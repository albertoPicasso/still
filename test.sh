#!/bin/zsh
# Ejecuta los tests. Con solo las Command Line Tools, Swift Testing necesita estas rutas.
set -euo pipefail
cd "$(dirname "$0")"

D=/Library/Developer/CommandLineTools/Library/Developer
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools ]]; then
    swift test -Xswiftc -F$D/Frameworks -Xlinker -F$D/Frameworks \
        -Xlinker -rpath -Xlinker $D/Frameworks -Xlinker -rpath -Xlinker $D/usr/lib "$@"
else
    swift test "$@"
fi
