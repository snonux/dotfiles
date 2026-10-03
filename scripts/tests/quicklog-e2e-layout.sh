#!/usr/bin/env bash
# Structural checks for the co-located Quicklog drain e2e layout (task t33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r QL_DIR="${SCRIPT_DIR}/../quicklog"
declare -r E2E_DIR="${QL_DIR}/e2e"
declare -r DRAIN="${QL_DIR}/drain"
declare -r DRAIN_WRAPPER="${SCRIPT_DIR}/../quicklog-drain"
declare -r E2E_WRAPPER="${SCRIPT_DIR}/../quicklog-drain-e2e"

die() {
    printf 'quicklog-e2e-layout test: %s\n' "$*" >&2
    exit 1
}

[[ -x "$DRAIN" ]] || die "drain missing or not executable: $DRAIN"
[[ -x "$DRAIN_WRAPPER" ]] || die "drain wrapper missing: $DRAIN_WRAPPER"
[[ -x "$E2E_WRAPPER" ]] || die "e2e wrapper missing or not executable: $E2E_WRAPPER"
[[ -x "$E2E_DIR/run" ]] || die "run missing or not executable"
[[ -x "$E2E_DIR/protocol-fake" ]] || die "protocol-fake entry missing"
[[ -x "$E2E_DIR/live-s3" ]] || die "live-s3 entry missing"

for f in common.sh preflight-live.sh parser-local.sh live-s3.sh \
    protocol-fake.sh isolation.sh; do
    [[ -f "$E2E_DIR/$f" ]] || die "missing $f"
    bash -n "$E2E_DIR/$f" || die "bash -n failed for $f"
done

bash -n "$DRAIN" || die "bash -n drain failed"
bash -n "$DRAIN_WRAPPER" || die "bash -n drain wrapper failed"
bash -n "$E2E_WRAPPER" || die "bash -n e2e wrapper failed"
bash -n "$E2E_DIR/run" || die "bash -n run failed"
bash -n "$E2E_DIR/protocol-fake" || die "bash -n protocol-fake entry failed"
bash -n "$E2E_DIR/live-s3" || die "bash -n live-s3 entry failed"

# Package layout: drain + e2e under scripts/quicklog/; thin top-level wrappers.
grep -q 'quicklog/drain' "$DRAIN_WRAPPER" \
    || die "drain wrapper does not exec quicklog/drain"
grep -q 'quicklog/e2e/run' "$E2E_WRAPPER" \
    || die "e2e wrapper does not exec quicklog/e2e/run"

# PROGRAM via export (exec -a does not change bash argv0 for scripts).
grep -q 'PROGRAM:=quicklog-drain' "$DRAIN_WRAPPER" \
    || die "drain wrapper missing PROGRAM=quicklog-drain"
grep -qE 'PROGRAM:=quicklog-drain-e2e' "$E2E_WRAPPER" \
    || die "e2e wrapper missing PROGRAM=quicklog-drain-e2e"
grep -qE 'PROGRAM:=quicklog-drain-e2e' "$E2E_DIR/run" \
    || die "run missing default PROGRAM=quicklog-drain-e2e"
if grep -qE 'PROGRAM=\$\{0##\*/\}' "$E2E_DIR/run"; then
    die "run still derives PROGRAM from \$0 (breaks under thin wrappers)"
fi
if grep -q 'exec -a' "$E2E_WRAPPER" "$E2E_DIR/protocol-fake" "$E2E_DIR/live-s3" \
    "$DRAIN_WRAPPER"; then
    die "wrappers still rely on exec -a for PROGRAM"
fi
# WRAPPER_ENV must pin PROGRAM=quicklog-drain so env (no -i) does not leak
# the harness PROGRAM=quicklog-drain-e2e into drain Usage/errors.
grep -qE 'PROGRAM=quicklog-drain' "$E2E_DIR/common.sh" \
    || die "common.sh WRAPPER_ENV missing PROGRAM=quicklog-drain pin"
if awk '
    /build_wrapper_env\(\)/ { in_fn=1 }
    in_fn && /WRAPPER_ENV=\(/ { in_arr=1 }
    in_arr && /PROGRAM=quicklog-drain/ { found=1 }
    in_arr && /^[[:space:]]*\)/ { exit }
    END { exit found ? 0 : 1 }
' "$E2E_DIR/common.sh"; then
    :
else
    die "PROGRAM=quicklog-drain not inside WRAPPER_ENV array"
fi

# gonf SyncDir(scripts/*) skips directories; nested drain needs Dir then InstallFile
# (atomicfile.Write CreateTemp's in the parent and does not MkdirAll).
GONF_HOME="${SCRIPT_DIR}/../../gonf/home/home.go"
[[ -f "$GONF_HOME" ]] || die "missing gonf home.go for deploy check"
# Each InstallFile(scripts/quicklog/drain) must be preceded by Dir(scripts/quicklog)
# in the same task body (Scripts + SystemdUser) — not a mere path grep.
if ! awk '
    /func \(HomeTasks\) Scripts\(\)/ { in_scripts=1; in_systemd=0 }
    /func \(HomeTasks\) SystemdUser\(\)/ { in_systemd=1; in_scripts=0 }
    /^func / && !/Scripts\(\)/ && !/SystemdUser\(\)/ { in_scripts=0; in_systemd=0 }
    in_scripts && /Dir\(DestHome\("scripts\/quicklog"\)/ { scripts_dir=1 }
    in_scripts && /InstallFile\(DestHome\("scripts\/quicklog\/drain"\)/ {
        if (!scripts_dir) exit 1
        scripts_install=1
    }
    in_scripts && /NoFile\(DestHome\("scripts\/quicklog-drain-e2e"\)/ {
        scripts_nofile=1
    }
    in_systemd && /Dir\(DestHome\("scripts\/quicklog"\)/ { systemd_dir=1 }
    in_systemd && /InstallFile\(DestHome\("scripts\/quicklog\/drain"\)/ {
        if (!systemd_dir) exit 1
        systemd_install=1
    }
    END { exit (scripts_install && systemd_install && scripts_nofile) ? 0 : 1 }
' "$GONF_HOME"; then
    die "gonf must Dir(scripts/quicklog) before InstallFile drain in Scripts and SystemdUser, and NoFile quicklog-drain-e2e after SyncDir"
fi

# common.sh must source shared asserts; phase bodies must not redefine them.
grep -qE '^[[:space:]]*source[[:space:]].*lib/e2e-assert\.sh' \
    "$E2E_DIR/common.sh" || die "common.sh does not source lib/e2e-assert.sh"

for f in preflight-live.sh parser-local.sh live-s3.sh protocol-fake.sh \
    isolation.sh run; do
    if grep -nE '^(say|fail|assert_rc|assert_rc_nonzero|assert_eq|assert_contains|assert_not_contains|assert_exists|assert_missing)\(\)' \
        "$E2E_DIR/$f"; then
        die "$f redefines assert helpers"
    fi
done

# Mode dispatch must expose protocol-fake vs live-s3 split.
grep -q 'protocol-fake' "$E2E_DIR/run" || die "run missing protocol-fake mode"
grep -q 'live-s3' "$E2E_DIR/run" || die "run missing live-s3 mode"

# protocol-fake must not force live load_creds / live-shaped CREDS.
if grep -A20 'protocol-fake)' "$E2E_DIR/run" | grep -q 'ql_e2e::load_creds'; then
    die "protocol-fake still calls load_creds"
fi
grep -q 'write_dummy_creds\|dummy-creds' "$E2E_DIR/run" \
    || die "protocol-fake missing dummy-creds path"
grep -q 'ql_e2e::write_dummy_creds' "$E2E_DIR/common.sh" \
    || die "common.sh missing write_dummy_creds"

# Cross-phase wipe lives in run orchestration, not parser-local.
grep -q 'ql_e2e::reset_sandbox_taskdata' "$E2E_DIR/run" \
    || die "run missing reset_sandbox_taskdata orchestration"
if grep -qE 'rm -rf "\$SAN/taskdata"' "$E2E_DIR/parser-local.sh"; then
    die "parser-local still wipes sandbox taskdata (belongs in run)"
fi

# Exit-on-FAILURES contract (s33/t33): run must exit 1 when FAILURES > 0.
grep -qE 'FAILURES -eq 0' "$E2E_DIR/run" || die "run missing FAILURES summary"
grep -qE 'exit 1' "$E2E_DIR/run" || die "run missing exit 1 on FAILURES"
grep -qE 'FAILURES > 0 \? 1' "$E2E_DIR/common.sh" \
    || die "cleanup missing exit-on-FAILURES"

# Wrappers stay thin.
wc -l <"$E2E_WRAPPER" | awk '$1 > 20 { exit 1 }' \
    || die "e2e wrapper is no longer thin ($(wc -l <"$E2E_WRAPPER") lines)"
wc -l <"$DRAIN_WRAPPER" | awk '$1 > 20 { exit 1 }' \
    || die "drain wrapper is no longer thin ($(wc -l <"$DRAIN_WRAPPER") lines)"

# Helpful unknown-mode path (no Garage): should fail fast with usage, not hang.
out="$E2E_DIR/../.layout-test-out.$$"
if "$E2E_DIR/run" not-a-mode >"$out" 2>&1; then
    rm -f "$out"
    die "run accepted unknown mode"
fi
grep -q "unknown mode" "$out" || {
    cat "$out" >&2
    rm -f "$out"
    die "unknown mode did not report clearly"
}
# PROGRAM must be quicklog-drain-e2e, not "run".
grep -q 'quicklog-drain-e2e: unknown mode' "$out" || {
    cat "$out" >&2
    rm -f "$out"
    die "unknown-mode error used wrong PROGRAM (want quicklog-drain-e2e:)"
}
rm -f "$out"

# Via thin wrapper, same PROGRAM contract.
if "$E2E_WRAPPER" not-a-mode >"$out" 2>&1; then
    rm -f "$out"
    die "e2e wrapper accepted unknown mode"
fi
grep -q 'quicklog-drain-e2e: unknown mode' "$out" || {
    cat "$out" >&2
    rm -f "$out"
    die "wrapper unknown-mode error used wrong PROGRAM"
}
rm -f "$out"

# z33: fake dart must not list objects via unquoted $(ls|sort).
if grep -nE 'for[[:space:]]+obj[[:space:]]+in[[:space:]]+\$\(ls' \
    "$E2E_DIR/protocol-fake.sh"; then
    die "protocol-fake still uses unquoted \$(ls ...) object listing"
fi
grep -qE 'find .* -print0 \| sort -z' "$E2E_DIR/protocol-fake.sh" \
    || die "protocol-fake missing find -print0 | sort -z object listing"
grep -qE 'mapfile -d' "$E2E_DIR/protocol-fake.sh" \
    || die "protocol-fake missing mapfile -d (must not while-read listing on stdin)"

# Behavioral: null-safe list keeps a whitespace name as one entry.
list_tmp=$(mktemp -d)
mkdir -p "$list_tmp/objects"
printf 'a\n' >"$list_tmp/objects/plain.md"
printf 'b\n' >"$list_tmp/objects/has space.md"
mapfile -d '' -t listed < <(
    find "$list_tmp/objects" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z
)
rc=0
((${#listed[@]} == 2)) || {
    echo "expected 2 object paths, got ${#listed[@]}" >&2
    rc=1
}
basenames=()
for p in "${listed[@]}"; do
    basenames+=("$(basename -- "$p")")
done
printf '%s\n' "${basenames[@]}" | grep -qxF 'has space.md' || {
    echo "whitespace object name was split or lost" >&2
    rc=1
}
printf '%s\n' "${basenames[@]}" | grep -qxF 'plain.md' || {
    echo "plain.md missing from null-safe listing" >&2
    rc=1
}
rm -rf "$list_tmp"
((rc == 0)) || die "null-safe object listing regression"

# shellcheck the runner (sourced libs via -x)
shellcheck -x "$E2E_DIR/run" || die "shellcheck run failed"
shellcheck -x "$E2E_WRAPPER" || die "shellcheck e2e wrapper failed"
shellcheck -x "$DRAIN_WRAPPER" || die "shellcheck drain wrapper failed"

printf 'ok: quicklog e2e layout checks passed\n'
