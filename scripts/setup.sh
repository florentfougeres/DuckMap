#!/usr/bin/env bash
# Downloads the DuckDB native library required to build DuckMap.
# Run once after cloning: ./scripts/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$ROOT/DuckDBLib"

echo "→ Downloading DuckDB universal library…"
mkdir -p "$LIB_DIR"
curl -L "https://github.com/duckdb/duckdb/releases/latest/download/libduckdb-osx-universal.zip" \
  -o /tmp/libduckdb.zip
unzip -o /tmp/libduckdb.zip -d "$LIB_DIR"
rm /tmp/libduckdb.zip

echo "✓ DuckDB library installed in DuckDBLib/"
echo "  Open DuckMap.xcodeproj and build (Cmd+B)."
