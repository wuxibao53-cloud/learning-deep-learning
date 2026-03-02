#!/usr/bin/env bash
# ============================================================
# New-API 中转中心 - 一键配置脚本
# 功能：自动添加 Gemini 渠道 + 生成统一 API Key
# ============================================================

set -e

BASE_URL="http://localhost:3000"
USERNAME="root"
PASSWORD="ProxyCenter2026!"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  New-API 中转中心 配置工具${NC}"
echo -e "${CYAN}========================================${NC}"

# ---- 1. 登录 ----
echo -e "\n${YELLOW}[1/4] 登录管理后台...${NC}"
curl -s -c /tmp/newapi_setup_cookies -X POST "${BASE_URL}/api/user/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" > /dev/null

COOKIE_FILE="/tmp/newapi_setup_cookies"
AUTH_HEADER="New-Api-User: 1"

# 测试认证
TEST=$(curl -s -b "$COOKIE_FILE" -H "$AUTH_HEADER" "${BASE_URL}/api/channel/" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))")
if [ "$TEST" != "True" ]; then
    echo -e "${RED}登录失败，请检查用户名密码${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ 登录成功${NC}"

# ---- 2. 添加渠道 ----
echo -e "\n${YELLOW}[2/4] 配置 Gemini API 渠道...${NC}"
echo -e "  请输入你的 API Key（从 https://aistudio.google.com 获取）"
echo ""

# 渠道配置数组
declare -a CHANNEL_NAMES=()
declare -a CHANNEL_KEYS=()

# 项目 A: Gemini 官网账号
echo -e "${CYAN}--- 项目 A: Gemini 官网接口 ---${NC}"
read -p "  账号 1 的 API Key (留空跳过): " KEY_A1
if [ -n "$KEY_A1" ]; then
    CHANNEL_NAMES+=("Gemini-官网-账号1")
    CHANNEL_KEYS+=("$KEY_A1")
fi

read -p "  账号 2 的 API Key (留空跳过): " KEY_A2
if [ -n "$KEY_A2" ]; then
    CHANNEL_NAMES+=("Gemini-官网-账号2")
    CHANNEL_KEYS+=("$KEY_A2")
fi

echo ""
echo -e "${CYAN}--- 项目 B: 谷歌反重力项目 ---${NC}"
read -p "  账号 3 的 API Key (留空跳过): " KEY_B1
if [ -n "$KEY_B1" ]; then
    CHANNEL_NAMES+=("Gemini-反重力-账号3")
    CHANNEL_KEYS+=("$KEY_B1")
fi

read -p "  账号 4 的 API Key (留空跳过): " KEY_B2
if [ -n "$KEY_B2" ]; then
    CHANNEL_NAMES+=("Gemini-反重力-账号4")
    CHANNEL_KEYS+=("$KEY_B2")
fi

if [ ${#CHANNEL_KEYS[@]} -eq 0 ]; then
    echo -e "${RED}未输入任何 API Key，退出${NC}"
    exit 1
fi

# Gemini 模型列表
MODELS="gemini-2.5-pro-preview-05-06,gemini-2.5-flash,gemini-2.5-flash-preview-04-17,gemini-2.0-flash,gemini-2.0-flash-lite,gemini-1.5-pro,gemini-1.5-flash"

CHANNEL_IDS=()
for i in "${!CHANNEL_KEYS[@]}"; do
    NAME="${CHANNEL_NAMES[$i]}"
    KEY="${CHANNEL_KEYS[$i]}"
    
    # type 24 = Google Gemini AI Studio
    RESP=$(curl -s -b "$COOKIE_FILE" -H "$AUTH_HEADER" -X POST "${BASE_URL}/api/channel/" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${NAME}\",
        \"type\": 24,
        \"key\": \"${KEY}\",
        \"base_url\": \"\",
        \"models\": \"${MODELS}\",
        \"model_mapping\": \"\",
        \"group\": \"default\",
        \"priority\": 0,
        \"weight\": 1,
        \"status\": 1
      }")

    SUCCESS=$(echo "$RESP" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('success', False))" 2>/dev/null || echo "False")
    
    if [ "$SUCCESS" = "True" ]; then
        CH_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('id','?'))" 2>/dev/null || echo "?")
        CHANNEL_IDS+=("$CH_ID")
        echo -e "${GREEN}  ✓ 渠道 [${NAME}] 创建成功 (ID: ${CH_ID})${NC}"
    else
        MSG=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','未知错误'))" 2>/dev/null || echo "$RESP")
        echo -e "${RED}  ✗ 渠道 [${NAME}] 创建失败: ${MSG}${NC}"
    fi
done

# ---- 3. 测试渠道连通性 ----
echo -e "\n${YELLOW}[3/4] 测试渠道连通性...${NC}"
for CH_ID in "${CHANNEL_IDS[@]}"; do
    RESP=$(curl -s -b "$COOKIE_FILE" -H "$AUTH_HEADER" "${BASE_URL}/api/channel/test/${CH_ID}" 2>&1)
    SUCCESS=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
    if [ "$SUCCESS" = "True" ]; then
        echo -e "${GREEN}  ✓ 渠道 ${CH_ID} 连通正常${NC}"
    else
        MSG=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','测试失败'))" 2>/dev/null || echo "未知")
        echo -e "${YELLOW}  ⚠ 渠道 ${CH_ID}: ${MSG}${NC}"
    fi
done

# ---- 4. 生成统一 API Token ----
echo -e "\n${YELLOW}[4/4] 生成统一 API 令牌...${NC}"

TOKEN_RESP=$(curl -s -b "$COOKIE_FILE" -H "$AUTH_HEADER" -X POST "${BASE_URL}/api/token/" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "统一中转令牌",
    "remain_quota": 0,
    "unlimited_quota": true,
    "expired_time": -1,
    "models": [],
    "subnet": ""
  }')

TOKEN_SUCCESS=$(echo "$TOKEN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")

if [ "$TOKEN_SUCCESS" = "True" ]; then
    TOKEN_KEY=$(echo "$TOKEN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])" 2>/dev/null)
    echo -e "${GREEN}  ✓ 令牌创建成功${NC}"
else
    echo -e "${RED}  ✗ 令牌创建失败: ${TOKEN_RESP}${NC}"
    TOKEN_KEY="(请手动在管理面板创建)"
fi

# ---- 汇总 ----
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  配置完成！以下是你的中转信息：${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "  ${GREEN}管理面板:${NC}    ${BASE_URL}"
echo -e "  ${GREEN}用户名:${NC}      ${USERNAME}"
echo -e "  ${GREEN}密码:${NC}        ${PASSWORD}"
echo ""
echo -e "  ${GREEN}API 地址:${NC}    ${BASE_URL}/v1"
echo -e "  ${GREEN}API Key:${NC}     ${TOKEN_KEY}"
echo ""
echo -e "  ${GREEN}已配置渠道:${NC}  ${#CHANNEL_IDS[@]} 个 (负载均衡: 轮询模式)"
echo -e "  ${GREEN}支持模型:${NC}    ${MODELS}"
echo ""
echo -e "${YELLOW}使用方式（在你的其他项目中）:${NC}"
echo ""
echo -e "  # Python (openai 库)"
echo -e "  from openai import OpenAI"
echo -e "  client = OpenAI("
echo -e "      api_key=\"${TOKEN_KEY}\","
echo -e "      base_url=\"${BASE_URL}/v1\""
echo -e "  )"
echo -e "  resp = client.chat.completions.create("
echo -e "      model=\"gemini-2.5-flash\","
echo -e "      messages=[{\"role\": \"user\", \"content\": \"你好\"}]"
echo -e "  )"
echo ""
echo -e "  # curl"
echo -e "  curl ${BASE_URL}/v1/chat/completions \\"
echo -e "    -H \"Authorization: Bearer ${TOKEN_KEY}\" \\"
echo -e "    -H \"Content-Type: application/json\" \\"
echo -e "    -d '{\"model\":\"gemini-2.5-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
echo ""
echo -e "${CYAN}========================================${NC}"
