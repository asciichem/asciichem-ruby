#!/usr/bin/env bash
# Re-vendor the asciichem-model v1 JSON Schemas (YAML) and examples.
# Usage: scripts/update-model-schemas.sh [model-tag] (default: main).
set -euo pipefail

tag="${1:-main}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone --depth 1 --branch "$tag" https://github.com/asciichem/asciichem-model.git "$work/model"

python3 - "$work/model" <<'PY'
import os, shutil, sys
src = os.path.join(sys.argv[1], "schemas", "v1")
dst = "spec/schemas"
if os.path.exists(dst):
    shutil.rmtree(dst)
os.makedirs(dst)
for name in os.listdir(src):
    if name.endswith(".yaml"):
        shutil.copy(os.path.join(src, name), os.path.join(dst, name))
shutil.copytree(os.path.join(src, "examples"), os.path.join(dst, "examples"))
print("vendored", len([f for f in os.listdir(dst) if f.endswith('.yaml')]), "schemas")
PY

echo "spec/schemas updated from asciichem-model $tag"
