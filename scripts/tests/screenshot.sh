#!/usr/bin/env bash
# Checks for scripts/screenshot (pg4: pinned before screenshot::main was
# split). flameshot, date and the clipboard tools are fakes on a fixture
# PATH that holds only the tools the script needs, so a real wl-copy or
# xclip on this machine is never found and no screen is captured.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r TARGET="$SCRIPT_DIR/../screenshot"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    printf 'screenshot test: %s\n' "$*" >&2
    exit 1
}

declare -r BIN="$TEST_ROOT/bin"
declare -r CALLS="$TEST_ROOT/calls"
mkdir -p "$BIN" "$TEST_ROOT/home"
for tool in bash env cat mkdir dirname; do
    ln -s "$(command -v "$tool")" "$BIN/$tool" \
        || fail "cannot symlink $tool into the fixture PATH"
done
# Fake flameshot: logs its argv; writes a PNG stand-in to the -p path unless
# FLAMESHOT_EMPTY is set (an aborted gui selection); FLAMESHOT_RC sets the
# exit status.
cat >"$BIN/flameshot" <<'EOF'
#!/usr/bin/env bash
printf 'flameshot %s\n' "$*" >>"$CALLS"
[[ -n "${FLAMESHOT_RC:-}" ]] && exit "$FLAMESHOT_RC"
[[ -n "${FLAMESHOT_EMPTY:-}" ]] && exit 0
printf 'png\n' >"${*: -1}"
EOF
printf '#!/usr/bin/env bash\necho 20260102-030405\n' >"$BIN/date"
# Clipboard fakes log their argv and what they read on stdin.
cat >"$TEST_ROOT/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf 'wl-copy %s <%s>\n' "$*" "$(cat)" >>"$CALLS"
EOF
cat >"$TEST_ROOT/xclip" <<'EOF'
#!/usr/bin/env bash
printf 'xclip %s\n' "$*" >>"$CALLS"
EOF
chmod +x "$BIN/flameshot" "$BIN/date" "$TEST_ROOT/wl-copy" "$TEST_ROOT/xclip"
export CALLS

# run_shot ARGS... — run the script on the fixture PATH; sets rc and leaves
# stdout/stderr in out/err and the tool calls in $CALLS.
run_shot() {
    : >"$CALLS"
    rc=0
    env -i PATH="$BIN" HOME="$TEST_ROOT/home" CALLS="$CALLS" \
        ${WAYLAND_DISPLAY:+WAYLAND_DISPLAY="$WAYLAND_DISPLAY"} \
        ${FLAMESHOT_EMPTY:+FLAMESHOT_EMPTY=1} \
        ${FLAMESHOT_RC:+FLAMESHOT_RC="$FLAMESHOT_RC"} \
        "$TARGET" "$@" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || rc=$?
}

# expect_shot WANT_RC WANT_CALLS WANT_OUT WANT_ERR ARGS...
expect_shot() {
    local -r want_rc="$1" want_calls="$2" want_out="$3" want_err="$4"
    shift 4
    run_shot "$@"
    ((rc == want_rc)) || fail "'$*': want rc $want_rc, got $rc: $(cat "$TEST_ROOT/err")"
    [[ "$(cat "$CALLS")" == "$want_calls" ]] \
        || fail "'$*': calls changed: $(cat "$CALLS")"
    [[ "$(cat "$TEST_ROOT/out")" == "$want_out" ]] \
        || fail "'$*': stdout changed: $(cat "$TEST_ROOT/out")"
    [[ "$(cat "$TEST_ROOT/err")" == "$want_err" ]] \
        || fail "'$*': stderr changed: $(cat "$TEST_ROOT/err")"
}

unset WAYLAND_DISPLAY FLAMESHOT_EMPTY FLAMESHOT_RC
def="$TEST_ROOT/home/Pictures/Screenshot-20260102-030405.png"
p="$TEST_ROOT/shots/sub/x.png"

# Modes, default path (its directory is created), and a bare output path.
expect_shot 0 "flameshot full -p $def" "$def" ''
[[ -s "$def" ]] || fail "default path not written"
expect_shot 0 "flameshot screen -p $p" "$p" '' screen "$p"
expect_shot 0 "flameshot gui -p $p" "$p" '' gui "$p"
expect_shot 0 "flameshot full -p $p" "$p" '' "$p"

# Clipboard: wl-copy under Wayland, else xclip, else an error (exit 1)
# after the capture was saved.
cp "$TEST_ROOT/wl-copy" "$TEST_ROOT/xclip" "$BIN/"
WAYLAND_DISPLAY=wayland-0 expect_shot 0 "flameshot full -p $p
wl-copy --type image/png <png>" "$p" '' -c "$p"
expect_shot 0 "flameshot screen -p $p
xclip -selection clipboard -t image/png -i $p" "$p" '' --clipboard screen "$p"
rm "$BIN/wl-copy" "$BIN/xclip"
WAYLAND_DISPLAY=wayland-0 expect_shot 1 "flameshot full -p $p" '' \
    'screenshot: no clipboard tool found (need wl-copy or xclip)' -c "$p"

# An aborted gui selection writes nothing: exit 1, no clipboard copy.
cp "$TEST_ROOT/xclip" "$BIN/"
FLAMESHOT_EMPTY=1 expect_shot 1 "flameshot gui -p $TEST_ROOT/empty.png" '' \
    'screenshot: nothing captured' -c gui "$TEST_ROOT/empty.png"
# A failing flameshot stops the script (set -e) with its status.
FLAMESHOT_RC=3 expect_shot 3 "flameshot full -p $p" '' '' "$p"

# Help and usage errors never run flameshot.
run_shot -h
((rc == 0)) || fail "-h exited $rc"
[[ "$(head -n 1 "$TEST_ROOT/err")" == 'Usage: screenshot [-c|--clipboard] [full|screen|gui] [output-path]' ]] \
    || fail "-h: usage missing on stderr: $(cat "$TEST_ROOT/err")"
[[ ! -s "$CALLS" ]] || fail "-h ran flameshot"
for bad in -x '-c -x' '-c --help'; do
    # shellcheck disable=SC2086 # split the option string on purpose
    run_shot $bad
    want=2
    [[ "$bad" == '-c --help' ]] && want=0
    ((rc == want)) || fail "'$bad': want rc $want, got $rc"
    grep -Fq 'Usage: screenshot' "$TEST_ROOT/err" || fail "'$bad': no usage"
    [[ ! -s "$CALLS" ]] || fail "'$bad' ran flameshot"
done

printf 'screenshot test: ok\n'
