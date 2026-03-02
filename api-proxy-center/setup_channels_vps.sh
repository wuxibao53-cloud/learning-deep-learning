#!/usr/bin/env bash
# ============================================================
# VPS 渠道配置脚本 — 在 VPS 上运行
# 自动添加 Gemini 渠道 + 生成统一 API Key
# ============================================================

set -e

VPS_IP="20.249.211.84"
BASE_URL="http://localhost:3000"
USERNAME="root"
PASSWORD="ProxyCenter2026!"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  渠道配置工具 (VPS: ${VPS_IP})${NC}"
echo -e "${CYAN}========================================${NC}"

# 登录
echo -e "\n${YELLOW}[1/4] 登录...${NC}"
curl -s -c /tmp/newapi_vps_cookies -X POST "${BASE_URL}/api/user/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" > /dev/null
echo -e "${GREEN}  ✓ 已登录${NC}"

COOKIE="-b /tmp/newapi_vps_cookies"
AUTH="-H New-Api-User:1"

# 收集 API Key
echo -e "\n${YELLOW}[2/4] 输入 API Key...${NC}"
echo -e "  从 ${CYAN}https://aistudio.google.com${NC} 获取 Key"
echo ""

declare -a NAMES=()
declare -a KEYS=()

echo -e "${CYAN}项目 A: Gemini 官网${NC}"
read -p "  账号1 Key (留空跳过): " K1
[ -n "$K1" ] && NAMES+=("Gemini官网-1") && KEYS+=("$K1")
read -p "  账号2 Key (留空跳过): " K2
[ -n "$K2" ] && NAMES+=("Gemini官网-2") && KEYS+=("$K2")

echo ""
echo -e "${CYAN}项目 B: 反重力项目${NC}"
read -p "  账号3 Key (留空跳过): " K3
[ -n "$K3" ] && NAMES+=("反重力-3") && KEYS+=("$K3")
read -p "  账号4 Key (留空跳过): " K4
[ -n "$K4" ] && NAMES+=("反重力-4") && KEYS+=("$K4")

[ ${#KEYS[@]} -eq 0 ] && echo -e "${RED}未输入 Key${NC}" && exit 1

# 添加渠道
echo -e "\n${YELLOW}[3/4] 添加渠道...${NC}"
MODELS="gemini-2.5-pro-preview-05-06,gemini-2.5-flash,gemini-2.5-flash-preview-04-17,gemini-2.0-flash,gemini-2.0-flash-lite,gemini-1.5-pro,gemini-1.5-flash"

for i in "${!KEYS[@]}"; do
    RESP=$(curl -s $COOKIE $AUTH -X POST "${BASE_URL}/api/channel/" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${NAMES[$i]}\",\"type\":24,\"key\":\"${KEYS[$i]}\",\"base_url\":\"\",\"models\":\"${MODELS}\",\"group\":\"default\",\"priority\":0,\"weight\":1,\"status\":1}")
    
    OK=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('success',False))" 2>/dev/null || echo "False")
    [ "$OK" = "True" ] && echo -e "${GREEN}  ✓ ${NAMES[$i]} 添加成功${NC}" || echo -e "${RED}  ✗ ${NAMES[$i]} 失败${NC}"
done

# 生成令牌
echo -e "\n${YELLOW}[4/4] 生成统一 API Key...${NC}"
TRESP=$(curl -s $COOKIE $AUTH -X POST "${BASE_URL}/api/token/" \
  -H "Content-Type: application/json" \
  -d '{"name":"统一中转令牌","remain_quota":0,"unlimited_quota":true,"expired_time":-1}')

TOKEN=$(echo "$TRESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['key'])" 2>/dev/null || echo "(创建失败,请手动创建)")

echo ""
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${GREEN}配置完成！${NC}"
echo ""
echo -e "  API 地址:  ${CYAN}http://${VPS_IP}:3000/v1${NC}"
echo -e "  API Key:   ${CYAN}${TOKEN}${NC}"
echo ""
echo -e "  Python 示例:"
echo -e "  ${YELLOW}client = OpenAI(api_key=\"${TOKEN}\", base_url=\"http://${VPS_IP}:3000/v1\")${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
