#!/bin/bash
#
# Runs `xcodebuild test` on CI, retrying only when the runner failed, never when a test did.
#
# A failing test case, a crashed test bundle or a build error is final: the job goes red on the
# first attempt, and no test-level retry is passed to xcodebuild. (-retry-tests-on-failure used
# to hide a ~30% red rate behind a second run of the failed cases; with the tests fixed, a red
# leg has to mean something again.)
#
# A runner failure is one where the tests were never reached, or all passed and xcodebuild died
# afterwards. Only failures observed on GitHub-hosted macOS runners are retried, each listed with
# the run it was seen in. Add a signature only with the same evidence, and keep it specific: a
# string that a broken test bundle or example app could also produce must not be retried.
#   - package resolution: "failed downloading 'https://github.com/.../releases/download/.../
#     AmplitudeCore.zip' ... already exists in file system" (binary target, stale SwiftPM
#     artifact cache), exit 74 -- run 33817758147, tvOS and visionOS legs. The cache is
#     cleared before the retry.
#   - test host launch: DTServiceHub "Failed to send signal 19 to process N: 3" (errno 3 is
#     ESRCH), after which xcodebuild itself dies with SIGSEGV, exit 139 -- run 33712638521, objc.
#   - xcodebuild aborting with SIGABRT, exit 134, after every test case had passed
#     (DVTAssertions failure inside DVTiPhoneSimulator) -- run 33819412376, objc, and once before.
# Anything else non-zero is reported and not retried, so a new failure mode is seen, not hidden.
#
# Usage:  scripts/ci_xcodebuild_test.sh test -scheme <scheme> -destination <dest> [...]
#         Do not pass -resultBundlePath; the script sets one per attempt under the log dir.
# Env:    MAX_ATTEMPTS            total attempts, default 3
#         XCODEBUILD_LOG_DIR      where attempt logs and result bundles go, default a temp dir;
#                                 upload it when the step fails
#         SWIFTPM_ARTIFACT_CACHE  SwiftPM binary-artifact cache cleared before retrying a
#                                 download failure; default ~/Library/Caches/org.swift.swiftpm/artifacts
#
# The runner's /bin/bash is 3.2: no associative arrays, no ${var,,}, no mapfile.

set -u
set -o pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
case "$MAX_ATTEMPTS" in
  ''|*[!0-9]*|0)
    echo "::error::MAX_ATTEMPTS must be a positive integer, got '$MAX_ATTEMPTS'"
    exit 2
    ;;
esac

LOG_DIR="${XCODEBUILD_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"

if [ -z "${SWIFTPM_ARTIFACT_CACHE:-}" ]; then
  if [ -n "${HOME:-}" ]; then
    SWIFTPM_ARTIFACT_CACHE="$HOME/Library/Caches/org.swift.swiftpm/artifacts"
  else
    SWIFTPM_ARTIFACT_CACHE=""
  fi
fi

# A test-side result. Any match makes the outcome final, whatever the exit code. Covers XCTest's
# serial format ("Test Case '-[...]' failed") and the parallel one the ObjC example scheme uses
# ("Test case '-[...]' failed on 'Clone 1 of iPhone 16 ...'"), a compiler error in any source
# file, a linker error, a test bundle that fails to load, a crashed or timed-out test, and both
# build-failure banners (`xcodebuild test` prints "** TEST BUILD FAILED **").
TEST_FAILURE_PATTERN="Test [Cc]ase '.*' failed|\.(swift|m|mm|h|c|cc|cpp)(:[0-9]+){1,2}: error:|Restarting after unexpected exit|\*\* (TEST )?BUILD FAILED \*\*|error: linker command failed|Undefined symbols for architecture|Failed to load the test bundle"

# The observed runner failures and nothing generic. "Could not resolve package dependencies" is
# also what a wrong version requirement prints, and "Failed to launch the test host" is also what
# a crashing example app prints, so neither is here.
RUNNER_FAILURE_PATTERN="failed downloading .*/releases/download/|Failed to send signal [0-9]+ to process [0-9]+"

# xcodebuild itself dying is a runner failure when the log carries no test-side result: 134 is
# SIGABRT, 139 is SIGSEGV. Exit 74 (package resolution) is deliberately not here: a wrong version
# requirement exits 74 too, and only the download failure above is worth a retry.
is_runner_exit_code() {
  case "$1" in
    134|139) return 0 ;;
    *) return 1 ;;
  esac
}

attempt=1
while :; do
  log="$LOG_DIR/xcodebuild-attempt-$attempt.log"
  result_bundle="$LOG_DIR/xcodebuild-attempt-$attempt.xcresult"
  echo "::group::xcodebuild attempt $attempt of $MAX_ATTEMPTS"
  xcodebuild "$@" -resultBundlePath "$result_bundle" 2>&1 | tee "$log"
  status="${PIPESTATUS[0]}"
  echo "::endgroup::"

  if [ "$status" -eq 0 ]; then
    exit 0
  fi

  if grep -qaE "$TEST_FAILURE_PATTERN" "$log"; then
    echo "::error::xcodebuild exited $status with a test or build failure (attempt $attempt); not retrying"
    grep -aE "$TEST_FAILURE_PATTERN" "$log" | head -20
    exit "$status"
  fi

  reason="$(grep -aoE "$RUNNER_FAILURE_PATTERN" "$log" | head -1)"
  if [ -z "$reason" ] && is_runner_exit_code "$status"; then
    reason="exit code $status with no test failure in the log"
  fi

  if [ -z "$reason" ]; then
    echo "::error::xcodebuild exited $status for a reason this script does not recognise (attempt $attempt); not retrying. Log: $log"
    tail -40 "$log"
    exit "$status"
  fi

  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    echo "::error::runner failure on all $MAX_ATTEMPTS attempts, last: $reason (exit $status)"
    exit "$status"
  fi

  echo "::warning::runner failure on attempt $attempt (exit $status): $reason. Retrying."
  case "$reason" in
    "failed downloading"*)
      # The observed failure left a half-written artifact behind ("already exists in file
      # system"); a plain rerun would trip over the same directory.
      if [ -n "$SWIFTPM_ARTIFACT_CACHE" ] && [ -d "$SWIFTPM_ARTIFACT_CACHE" ]; then
        echo "Clearing the SwiftPM artifact cache at $SWIFTPM_ARTIFACT_CACHE before retrying"
        rm -rf "$SWIFTPM_ARTIFACT_CACHE"
      fi
      ;;
  esac
  attempt=$((attempt + 1))
done
