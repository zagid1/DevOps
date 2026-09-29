"""Демонстрационный файл для лабораторной по Git hooks.

Проверяет, что pre-commit хук блокирует коммит с запрещёнными
комментариями, а CI-проверка ловит нарушение даже после обхода
хука через --no-verify.
"""


def main() -> None:
    """Выводит приветствие (через логгер, а не print — иначе ругается ruff T201)."""
    import logging

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    logging.getLogger(__name__).info("hello")


if __name__ == "__main__":
    main()
