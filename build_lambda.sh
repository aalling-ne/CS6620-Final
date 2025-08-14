#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="lambda_build"
ZIP_OUT="terraform/etl_package.zip"

rm -rf "$BUILD_DIR" "$ZIP_OUT"
mkdir -p "$BUILD_DIR"

cp etl_script.py "$BUILD_DIR/"

pip install --upgrade pip >/dev/null
pip install --target "$BUILD_DIR" sodapy requests >/dev/null

(
  cd "$BUILD_DIR"
  zip -r9 "../$ZIP_OUT" . >/dev/null
)
echo "Built $ZIP_OUT"