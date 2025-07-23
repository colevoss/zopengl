#!/usr/bin/env bash

DEAR_BINDINGS_DIR="./dear_bindings"
GENERATED_DIR="./generated"

cd "$DEAR_BINDINGS_DIR"

if [ -d "$GENERATED_DIR" ]; then
  rm -rf "$GENERATED_DIR"
fi

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

chmod +x ./BuildAllBindings.sh

./BuildAllBindings.sh

deactivate
