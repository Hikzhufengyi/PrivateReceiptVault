#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${TMPDIR:-/tmp}/receipt-vault-ocr-image-module-cache"
BINARY="${TMPDIR:-/tmp}/receipt-vault-ocr-image-integration-tests"
INPUT="${1:-$ROOT/QAReceipts/en_use_cases}"

mkdir -p "$CACHE"

CLANG_MODULE_CACHE_PATH="$CACHE" \
SWIFT_MODULECACHE_PATH="$CACHE" \
xcrun swiftc \
  -module-cache-path "$CACHE" \
  -framework AppKit \
  -framework Vision \
  "$ROOT/PrivateReceiptVault/Models/Models.swift" \
  "$ROOT/PrivateReceiptVault/Services/OCRService.swift" \
  "$ROOT/Tests/OCRImageIntegrationRunner.swift" \
  -o "$BINARY"

"$BINARY" "$INPUT"
