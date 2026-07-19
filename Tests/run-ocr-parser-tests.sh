#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${TMPDIR:-/tmp}/receipt-vault-ocr-module-cache"
BINARY="${TMPDIR:-/tmp}/receipt-vault-ocr-parser-tests"

mkdir -p "$CACHE"

CLANG_MODULE_CACHE_PATH="$CACHE" \
SWIFT_MODULECACHE_PATH="$CACHE" \
xcrun swiftc \
  -module-cache-path "$CACHE" \
  "$ROOT/PrivateReceiptVault/Models/Models.swift" \
  "$ROOT/PrivateReceiptVault/Services/OCRService.swift" \
  "$ROOT/Tests/OCRParserRegressionTests.swift" \
  -o "$BINARY"

"$BINARY"
