#!/usr/bin/env bash
# ============================================================
# New-API 中转中心 — VPS 一键部署脚本
# 
# 使用方法（在 VPS 上执行）：
#   curl -fsSL https://raw.githubusercontent.com/wuxibao53-cloud/learning-deep-learning/main/api-proxy-center/deploy_vps.sh | bash
#
# 或者手动：
#   bash deploy_vps.sh
# ============================================================

set -e

# ====== 配置 ======
VPS_IP="20.249.211.84"
DEPLOY_DIR="/opt/api-proxy-center"
PORT=3000
ADMIN_USER="root"
ADMIN_PASS="ProxyCenter2026!"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   API 中转中心 — VPS 一键部署            ║${NC}"
echo -e "${CYAN}║   目标: ${VPS_IP}:${PORT}              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ---- 1. 检查/安装 Docker ----
echo -e "${YELLOW}[1/5] 检查 Docker 环境...${NC}"
if command -v docker &>/dev/null; then
    echo -e "${GREEN}  ✓ Docker 已安装: $(docker --version)${NC}"
else
    echo -e "${YELLOW}  → 正在安装 Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}  ✓ Docker 安装完成${NC}"
fi

# 检查 Docker Compose
if docker compose version &>/dev/null; then
    echo -e "${GREEN}  ✓ Docker Compose 可用${NC}"
elif command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}  ✓ docker-compose 可用${NC}"
else
    echo -e "${YELLOW}  → 安装 Docker Compose 插件...${NC}"
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin 2>/dev/null || {
        # 如果是 CentOS/RHEL
        yum install -y docker-compose-plugin 2>/dev/null || true
    }
fi

# ---- 2. 创建部署目录和配置 ----
echo -e "\n${YELLOW}[2/5] 创建部署配置...${NC}"
mkdir -p "${DEPLOY_DIR}/data"
cd "${DEPLOY_DIR}"

cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  new-api:
    image: calciumion/new-api:latest
    container_name: api-proxy-center
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - ./data:/data
    environment:
      - SQL_DSN=
      - SESSION_SECRET=vps-proxy-session-secret-2026
      - BATCH_UPDATE_ENABLED=true
      - BATCH_UPDATE_INTERVAL=60
      - GLOBAL_API_RATE_LIMIT=120
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3
COMPOSE_EOF

echo -e "${GREEN}  ✓ 配置文件已创建: ${DEPLOY_DIR}/docker-compose.yml${NC}"

# ---- 3. 拉取镜像并启动 ----
echo -e "\n${YELLOW}[3/5] 拉取镜像并启动服务...${NC}"
docker compose pull
docker compose up -d

# 等待容器启动
echo -n "  等待服务就绪"
for i in $(seq 1 15); do
    if curl -s "http://localhost:${PORT}/api/status" &>/dev/null; then
        echo ""
        echo -e "${GREEN}  ✓ 服务启动成功！${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# 检查服务是否真正启动
if ! curl -s "http://localhost:${PORT}/api/status" &>/dev/null; then
    echo ""
    echo -e "${RED}  ✗ 服务可能未正常启动，请检查: docker logs api-proxy-center${NC}"
    exit 1
fi

# ---- 4. 注册管理员账号 ----
echo -e "\n${YELLOW}[4/5] 初始化管理员账号...${NC}"

# 检查是否已初始化
SETUP_STATUS=$(curl -s "http://localhost:${PORT}/api/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['setup'])" 2>/dev/null || echo "Unknown")

if [ "$SETUP_STATUS" = "False" ]; then
    REG_RESP=$(curl -s -X POST "http://localhost:${PORT}/api/user/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASS}\",\"email\":\"admin@proxy.local\"}")
    
    REG_OK=$(echo "$REG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
    if [ "$REG_OK" = "True" ]; then
        echo -e "${GREEN}  ✓ 管理员账号创建成功${NC}"
    else
        echo -e "${YELLOW}  ⚠ 注册响应: ${REG_RESP}${NC}"
    fi
else
    echo -e "${GREEN}  ✓ 系统已初始化，跳过注册${NC}"
fi

# ---- 5. 配置防火墙 ----
echo -e "\n${YELLOW}[5/5] 配置防火墙...${NC}"

# ufw (Ubuntu/Debian)
if command -v ufw &>/dev/null; then
    ufw allow ${PORT}/tcp 2>/dev/null && echo -e "${GREEN}  ✓ ufw 已放行端口 ${PORT}${NC}" || true
fi

# firewalld (CentOS/RHEL)
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=${PORT}/tcp 2>/dev/null && firewall-cmd --reload 2>/dev/null && echo -e "${GREEN}  ✓ firewalld 已放行端口 ${PORT}${NC}" || true
fi

# iptables fallback
if command -v iptables &>/dev/null; then
    iptables -C INPUT -p tcp --dport ${PORT} -j ACCEPT 2>/dev/null || {
        iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT 2>/dev/null && echo -e "${GREEN}  ✓ iptables 已放行端口 ${PORT}${NC}" || true
    }
fi

# ---- 完成 ----
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             部署成功！                            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}管理面板:${NC}  http://${VPS_IP}:${PORT}"
echo -e "  ${GREEN}用户名:${NC}    ${ADMIN_USER}"
echo -e "  ${GREEN}密码:${NC}      ${ADMIN_PASS}"
echo ""
echo -e "  ${GREEN}API 地址:${NC}  http://${VPS_IP}:${PORT}/v1"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo -e "  1. 浏览器打开 http://${VPS_IP}:${PORT} 登录管理面板"
echo -e "  2. 进入「渠道」→ 添加渠道 → 类型选 Google Gemini"
echo -e "  3. 填入你的 API Key"
echo -e "  4. 进入「令牌」→ 创建令牌 → 获取统一 API Key"
echo ""
echo -e "  或者运行自动配置脚本:"
echo -e "  ${CYAN}bash ${DEPLOY_DIR}/setup_channels.sh${NC}"
echo ""

# 创建管理脚本
cat > "${DEPLOY_DIR}/manage.sh" << 'MANAGE_EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
case "${1:-help}" in
  start)   docker compose up -d && echo "已启动" ;;
  stop)    docker compose down && echo "已停止" ;;
  restart) docker compose restart && echo "已重启" ;;
  logs)    docker compose logs -f --tail=100 ;;
  status)  docker compose ps ;;
  update)  docker compose pull && docker compose up -d && echo "已更新" ;;
  *)       echo "用法: $0 {start|stop|restart|logs|status|update}" ;;
esac
MANAGE_EOF
chmod +x "${DEPLOY_DIR}/manage.sh"

echo -e "  管理命令: ${CYAN}bash ${DEPLOY_DIR}/manage.sh {start|stop|restart|logs|status|update}${NC}"
echo ""
