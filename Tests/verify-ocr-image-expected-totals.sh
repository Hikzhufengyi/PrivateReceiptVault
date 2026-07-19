#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED="$ROOT/QAReceipts/en_use_cases/expected_totals.csv"
OUTPUT="${TMPDIR:-/tmp}/receipt-vault-ocr-image-integration-final.tsv"

"$ROOT/Tests/run-ocr-image-integration-tests.sh" > "$OUTPUT"

awk -F ',' '
  NR == FNR {
    if (FNR > 1) expected[$1] = $2
    next
  }
  /^FILE\t/ { file = substr($0, 6); next }
  /^RESULT\t/ {
    if (!(file in expected)) next
    result = $0
    sub(/^.*\ttotal=/, "", result)
    split(result, fields, "\t")
    actual = fields[1]
    if (actual == expected[file]) {
      print "PASS\t" file "\t" actual
    } else {
      print "FAIL\t" file "\texpected=" expected[file] "\tactual=" actual
      failures += 1
    }
    seen[file] = 1
  }
  END {
    for (file in expected) {
      if (!(file in seen)) {
        print "FAIL\t" file "\tmissing result"
        failures += 1
      }
    }
    if (failures > 0) exit 1
  }
' "$EXPECTED" "$OUTPUT"
