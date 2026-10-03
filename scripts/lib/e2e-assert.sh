# shellcheck shell=bash
# Shared assertion helpers for scripts/*-e2e harnesses.
#
# Source from a harness after setting PROGRAM (defaults to ${0##*/}) and
# optionally FAILURES=0. fail() increments FAILURES and prints to stderr;
# assert_* helpers call fail on mismatch and print "ok: …" on success.
# Scenario bodies stay in the harness; only the assert family lives here.

: "${PROGRAM:=${0##*/}}"
: "${FAILURES:=0}"

say() { printf '\n== %s ==\n' "$*"; }

fail() {
  FAILURES=$((FAILURES + 1))
  echo "$PROGRAM: FAIL: $*" >&2
}

assert_rc() { # desc expected_rc actual_rc
  if [[ "$2" != "$3" ]]; then
    fail "$1: expected rc=$2, got rc=$3"
  else
    echo "ok: $1 (rc=$3)"
  fi
}

assert_rc_nonzero() { # desc actual_rc
  if [[ "$2" -eq 0 ]]; then
    fail "$1: expected a nonzero exit code, got rc=0"
  else
    echo "ok: $1 (rc=$2)"
  fi
}

assert_eq() { # desc actual expected
  if [[ "$2" != "$3" ]]; then
    fail "$1: got '$2', expected '$3'"
  else
    echo "ok: $1"
  fi
}

assert_contains() { # desc haystack needle
  if [[ "$2" == *"$3"* ]]; then
    echo "ok: $1"
  else
    fail "$1: '$2' does not contain '$3'"
  fi
}

assert_not_contains() { # desc haystack needle
  if [[ "$2" != *"$3"* ]]; then
    echo "ok: $1"
  else
    fail "$1: '$2' unexpectedly contains '$3'"
  fi
}

assert_exists() { # desc path
  if [[ -e "$2" ]]; then
    echo "ok: $1 ($2)"
  else
    fail "$1: $2 is missing"
  fi
}

assert_missing() { # desc path
  if [[ ! -e "$2" ]]; then
    echo "ok: $1 ($2)"
  else
    fail "$1: $2 exists but must not"
  fi
}
