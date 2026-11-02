#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports
gcc --version >reports/reference_compiler.txt
gcc -std=c11 -O2 -Wall -Wextra -Werror -shared -fPIC src/sobel.c -o build/sobel.so
python3 scripts/reference.py
