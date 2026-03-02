#!/usr/bin/env bash
# 中转中心管理脚本
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

case "${1:-help}" in
  start)
    echo "启动中转中心..."
    docker compose up -d
    echo "已启动: http://localhost:3000"
    ;;
  stop)
    echo "停止中转中心..."
    docker compose down
    ;;
  restart)
    echo "重启中转中心..."
    docker compose restart
    ;;
  logs)
    docker compose logs -f --tail=50
    ;;
  status)
    docker compose ps
    curl -s http://localhost:3000/api/status | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
print(f\"系统: {d['system_name']} v{d['version']}\")
print(f\"状态: 运行中\")
" 2>/dev/null || echo "服务未响应"
    ;;
  setup)
    bash "$DIR/setup_channels.sh"
    ;;
  update)
    echo "更新镜像..."
    docker compose pull
    docker compose up -d
    echo "更新完成"
    ;;
  *)
    echo "用法: $0 {start|stop|restart|logs|status|setup|update}"
    echo ""
    echo "  start   - 启动中转中心"
    echo "  stop    - 停止中转中心"
    echo "  restart - 重启"
    echo "  logs    - 查看实时日志"
    echo "  status  - 查看运行状态"
    echo "  setup   - 配置渠道和令牌"
    echo "  update  - 更新到最新版本"
    ;;
esac
