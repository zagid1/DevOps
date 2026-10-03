#!/bin/bash
# CI-проверка: ищет TODO во всём отслеживаемом кодовом пространстве.
#
# В отличие от pre-commit хука это НЕ обходится: --no-verify действует
# только на локальную машину, а pipeline запускается на сервере.
#
# Используется git ls-files, а не find: нужны только файлы, которые
# реально попадут в репозиторий. find обошёл бы venv (тысячи .py
# из torch и transformers) и дал бы недетерминированный результат.

echo "🔍 CI: проверка на TODO в Python файлах..."

# xargs -r: без него при пустом списке grep запускается без аргументов
# и читает stdin, то есть висит до таймаута стадии.
TODO_FILES=$(git ls-files '*.py' | xargs -r grep -l "TODO" 2>/dev/null || true)

if [ -n "$TODO_FILES" ]; then
    echo "❌ CI failed: TODO found in codebase"
    echo "Файлы с TODO:"
    echo "$TODO_FILES"
    exit 1
fi

echo "✅ CI passed: TODO не найдены"
exit 0
