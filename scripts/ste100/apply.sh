#!/usr/bin/env bash
# Install a local ASD-STE100 Issue 9 copy for agents: the PDF, ste100.md, and dictionary.json.
# The standard is CC BY-NC-ND 4.0 and ASD forbids reproduction without its written authority,
# so this public repo keeps only scripts. The PDF comes from Zenodo at install time.
# Usage: apply.sh [local-ASD-STE100_ISSUE9.pdf]   (a local file must have the same checksum)
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RECORD=23666006
FILE=ASD-STE100_ISSUE9.pdf
MD5=9c720341c350ed77943b2c73d01c716f
URL="https://zenodo.org/api/records/$RECORD/files/$FILE/content"
DATA_DIR="${STE100_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ste100/issue9}"
VENV="${XDG_CACHE_HOME:-$HOME/.cache}/personal-settings/ste100-venv"
PDFPLUMBER_VERSION=0.11.7
SOURCE_PDF="${1:-}"

missing=()
for tool in curl md5sum jq; do
  command -v "$tool" > /dev/null || missing+=("$tool")
done
if ! command -v uv > /dev/null && ! python3 -c 'import ensurepip, venv' 2> /dev/null; then
  missing+=("uv or python3-venv")
fi
if ((${#missing[@]})); then
  echo "missing tools: ${missing[*]} (Ubuntu: sudo apt install curl jq python3-venv)" >&2
  exit 1
fi

mkdir -p "$(dirname "$DATA_DIR")"
STAGE="$(mktemp -d "$(dirname "$DATA_DIR")/.stage.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT

has_md5() {
  [[ -f "$1" ]] && [[ "$(md5sum "$1" | cut -d' ' -f1)" == "$MD5" ]]
}

ensure_venv() {
  local check="import pdfplumber; assert pdfplumber.__version__ == '$PDFPLUMBER_VERSION'"
  if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c "$check" 2> /dev/null; then
    return
  fi
  if command -v uv > /dev/null; then
    uv venv -q --clear "$VENV"
    uv pip install -q --python "$VENV/bin/python" "pdfplumber==$PDFPLUMBER_VERSION"
  else
    python3 -m venv --clear "$VENV"
    "$VENV/bin/pip" install -q "pdfplumber==$PDFPLUMBER_VERSION"
  fi
  "$VENV/bin/python" -c "$check"
}

fetch_pdf() {
  local target="$STAGE/$FILE"
  if [[ -n "$SOURCE_PDF" ]]; then
    cp -- "$SOURCE_PDF" "$target"
  elif has_md5 "$DATA_DIR/$FILE"; then
    cp -- "$DATA_DIR/$FILE" "$target"
  else
    curl -fsSL --retry 3 --retry-connrefused --max-time 300 -o "$target" "$URL"
  fi
  if ! has_md5 "$target"; then
    echo "checksum mismatch for $FILE (expected md5 $MD5)" >&2
    exit 1
  fi
}

install_data() {
  "$VENV/bin/python" "$REPO/scripts/ste100/extract.py" "$STAGE/$FILE" "$STAGE"
  chmod 0755 "$STAGE"
  chmod 0644 "$STAGE"/*
  # Check the new data before it replaces the installed copy.
  STE100_DIR="$STAGE" "$REPO/scripts/ste100/verify.sh" --data-only
  local old="$DATA_DIR.old.$$"
  rm -rf -- "$DATA_DIR".old.*
  if [[ -d "$DATA_DIR" ]]; then
    mv -- "$DATA_DIR" "$old"
  fi
  if ! mv -- "$STAGE" "$DATA_DIR"; then
    if [[ -d "$old" ]]; then
      mv -- "$old" "$DATA_DIR"
    fi
    echo "could not install $DATA_DIR; the previous data is kept" >&2
    exit 1
  fi
  rm -rf -- "$old"
}

ensure_venv
fetch_pdf
install_data
"$REPO/scripts/ste100/verify.sh"
echo "installed: $DATA_DIR"
