#!/bin/sh
# Runs all test files, each in its own temporary directory.
set -u
cd "$(dirname "$0")/.." || exit 1

rc=0
for t in tests/test_*.sh; do
	echo "== $t"
	TT_TEST_TMP="$(mktemp -d)"
	export TT_TEST_TMP
	# stdin is closed for each test: nothing should read it.
	# A stub or command accidentally waiting for input must fail right away,
	# not hang the whole suite.
	if ! sh "$t" < /dev/null; then
		rc=1
	fi
	rm -rf "$TT_TEST_TMP"
done

if [ "$rc" = "0" ]; then
	echo "== all tests passed"
else
	echo "== FAILURES"
fi
exit "$rc"
