#!/usr/bin/env bash
# Runs the headless tests (tests/Test*.tscn) and prints one line per test plus the total.
#   bash tools/run_tests.sh               # all tests
#   bash tools/run_tests.sh Terrain Wind  # only tests whose name contains one of those words
# Exits with code 1 if any test fails.
cd "$(dirname "$0")/.." || exit 1
G="${GODOT:-godot}"
# Each copy of the project gets its own user:// so parallel runs don't share saves
export XDG_DATA_HOME="$PWD/.godot/test_user"
mkdir -p "$XDG_DATA_HOME"
failures=0
total=0
for scene in tests/Test*.tscn; do
	[ -e "$scene" ] || continue
	name=$(basename "$scene" .tscn)
	if [ $# -gt 0 ]; then
		pick=0
		for f in "$@"; do case "$name" in *"$f"*) pick=1 ;; esac; done
		[ $pick = 1 ] || continue
	fi
	total=$((total + 1))
	start=$SECONDS
	out=$(timeout 600 "$G" --headless --path . "res://$scene" 2>&1)
	if echo "$out" | grep -q "RESULT: ALL GOOD" && ! echo "$out" | grep -q "SCRIPT ERROR"; then
		res="OK  "
	else
		res="FAIL"
		failures=$((failures + 1))
	fi
	echo "$res  $name ($((SECONDS - start)) s)"
	[ "$res" = "FAIL" ] && echo "$out" | grep -E "FAIL|SCRIPT ERROR|RESULT" | head -8 | sed 's/^/      /'
done
echo "TESTS: $total, $failures failures"
[ $failures = 0 ]
