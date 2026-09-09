#!/bin/sh
# Test suite runner: executes every tests/test_*.sh in its own scratch
# directory with stdin closed, and fails the run when any test fails.

set -u

# Work from the repository root, wherever the runner is invoked.
cd "$(dirname "$0")/.." || exit 1

suite_failed=0

for test_file in tests/test_*.sh; do
    [ -f "$test_file" ] || continue
    echo "== $test_file"

    tmp_dir=$(mktemp -d) || exit 1
    export TT_TEST_TMP=$tmp_dir

    sh "$test_file" < /dev/null
    test_status=$?

    rm -rf "$tmp_dir"
    if [ "$test_status" -ne 0 ]; then
        suite_failed=1
    fi
done

if [ "$suite_failed" -eq 0 ]; then
    echo "== all tests passed"
    exit 0
fi
echo "== FAILURES"
exit 1
