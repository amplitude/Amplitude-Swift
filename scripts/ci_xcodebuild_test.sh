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
# afterwards. Seen on GitHub-hosted macOS runners, once each per few hundred jobs:
#   - package resolution: "Could not resolve package dependencies: failed downloading
#     https://github.com/.../releases/download/.../AmplitudeCore.zip" (binary target), exit 74
#   - test host launch: "Failed to send signal 19 ... ESRCH", the test runner never started
#   - xcodebuild aborting with SIGABRT (exit 134) after every test case had passed
# These are retried, up to MAX_ATTEMPTS in total, with the reason printed as a workflow warning.
# Anything else non-zero is reported and not retried, so a new failure mode is seen, not hidden.
#
# Usage:  scripts/ci_xcodebuild_test.sh test -scheme <scheme> -destination <dest> [...]
# Env:    MAX_ATTEMPTS        total attempts, default 3
#         XCODEBUILD_LOG_DIR  where attempt logs go, default a temp dir; upload it on failure
#
# The runner's /bin/bash is 3.2: no associative arrays, no ${var,,}, no mapfile.

set -u
set -o pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
LOG_DIR="${XCODEBUILD_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"

# A test-side result. Any match makes the outcome final, whatever the exit code.
TEST_FAILURE_PATTERN="Test Case '-\[.*\]' failed|\.swift:[0-9]+(:[0-9]+)?: error:|Restarting after unexpected exit|\*\* BUILD FAILED \*\*"

# A runner failure. Kept narrow on purpose: a failure that matches nothing here is not retried.
RUNNER_FAILURE_PATTERN='Could not resolve package dependencies|failed downloading .*/releases/download/|Failed to send signal .*ESRCH|Test runner never began executing tests|Unable to boot the Simulator|Failed to launch the test host|Simulator device failed to launch|Lost connection to the test manager|Timed out waiting for .*(test runner|test host|Simulator)'

# Exit codes that are a runner failure on their own: 134 is SIGABRT from xcodebuild itself,
# 74 (EX_IOERR) is what package resolution returns when a download fails.
is_runner_exit_code() {
  case "$1" in
    134|74) return 0 ;;
    *) return 1 ;;
  esac
}

attempt=1
while :; do
  log="$LOG_DIR/xcodebuild-attempt-$attempt.log"
  echo "::group::xcodebuild attempt $attempt of $MAX_ATTEMPTS"
  xcodebuild "$@" 2>&1 | tee "$log"
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
  attempt=$((attempt + 1))
done
