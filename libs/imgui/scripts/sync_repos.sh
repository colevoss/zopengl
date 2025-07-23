#!/usr/bin/env bash

IMGUI_REPO_URL="git@github.com:ocornut/imgui.git"
IMGUI_DIR="./imgui"

DEAR_BINDINGS_REPO_URL="git@github.com:dearimgui/dear_bindings.git"
DEAR_BINDINGS_DIR="./dear_bindings"

if [ -d "$IMGUI_DIR" ]; then
  echo "Syncing ImGUI"
  git -C "$IMGUI_DIR" pull
else
  echo "Cloning ImGUI (docking)"
  git clone -b docking "$IMGUI_REPO_URL" "$IMGUI_DIR"
fi

if [ -d "$DEAR_BINDINGS_DIR" ]; then
  echo "Dear Bindings ImGUI"
  git -C "$DEAR_BINDINGS_DIR" pull
else
  echo "Cloning dear_bindings"
  git clone "$DEAR_BINDINGS_REPO_URL" "$DEAR_BINDINGS_DIR"
fi
