#!/bin/sh
# Upload uptimed records / host metadata to goprecords (cron / systemd).
set -eu

GOPRECORDS_BASE_URL="${GOPRECORDS_BASE_URL:-https://goprecords.f3s.buetow.org}"
# Bound hung TCP/HTTP so cron/systemd units cannot stall forever (v33).
#
# Wall-clock budget (defaults):
#   Per attempt: connect <= CONNECT_TIMEOUT (10s), whole transfer <= MAX_TIME (60s).
#   Retries: up to CURL_RETRIES (2) extra attempts, delaying CURL_RETRY_DELAY (1s)
#   between them; --retry-max-time (180s) caps the entire retry budget so the
#   worst-case hang is ~RETRY_MAX_TIME (+ small curl overhead), not
#   (RETRIES+1)*MAX_TIME unbounded growth.
GOPRECORDS_CONNECT_TIMEOUT="${GOPRECORDS_CONNECT_TIMEOUT:-10}"
GOPRECORDS_MAX_TIME="${GOPRECORDS_MAX_TIME:-60}"
# Bounded retries for transient curl failures (timeouts, 408/429/5xx).
GOPRECORDS_CURL_RETRIES="${GOPRECORDS_CURL_RETRIES:-2}"
GOPRECORDS_CURL_RETRY_DELAY="${GOPRECORDS_CURL_RETRY_DELAY:-1}"
GOPRECORDS_CURL_RETRY_MAX_TIME="${GOPRECORDS_CURL_RETRY_MAX_TIME:-180}"

_default_token_file() {
	if [ "$(id -u)" = "0" ]; then
		printf '/etc/goprecords-upload.token'
	else
		config="${XDG_CONFIG_HOME:-${HOME}/.config}"
		printf '%s/goprecords-upload-%s/token' "$config" "$GOPRECORDS_HOST"
	fi
}

upload() {
	kind=$1
	file=$2
	if ! test -f "$file"; then
		echo "goprecords-upload-client: skip $kind (no $file)" >&2
		return 0
	fi
	curl -fsS \
		--connect-timeout "${GOPRECORDS_CONNECT_TIMEOUT}" \
		--max-time "${GOPRECORDS_MAX_TIME}" \
		--retry "${GOPRECORDS_CURL_RETRIES}" \
		--retry-delay "${GOPRECORDS_CURL_RETRY_DELAY}" \
		--retry-max-time "${GOPRECORDS_CURL_RETRY_MAX_TIME}" \
		-X PUT --data-binary "@${file}" \
		-H "Authorization: Bearer ${TOKEN}" \
		"${GOPRECORDS_BASE_URL}/upload/${GOPRECORDS_HOST}/${kind}"
}

_find_records() {
	if [ -n "${GOPRECORDS_RECORDS_FILE:-}" ]; then
		if test -f "$GOPRECORDS_RECORDS_FILE"; then
			printf '%s' "$GOPRECORDS_RECORDS_FILE"
			return 0
		fi
		echo "goprecords-upload-client: GOPRECORDS_RECORDS_FILE not a file: $GOPRECORDS_RECORDS_FILE" >&2
		exit 1
	fi
	for p in \
		/var/spool/uptimed/records \
		/var/db/uptimed/records \
		/usr/local/var/uptimed/records; do
		if test -f "$p"; then
			printf '%s' "$p"
			return 0
		fi
	done
	echo "goprecords-upload-client: no uptimed records file found" >&2
	exit 1
}

_main() {
	: "${GOPRECORDS_HOST:?set GOPRECORDS_HOST (e.g. f0, pi0, earth)}"

	# Prefer known platform dirs (NetBSD pkgsrc, FreeBSD local) over a
	# sparse/odd caller PATH — same approach as the pre-v33 script.
	PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/pkg/bin:/usr/pkg/sbin:/usr/local/bin:/usr/local/sbin:${PATH}"

	GOPRECORDS_TOKEN_FILE="${GOPRECORDS_TOKEN_FILE:-$(_default_token_file)}"

	if ! test -r "$GOPRECORDS_TOKEN_FILE"; then
		echo "goprecords-upload-client: cannot read $GOPRECORDS_TOKEN_FILE" >&2
		exit 1
	fi
	TOKEN=$(tr -d '\n\r' <"$GOPRECORDS_TOKEN_FILE")

	records_path=$(_find_records)

	tmp=$(mktemp)
	trap 'rm -f "$tmp"' 0 INT TERM HUP

	upload records "$records_path"

	if command -v uprecords >/dev/null 2>&1; then
		uprecords -a -m 100 >"$tmp"
		upload txt "$tmp"
		uprecords -a | grep '^->' >"$tmp" || true
		if test -s "$tmp"; then
			upload cur.txt "$tmp"
		fi
	fi

	if test -r /etc/os-release; then
		upload os.txt /etc/os-release
	elif test -r /var/run/dmesg.boot; then
		upload os.txt /var/run/dmesg.boot
	else
		uname -a >"$tmp"
		upload os.txt "$tmp"
	fi

	if test -r /proc/cpuinfo; then
		upload cpuinfo.txt /proc/cpuinfo
	elif test -r /var/run/dmesg.boot; then
		upload cpuinfo.txt /var/run/dmesg.boot
	else
		sysctl hw.model hw.ncpu hw.machine >"$tmp" 2>/dev/null || uname -a >"$tmp"
		upload cpuinfo.txt "$tmp"
	fi
}

# Library mode for tests only when *sourced* under bash with
# GOPRECORDS_UPLOAD_LIB=yes. Executing this script always runs _main
# (cron/systemd-safe): LIB=yes must not become a silent success no-op
# (v33 review follow-up). Basename gating is unsafe — scripts/tests/ shares
# this name.
# shellcheck disable=SC3028,SC3054
if [ -n "${BASH_VERSION:-}" ] \
	&& [ "${BASH_SOURCE[0]}" != "$0" ] \
	&& [ "${GOPRECORDS_UPLOAD_LIB:-no}" = "yes" ]; then
	:
else
	_main "$@"
fi
