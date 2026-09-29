#!/bin/bash
# CI-проверка: ищет TODO во всём отслеживаемом кодовом пространстве.
#
# В отличие от pre-commit хука это НЕ обходится: --no-verify действует
# только на локальную машину, а pipeline запускается на сервере.

echo "🔍 CI: проверка на TODO в Python файлах..."

# Берём только файлы, реально отслеживаемые git — venv, кэши и
# неотслеживаемое junk в кодовую базу не попадают.
TODO_FILES=$(git ls-files '*.py' | xargs grep -l "TODO" 2>/dev/null || true)

if [ -n "$TODO_FILES" ]; then
    echo "❌ CI failed: TODO found in codebase"
    echo "Файлы с TODO:"
    echo "$TODO_FILES"
    exit 1
fi

echo "✅ CI passed: TODO не найдены"
exit 0
