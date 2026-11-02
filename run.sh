#!/bin/bash
# 便捷入口：等同于 bash scripts/launch-zzz.sh
exec bash "$(cd "$(dirname "$0")" && pwd)/scripts/launch-zzz.sh" "$@"
