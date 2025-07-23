#!/usr/bin/env bash

IMGUI_DIR="./imgui"
DEAR_BINDINGS_DIR="./dear_bindings/generated"
DESTINATION_DIR="./include"

if [ -d "$DESTINATION_DIR" ]; then
  rm -rf "$DESTINATION_DIR"
fi

mkdir "$DESTINATION_DIR"


echo "Copying files from dear_bindings..."
for filename in $DEAR_BINDINGS_DIR/*.{cpp,h}; do
  base=$(basename "$filename")
  cp "$filename" "$DESTINATION_DIR/$base"
done

echo "Copying files from dear_bindings backends"
for filename in $DEAR_BINDINGS_DIR/backends/*.{cpp,h}; do
  base=$(basename "$filename")
  cp "$filename" "$DESTINATION_DIR/$base"
done

echo "Copying files from imgui"

IMCONFIG="$IMGUI_DIR/imconfig.h"
IMCONFIG_DEST="$DESTINATION_DIR/imconfig.h"

cp "$IMCONFIG" "$IMCONFIG_DEST"

for filename in $IMGUI_DIR/imstb*; do
  base=$(basename "$filename")
  cp "$filename" "$DESTINATION_DIR/$base"
done

for filename in $IMGUI_DIR/imgui*; do
  base=$(basename "$filename")
  cp "$filename" "$DESTINATION_DIR/$base"
done

for filename in $IMGUI_DIR/backends/*.{cpp,h}; do
  base=$(basename "$filename")
  cp "$filename" "$DESTINATION_DIR/$base"
done
