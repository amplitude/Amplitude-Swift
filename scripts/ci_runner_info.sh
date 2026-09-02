#!/bin/bash
#
# Dump everything we can learn about a GitHub Actions macOS runner, so that the
# environment our unit tests are flaky in can be reproduced locally.
#
# Key facts to print to the log, bulky dumps (sysctl -a, system_profiler,
# simctl list) to $OUT_DIR so they can be uploaded as a build artifact.
#
# Usage: scripts/ci_runner_info.sh [output-dir]
#
# Never fails the build: every probe is best-effort.

set +e

OUT_DIR="${1:-runner-info}"
mkdir -p "$OUT_DIR"

# --- log helpers ------------------------------------------------------------
# ::group:: makes the section collapsible in the Actions log viewer.
group() { echo "::group::$*"; }
endgroup() { echo "::endgroup::"; }

# run <label> <cmd...>: echo the command, run it, never fail.
run() {
  local label="$1"; shift
  echo "--- $label: $* ---"
  "$@" 2>&1
  local rc=$?
  [ $rc -ne 0 ] && echo "(exit $rc)"
  echo
  return 0
}

# sysctls <name...>: print `name = value` for each, skipping missing keys.
sysctls() {
  for key in "$@"; do
    local value
    value="$(sysctl -n "$key" 2>/dev/null)"
    [ -n "$value" ] && printf '%-40s %s\n' "$key" "$value"
  done
  return 0
}

# Environment variables we're willing to publish. This is an allowlist, not a
# filter: artifacts on a public repo are downloadable by anyone, so a variable
# gets in only if it says something about the runner (image, arch, toolchain,
# paths) or identifies the run. Anything not named here never leaves the box.
ENV_ALLOWLIST="
CI
DEVELOPER_DIR
HOME
LANG
LC_ALL
PATH
SHELL
TERM
TMPDIR
TEST_ITERATIONS
IMAGE_OS
IMAGE_VERSION
ImageOS
ImageVersion
RUNNER_ARCH
RUNNER_ENVIRONMENT
RUNNER_NAME
RUNNER_OS
RUNNER_TEMP
RUNNER_TOOL_CACHE
RUNNER_WORKSPACE
GITHUB_BASE_REF
GITHUB_EVENT_NAME
GITHUB_HEAD_REF
GITHUB_JOB
GITHUB_REF
GITHUB_REPOSITORY
GITHUB_RUN_ATTEMPT
GITHUB_RUN_ID
GITHUB_RUN_NUMBER
GITHUB_SHA
GITHUB_WORKFLOW
GITHUB_WORKSPACE
"

# allowed_env: print `NAME=value` for each allowlisted variable that is set.
allowed_env() {
  local name value
  for name in $ENV_ALLOWLIST; do
    eval "value=\${$name}"
    [ -n "$value" ] && printf '%s=%s\n' "$name" "$value"
  done
  return 0
}

echo "=============================================================="
echo " Runner info  ($(date -u '+%Y-%m-%dT%H:%M:%SZ'))"
echo "=============================================================="

# --- 1. identity: which machine / image are we on? -------------------------
group "1. Machine & image identity"
sysctls \
  hw.model machdep.cpu.brand_string hw.machine hw.target hw.product \
  kern.osproductversion kern.osversion kern.version kern.osrelease \
  kern.hostname kern.uuid kern.bootargs
echo
run "arch" arch
run "uname" uname -a
run "sw_vers" sw_vers
echo "--- virtualization ---"
# hw.model VirtualMac2,1 + kern.hv_vmm_present=1 => Apple Virtualization guest.
# That is the thing to mirror locally (e.g. Tart/UTM on Apple silicon), not
# bare metal, and it changes timer/IO behaviour noticeably.
sysctls kern.hv_vmm_present kern.hv_support hw.optional.arm64 sysctl.proc_translated
echo
echo "--- runner image metadata (env) ---"
allowed_env | grep -E '^(Image|IMAGE_|RUNNER_)'
for candidate in \
  /imagegeneration/imagedata.json \
  "$HOME/image-info" \
  "$HOME/.image-info" \
  /usr/local/share/imagegeneration/imagedata.json; do
  [ -e "$candidate" ] && { echo "--- $candidate ---"; cat "$candidate"; echo; }
done
endgroup

# --- 2. CPU topology -------------------------------------------------------
# Apple silicon runners expose performance (perflevel0) and efficiency
# (perflevel1) cores. Test code that races on wall-clock timing behaves very
# differently when a queue lands on an E core, and the P/E split is the single
# most useful number for reproducing that locally.
group "2. CPU topology"
sysctls \
  hw.ncpu hw.activecpu hw.physicalcpu hw.physicalcpu_max \
  hw.logicalcpu hw.logicalcpu_max hw.packages hw.nperflevels \
  hw.perflevel0.name hw.perflevel0.physicalcpu hw.perflevel0.logicalcpu \
  hw.perflevel0.cpusperl2 hw.perflevel0.l1dcachesize hw.perflevel0.l1icachesize \
  hw.perflevel0.l2cachesize \
  hw.perflevel1.name hw.perflevel1.physicalcpu hw.perflevel1.logicalcpu \
  hw.perflevel1.cpusperl2 hw.perflevel1.l1dcachesize hw.perflevel1.l1icachesize \
  hw.perflevel1.l2cachesize \
  hw.cpufrequency hw.cpufrequency_max hw.tbfrequency hw.busfrequency \
  hw.cachelinesize hw.l1dcachesize hw.l1icachesize hw.l2cachesize hw.l3cachesize \
  hw.byteorder hw.pagesize hw.pagesize32 \
  machdep.cpu.core_count machdep.cpu.thread_count machdep.cpu.features
endgroup

# --- 3. memory & swap ------------------------------------------------------
group "3. Memory & swap"
sysctls hw.memsize hw.memsize_usable vm.swapusage vm.page_pageable_internal_count
echo
run "vm_stat" vm_stat
endgroup

# --- 4. disk ---------------------------------------------------------------
# PersistentStorage writes event blocks as files; a slow or nearly-full volume
# changes flush timing and is a plausible source of storage-ordering flakes.
group "4. Disk & filesystem"
run "df -h" df -h
run "df -i /" df -i /
run "mount" mount
run "diskutil info /" diskutil info /
diskutil list > "$OUT_DIR/diskutil-list.txt" 2>&1
echo "(full diskutil list -> $OUT_DIR/diskutil-list.txt)"
endgroup

# --- 5. limits -------------------------------------------------------------
# File-descriptor and process limits: the test bundle opens a lot of small
# files and URLSession connections; hitting a limit shows up as a random
# unrelated failure.
group "5. Process & file limits"
run "ulimit -a" bash -c 'ulimit -a'
run "launchctl limit" launchctl limit
sysctls \
  kern.maxfiles kern.maxfilesperproc kern.maxproc kern.maxprocperuid \
  kern.num_taskthreads kern.num_threads kern.ipc.somaxconn kern.ipc.maxsockbuf
endgroup

# --- 6. current load -------------------------------------------------------
# Snapshot of what else is competing for the runner at test time.
group "6. Current load"
sysctls vm.loadavg
echo
run "uptime" uptime
run "top (1 sample, top 20 by cpu)" top -l 1 -n 20 -o cpu -stats pid,command,cpu,mem,th
# `comm` (executable path), never `command` (full argv): argv of a concurrent
# step can contain credentials, and both the log and the artifact are public on
# a public repo. Executable + rss + pcpu is all we need to see who is competing
# for the runner.
run "processes (top 40 by rss)" bash -c "ps -Ao pid,rss,pcpu,etime,comm -m | head -40"
run "thermal state" pmset -g therm
run "power/AC state" pmset -g ps
ps -Ao pid,ppid,rss,pcpu,etime,comm > "$OUT_DIR/ps-full.txt" 2>&1
echo "(full process list -> $OUT_DIR/ps-full.txt)"
endgroup

# --- 7. network ------------------------------------------------------------
# HttpClientTests hit real hosts in some cases and assert on error kinds; DNS
# and egress behaviour are part of the repro.
group "7. Network"
run "ifconfig -a" ifconfig -a
run "route -n get default" route -n get default
run "scutil --dns" scutil --dns
run "resolv.conf" cat /etc/resolv.conf
run "/etc/hosts" cat /etc/hosts
run "network time" systemsetup -getusingnetworktime
run "date (local/UTC)" bash -c 'date; date -u; TZ=UTC date'
sysctls kern.boottime
echo
for host in api2.amplitude.com api.lab.amplitude.com localhost; do
  echo "--- dns: $host ---"
  dscacheutil -q host -a name "$host" 2>&1 | head -12
done
echo "--- egress check (api2.amplitude.com:443, 5s timeout) ---"
curl -sS -o /dev/null -w 'http=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n' \
  --max-time 5 https://api2.amplitude.com/2/httpapi 2>&1
endgroup

# --- 8. toolchain & simulators --------------------------------------------
group "8. Toolchain & simulators"
run "xcode-select -p" xcode-select -p
run "xcodebuild -version" xcodebuild -version
run "swift --version" swift --version
run "clang --version" clang --version
run "installed Xcodes" bash -c 'ls -d /Applications/Xcode*.app 2>/dev/null'
run "simctl runtimes" xcrun simctl list runtimes
run "booted simulators" xcrun simctl list devices booted
# Full argv here on purpose, unlike section 6: only CoreSimulator-matching
# processes are listed, they are all Apple system binaries, and the paths are
# the information -- they show which runtime volumes are actually mounted.
run "CoreSimulator processes" bash -c 'pgrep -fl -i coresimulator | head -20'
run "CoreSimulator version" bash -c "defaults read /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/Info.plist CFBundleShortVersionString 2>/dev/null"
xcrun simctl list > "$OUT_DIR/simctl-list.txt" 2>&1
xcrun simctl list -j > "$OUT_DIR/simctl-list.json" 2>&1
echo "(full simctl list -> $OUT_DIR/simctl-list.txt, .json)"
endgroup

# --- 9. micro benchmarks ---------------------------------------------------
# Rough numbers so a local machine/VM can be compared against the runner
# instead of guessing. Total budget ~20s.
group "9. Micro benchmarks"

BENCH_DIR="$(mktemp -d)"

# timeit <label> <cmd...>: one clean line per benchmark. `time` writes to the
# shell's stderr, so send it to a file rather than into the shared stream --
# merging it with a backgrounded child's output mangles the digits.
timeit() {
  local label="$1"; shift
  local tf; tf="$(mktemp)"
  { time "$@" > /dev/null 2>&1; } 2> "$tf"
  printf '%-34s %s\n' "$label" \
    "$(tr '\n' ' ' < "$tf" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  rm -f "$tf"
  return 0
}

echo "--- disk ---"
timeit "seq write 512MiB + sync" \
  bash -c 'dd if=/dev/zero of="$1/bench.bin" bs=1m count=512; sync' _ "$BENCH_DIR"
dd if=/dev/zero of="$BENCH_DIR/bench2.bin" bs=1m count=512 2>&1 | tail -1
rm -f "$BENCH_DIR"/bench*.bin

# Mirrors PersistentStorage: lots of small JSON event-block files, written and
# read back one at a time. Done in-process so the numbers are IO and not fork
# overhead; the fsync variant is the worst case for flush-ordering flakes.
if command -v python3 > /dev/null 2>&1; then
  python3 - "$BENCH_DIR" <<'PY' 2>&1
import os, sys, time
d, n = sys.argv[1], 2000
payload = (b'{"event_type":"bench","event_properties":{"i":%d}}' % 0) * 4

def bench(label, fn):
    t0 = time.monotonic()
    fn()
    dt = time.monotonic() - t0
    print(f"{label:<34} {dt*1000:8.1f}ms  ({n/dt:,.0f} ops/s)")

def write(fsync=False):
    def go():
        for i in range(n):
            with open(os.path.join(d, f"f{i}.json"), "wb") as f:
                f.write(payload)
                if fsync:
                    f.flush()
                    os.fsync(f.fileno())
    return go

def read_back():
    for i in range(n):
        with open(os.path.join(d, f"f{i}.json"), "rb") as f:
            f.read()

def listdir():
    for _ in range(50):
        os.listdir(d)

def unlink():
    for i in range(n):
        os.unlink(os.path.join(d, f"f{i}.json"))

bench(f"{n} small files write+close", write())
bench(f"{n} small files read", read_back)
bench("50x listdir of 2000 entries", listdir)
bench(f"{n} small files unlink", unlink)
bench(f"{n} small files write+fsync", write(fsync=True))
bench(f"{n} small files unlink (2)", unlink)
PY
else
  echo "(python3 not available; skipping small-file benchmark)"
fi
rm -rf "$BENCH_DIR"
echo

# Integer loop in awk: crude but consistent across machines. Comparing the
# single-thread number to the N-thread number shows P-core vs E-core scheduling
# (the thing that makes wall-clock test assertions flaky) -- with only P cores
# the N-thread wall time barely moves, with E cores in the mix it does.
echo "--- cpu ---"
CPU_BENCH_AWK="$(mktemp)"
cat > "$CPU_BENCH_AWK" <<'AWK'
BEGIN { s = 0; for (i = 0; i < 12000000; i++) s += i % 7; print "checksum", s }
AWK
NCPU="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)"
timeit "awk loop, 1 thread" awk -f "$CPU_BENCH_AWK"
timeit "awk loop, $NCPU threads" bash -c '
  for _ in $(seq 1 "$2"); do awk -f "$1" > /dev/null 2>&1 & done
  wait
' _ "$CPU_BENCH_AWK" "$NCPU"
rm -f "$CPU_BENCH_AWK"
echo

# Timer slop and clock resolution measured in-process: this is what async
# XCTestExpectation waits are actually racing against. A runner that overshoots
# a 5 ms timer by 10x is a runner where a 1 s expectation on a 3-hop dispatch
# chain is a coin flip.
echo "--- timers ---"
if command -v python3 > /dev/null 2>&1; then
  python3 - <<'PY' 2>&1
import time, statistics
def slop(target, n):
    d = []
    for _ in range(n):
        t0 = time.monotonic()
        time.sleep(target)
        d.append((time.monotonic() - t0 - target) * 1000.0)
    return d
for target, n in ((0.005, 200), (0.050, 20)):
    d = slop(target, n)
    print(f"sleep({target*1000:.0f}ms) x{n}: overshoot "
          f"min={min(d):.2f}ms p50={statistics.median(d):.2f}ms "
          f"mean={statistics.mean(d):.2f}ms max={max(d):.2f}ms")
# Smallest observable tick of the monotonic clock.
ticks = []
for _ in range(2000):
    a = time.monotonic_ns()
    while (b := time.monotonic_ns()) == a:
        pass
    ticks.append(b - a)
print(f"monotonic clock granularity: min={min(ticks)}ns "
      f"p50={int(statistics.median(ticks))}ns")
print(f"time.get_clock_info('monotonic'): {time.get_clock_info('monotonic')}")
PY
else
  echo "(python3 not available; skipping timer-slop measurement)"
fi
endgroup

# --- 10. bulky dumps -> artifact ------------------------------------------
group "10. Full dumps (written to $OUT_DIR)"
sysctl -a > "$OUT_DIR/sysctl-a.txt" 2>&1
echo "sysctl -a                -> $OUT_DIR/sysctl-a.txt ($(wc -l < "$OUT_DIR/sysctl-a.txt" | tr -d ' ') lines)"

system_profiler -json \
  SPHardwareDataType SPSoftwareDataType SPMemoryDataType \
  SPStorageDataType SPNVMeDataType SPNetworkDataType SPDeveloperToolsDataType \
  > "$OUT_DIR/system_profiler.json" 2>"$OUT_DIR/system_profiler.err"
echo "system_profiler -json    -> $OUT_DIR/system_profiler.json"

allowed_env > "$OUT_DIR/env.txt" 2>&1
echo "env (allowlisted)        -> $OUT_DIR/env.txt ($(wc -l < "$OUT_DIR/env.txt" | tr -d ' ') vars)"

# Platform expert device only -- carries the VM/board identity. The full
# `ioreg -l` is tens of MB and not worth the artifact space.
ioreg -rd1 -c IOPlatformExpertDevice > "$OUT_DIR/ioreg-platform.txt" 2>&1
echo "ioreg IOPlatformExpert   -> $OUT_DIR/ioreg-platform.txt"

sw_vers > "$OUT_DIR/sw_vers.txt" 2>&1
xcodebuild -version >> "$OUT_DIR/sw_vers.txt" 2>&1

echo
echo "--- key facts, one line (grep-able across runs) ---"
printf 'RUNNER_FACTS model=%s cpu="%s" arch=%s ncpu=%s pcpu=%s p_cores=%s e_cores=%s mem=%s os=%s hv=%s image=%s xcode="%s" free_root=%s loadavg="%s"\n' \
  "$(sysctl -n hw.model 2>/dev/null)" \
  "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)" \
  "$(arch)" \
  "$(sysctl -n hw.ncpu 2>/dev/null)" \
  "$(sysctl -n hw.physicalcpu 2>/dev/null)" \
  "$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)" \
  "$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null)" \
  "$(sysctl -n hw.memsize 2>/dev/null)" \
  "$(sw_vers -productVersion 2>/dev/null)" \
  "$(sysctl -n kern.hv_vmm_present 2>/dev/null)" \
  "${ImageVersion:-$IMAGE_VERSION}" \
  "$(xcodebuild -version 2>/dev/null | tr '\n' ' ')" \
  "$(df -h / | awk 'NR==2{print $4}')" \
  "$(sysctl -n vm.loadavg 2>/dev/null)"
endgroup

exit 0
