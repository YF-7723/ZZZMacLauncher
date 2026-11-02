#!/bin/bash
# 便捷入口：等同于 bash scripts/setup.sh
exec bash "$(cd "$(dirname "$0")" && pwd)/scripts/setup.sh" "$@"
