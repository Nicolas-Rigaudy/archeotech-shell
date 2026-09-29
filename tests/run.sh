#!/bin/bash
# tests/run.sh — QML logic tests (qmltestrunner, Qt6). Pure-logic units only:
# Quickshell's own QML types are built into the qs binary, so tests import the
# plain .js libraries the services delegate to (e.g. ShellConfigLogic.js).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
QTR="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
[ -x "$QTR" ] || QTR="$(command -v qmltestrunner6 || command -v qmltestrunner)"
TMPHOME="$(mktemp -d)"; trap 'rm -rf "$TMPHOME"' EXIT
HOME="$TMPHOME" XDG_CONFIG_HOME="$TMPHOME/.config" QT_QPA_PLATFORM=offscreen \
  "$QTR" -input tests/qml "$@"
