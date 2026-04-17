#!/usr/bin/env bash
# DriveLink — llama.cpp setup script
# Run once after cloning the repo: bash scripts/setup-llama.sh

set -e

LLAMA_DIR="packages/flutter_llama/llama.cpp"

if [ -d "$LLAMA_DIR" ]; then
    echo "llama.cpp already exists at $LLAMA_DIR"
    echo "To update: cd $LLAMA_DIR && git pull"
    exit 0
fi

echo "Cloning llama.cpp (depth=1)..."
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"

echo "Done. llama.cpp ready at $LLAMA_DIR"
echo "Now run: flutter pub get && flutter build apk --debug"
