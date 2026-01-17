#!/bin/sh

# Docker Compose 更新脚本 (Alpine 兼容版 - 优化版)

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数 (兼容 Alpine)
print_color() {
    printf "%b\n" "$1"
}

# 获取项目名称（优先级：命令行参数 > 环境变量 DC_NAME > 默认值）
PROJECT_NAME=${1:-${DC_NAME:-caddy}}

# 项目路径
PROJECT_PATH="/opt/${PROJECT_NAME}"

print_color "${YELLOW}========================================${NC}"
print_color "${YELLOW}Docker Compose 更新脚本${NC}"
print_color "${YELLOW}项目: ${PROJECT_NAME}${NC}"
print_color "${YELLOW}路径: ${PROJECT_PATH}${NC}"
if [ -n "$DC_NAME" ] && [ -z "$1" ]; then
    print_color "${BLUE}(通过环境变量 DC_NAME 指定)${NC}"
fi
print_color "${YELLOW}========================================${NC}"

# 检测 Docker Compose 命令
print_color ""
print_color "${BLUE}[检测] 正在检测 Docker Compose 版本...${NC}"

DOCKER_COMPOSE_CMD=""

# 优先检测 docker compose (v2)
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || docker compose version)
    print_color "${GREEN}✓ 检测到 Docker Compose V2${NC}"
    print_color "${GREEN}  版本: ${COMPOSE_VERSION}${NC}"
# 检测 docker-compose (v1)
elif command -v docker-compose > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
    COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || docker-compose version)
    print_color "${GREEN}✓ 检测到 Docker Compose V1${NC}"
    print_color "${GREEN}  版本: ${COMPOSE_VERSION}${NC}"
else
    print_color "${RED}✗ 错误: 未找到 Docker Compose!${NC}"
    print_color "${RED}  请安装 Docker Compose V2 (推荐) 或 V1${NC}"
    exit 1
fi

print_color "${YELLOW}========================================${NC}"

# 检查项目目录是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    print_color "${RED}错误: 项目目录 ${PROJECT_PATH} 不存在!${NC}"
    exit 1
fi

# 检查 docker-compose.yml 是否存在
if [ ! -f "$PROJECT_PATH/docker-compose.yml" ] && [ ! -f "$PROJECT_PATH/compose.yaml" ]; then
    print_color "${RED}错误: 在 ${PROJECT_PATH} 中未找到 docker-compose.yml 或 compose.yaml 文件!${NC}"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_PATH" || exit 1
print_color "${GREEN}✓ 已进入目录: $(pwd)${NC}"

# 拉取最新镜像
print_color ""
print_color "${YELLOW}[1/4] 正在拉取最新镜像...${NC}"
if $DOCKER_COMPOSE_CMD pull; then
    print_color "${GREEN}✓ 镜像拉取成功${NC}"
else
    print_color "${RED}✗ 镜像拉取失败${NC}"
    exit 1
fi

# 重新创建并启动容器
print_color ""
print_color "${YELLOW}[2/4] 正在重新创建并启动容器...${NC}"
if $DOCKER_COMPOSE_CMD up -d --force-recreate; then
    print_color "${GREEN}✓ 容器启动成功${NC}"
else
    print_color "${RED}✗ 容器启动失败${NC}"
    exit 1
fi

# 清理旧镜像
print_color ""
print_color "${YELLOW}[3/4] 正在清理24小时前的旧镜像...${NC}"
if docker image prune -af --filter "until=24h"; then
    print_color "${GREEN}✓ 镜像清理完成${NC}"
else
    print_color "${YELLOW}⚠ 镜像清理遇到问题,但不影响主流程${NC}"
fi

# 等待容器启动
print_color ""
print_color "${YELLOW}[4/4] 等待容器完全启动...${NC}"
sleep 3

# 显示容器状态
print_color ""
print_color "${YELLOW}========================================${NC}"
print_color "${YELLOW}容器运行状态:${NC}"
print_color "${YELLOW}========================================${NC}"
$DOCKER_COMPOSE_CMD ps

# 检查容器健康状态
print_color ""
print_color "${YELLOW}========================================${NC}"
print_color "${YELLOW}详细状态检查:${NC}"
print_color "${YELLOW}========================================${NC}"

CONTAINERS=$($DOCKER_COMPOSE_CMD ps -q)

if [ -z "$CONTAINERS" ]; then
    print_color "${YELLOW}⚠ 当前没有任何运行中的容器${NC}"
    exit 1
fi

ALL_HEALTHY="true"

for container in $CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container")
    CONTAINER_NAME=${CONTAINER_NAME#/}
    
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$container")
    CONTAINER_HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$container")
    
    if [ "$CONTAINER_STATUS" = "running" ]; then
        if [ "$CONTAINER_HEALTH" = "healthy" ] || [ "$CONTAINER_HEALTH" = "no healthcheck" ]; then
            print_color "${GREEN}✓ ${CONTAINER_NAME}: ${CONTAINER_STATUS} (${CONTAINER_HEALTH})${NC}"
        else
            print_color "${YELLOW}⚠ ${CONTAINER_NAME}: ${CONTAINER_STATUS} (${CONTAINER_HEALTH})${NC}"
            ALL_HEALTHY="false"
        fi
    else
        print_color "${RED}✗ ${CONTAINER_NAME}: ${CONTAINER_STATUS}${NC}"
        ALL_HEALTHY="false"
    fi
done

print_color ""
print_color "${YELLOW}========================================${NC}"
if [ "$ALL_HEALTHY" = "true" ]; then
    print_color "${GREEN}✓ 所有容器运行正常!${NC}"
else
    print_color "${YELLOW}⚠ 部分容器可能需要检查${NC}"
fi
print_color "${YELLOW}========================================${NC}"

# 显示日志(最后10行)
print_color ""
print_color "${YELLOW}最近日志(最后10行):${NC}"
$DOCKER_COMPOSE_CMD logs --tail=10

print_color ""
print_color "${GREEN}更新完成!${NC}"
print_color "${YELLOW}提示: 使用 '${DOCKER_COMPOSE_CMD} logs -f' 查看实时日志${NC}"
