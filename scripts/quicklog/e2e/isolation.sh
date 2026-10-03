# shellcheck shell=bash
# Isolation verification (phase 7): real HOME / bucket leftovers.
# Sourced by scripts/quicklog/e2e/run — not executed directly.

# --- phase 7: isolation verification ------------------------------------------------------------

say "phase 7: isolation verification"

assert_eq "real taskwarrior DB content unchanged" "$(real_db_fingerprint)" "$REAL_DB_BEFORE"
assert_eq "real taskwarrior DB semantics unchanged" "$(real_db_semantics)" "$REAL_DB_SEM_BEFORE"
assert_eq "real notes dir unchanged" "$(real_notes_fingerprint)" "$REAL_NOTES_BEFORE"
assert_eq "real due-stamp file unchanged" "$(real_due_stamp_fingerprint)" "$REAL_STAMP_BEFORE"

leftovers=0
for key in "${TEST_KEYS[@]}"; do
  if bucket_keys | grep -F -x -q "$key"; then
    fail "test key left in bucket: $key"
    leftovers=$((leftovers + 1))
  fi
done
if ((leftovers == 0)); then
  echo "ok: no test keys left in the bucket"
fi

if [[ "$(bucket_keys | sort)" != "$BUCKET_BEFORE" ]]; then
  echo "WARNING: foreign keys appeared mid-run (--only kept them untouched):" >&2
  comm -13 <(printf '%s\n' "$BUCKET_BEFORE") <(bucket_keys | sort) >&2
  echo "WARNING: drain them normally, then re-run the harness" >&2
fi
