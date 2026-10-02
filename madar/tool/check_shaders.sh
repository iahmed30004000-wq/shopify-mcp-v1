#!/usr/bin/env bash
# Compiles every shader for SkSL + SPIR-V with impellerc (fast validation
# without running Flutter). SkSL must succeed: widget-test screenshots and the
# Skia fallback need it (e.g. never pass sampler2D as a function parameter).
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_BIN="$(dirname "$(command -v flutter)")"
IMPC="$FLUTTER_BIN/cache/artifacts/engine/linux-x64/impellerc"
SHLIB="$(dirname "$IMPC")/shader_lib"
status=0
for f in $(find shaders -name '*.frag' | sort); do
  if "$IMPC" --sksl --sl=/tmp/_madar.sksl --spirv=/tmp/_madar.spv --input="$f" --input-type=frag \
      --include="$(dirname "$f")" --include=shaders --include=shaders/orbit --include="$SHLIB" >/tmp/_madar_impellerc.log 2>&1; then
    echo "ok   $f"
  else
    echo "FAIL $f"; grep -A8 -E "error|Error" /tmp/_madar_impellerc.log | head -30; status=1
  fi
done
exit $status
