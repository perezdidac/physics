#!/usr/bin/env bash
# Quality check: loads every project script with ALL GDScript warnings turned into errors.
# Usage: bash tools/lint.sh   (prints "LINT: N scripts, 0 failures"; exit code 0 only when clean)
cd "$(dirname "$0")/.." || exit 1
G="${GODOT:-godot}"
cat > override.cfg <<'CFG'
[debug]

gdscript/warnings/enable=true
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unused_private_class_variable=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/shadowed_variable_base_class=2
gdscript/warnings/shadowed_global_identifier=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/unreachable_pattern=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/standalone_ternary=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/redundant_await=2
gdscript/warnings/int_as_enum_without_cast=2
gdscript/warnings/static_called_on_instance=2
gdscript/warnings/confusable_identifier=2
CFG
out=$("$G" --headless --path . res://tools/Lint.tscn 2>&1 | grep -E "LINT|FAIL|Parse Error|SCRIPT ERROR|at: GDScript::reload")
rm -f override.cfg
echo "$out"
echo "$out" | grep -q "LINT: [0-9]* scripts, 0 failures" && ! echo "$out" | grep -qE "Parse Error|SCRIPT ERROR"
