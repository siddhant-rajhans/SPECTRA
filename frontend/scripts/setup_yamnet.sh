#!/usr/bin/env bash
# Downloads the YAMNet TFLite model + AudioSet class map into
# frontend/assets/models so the SPECTRA app can run on-device sound classification.
#
# Re-running is idempotent — files only download if missing.
#
# Usage:
#   ./scripts/setup_yamnet.sh              # default URLs
#   YAMNET_TFLITE_URL=...  ./scripts/setup_yamnet.sh   # override

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets/models"
mkdir -p "$ASSETS_DIR"

MODEL_URL="${YAMNET_TFLITE_URL:-https://www.kaggle.com/api/v1/models/google/yamnet/tfLite/classification-tflite/1/download}"
LABELS_URL="${YAMNET_LABELS_URL:-https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv}"

MODEL_FILE="$ASSETS_DIR/yamnet.tflite"
LABELS_FILE="$ASSETS_DIR/yamnet_class_map.csv"

download() {
  local url="$1"
  local out="$2"
  if [ -f "$out" ] && [ "$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")" -gt 1024 ]; then
    echo "  [skip] $(basename "$out") already present"
    return
  fi
  echo "  [get]  $url"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --progress-bar -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --show-progress -O "$out" "$url"
  else
    echo "Need curl or wget on PATH" >&2
    exit 1
  fi
}

echo "Fetching YAMNet assets…"
download "$LABELS_URL" "$LABELS_FILE"

# A valid TFLite model starts with bytes "....TFL3" at offset 4. If we already
# have one, skip the download.
is_valid_tflite() {
  [ -f "$1" ] && [ "$(dd if="$1" bs=1 skip=4 count=4 2>/dev/null)" = "TFL3" ]
}

if is_valid_tflite "$MODEL_FILE"; then
  echo "  [skip] yamnet.tflite already valid"
else
  download "$MODEL_URL" "$MODEL_FILE.download"
  TMP_DIR="$(mktemp -d)"
  ARCHIVE="$MODEL_FILE.download"

  # Kaggle delivers a gzip'd tar containing a single .tflite. Detect format
  # via magic bytes.
  HEADER="$(dd if="$ARCHIVE" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  case "$HEADER" in
    1f8b*)
      echo "  [extract] gzip → $TMP_DIR"
      gunzip -c "$ARCHIVE" > "$TMP_DIR/payload"
      # Inner payload is usually a tar (Kaggle); fall through to tar handling.
      INNER_HEADER="$(dd if="$TMP_DIR/payload" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')"
      if file "$TMP_DIR/payload" 2>/dev/null | grep -qi 'tar archive' || \
         tar -tf "$TMP_DIR/payload" >/dev/null 2>&1; then
        tar -xf "$TMP_DIR/payload" -C "$TMP_DIR"
      fi
      ;;
    504b*)
      echo "  [extract] zip → $TMP_DIR"
      unzip -q "$ARCHIVE" -d "$TMP_DIR"
      ;;
    *)
      cp "$ARCHIVE" "$TMP_DIR/yamnet.tflite"
      ;;
  esac

  TFLITE_PATH="$(find "$TMP_DIR" -name '*.tflite' | head -n1)"
  if [ -z "$TFLITE_PATH" ]; then
    echo "Could not locate .tflite inside the downloaded archive" >&2
    exit 1
  fi
  mv "$TFLITE_PATH" "$MODEL_FILE"
  rm -rf "$TMP_DIR" "$ARCHIVE"

  if ! is_valid_tflite "$MODEL_FILE"; then
    echo "Downloaded file is not a valid TFLite model (TFL3 magic missing)" >&2
    exit 1
  fi
fi

echo
echo "Done. Files in $ASSETS_DIR:"
ls -lh "$ASSETS_DIR"
