#!/bin/sh

# V2Ray 卸载脚本 - 通用版本
# 支持系统: Alpine Linux, Debian, Ubuntu, CentOS, Fedora
# 使用方法: sh uninstall_v2ray.sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
OS_TYPE=""
INIT_SYSTEM=""
PKG_MANAGER=""

# 打印信息函数
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_step() {
    printf "${BLUE}[STEP]${NC} %s\n" "$1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

# 检测操作系统类型
detect_os() {
    print_info "检测操作系统类型..."
    
    # 检测 Alpine Linux
    if [ -f /etc/alpine-release ]; then
        OS_TYPE="alpine"
        INIT_SYSTEM="openrc"
        PKG_MANAGER="apk"
        OS_VERSION=$(cat /etc/alpine-release)
        print_info "检测到 Alpine Linux $OS_VERSION"
        return
    fi
    
    # 检测其他 Linux 发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                OS_TYPE="debian"
                PKG_MANAGER="apt"
                ;;
            centos|rhel|fedora)
                OS_TYPE="redhat"
                if command -v dnf >/dev/null 2>&1; then
                    PKG_MANAGER="dnf"
                else
                    PKG_MANAGER="yum"
                fi
                ;;
            opensuse*|sles)
                OS_TYPE="suse"
                PKG_MANAGER="zypper"
                ;;
            arch|manjaro)
                OS_TYPE="arch"
                PKG_MANAGER="pacman"
                ;;
            *)
                print_warning "未识别的操作系统: $ID，将尝试通用卸载方法"
                OS_TYPE="unknown"
                ;;
        esac
        
        # 检测 init 系统
        if [ -d /run/systemd/system ]; then
            INIT_SYSTEM="systemd"
        elif command -v rc-service >/dev/null 2>&1; then
            INIT_SYSTEM="openrc"
        else
            print_warning "无法检测 init 系统类型"
            INIT_SYSTEM="unknown"
        fi
        
        if [ "$OS_TYPE" != "unknown" ]; then
            print_info "检测到 $NAME"
            print_info "Init 系统: $INIT_SYSTEM"
        fi
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi
}

# 确认卸载
confirm_uninstall() {
    echo ""
    print_warning "=============================================="
    print_warning "  即将卸载 V2Ray 及相关文件"
    print_warning "=============================================="
    echo ""
    echo "系统信息："
    echo "  操作系统: $OS_TYPE"
    echo "  Init 系统: $INIT_SYSTEM"
    echo ""
    echo "将要删除的内容："
    echo "  • V2Ray 二进制文件"
    echo "  • V2Ray 配置文件"
    echo "  • V2Ray 日志文件"
    echo "  • V2Ray 服务文件"
    echo "  • V2Ray 连接信息文件"
    echo ""
    print_warning "注意: 此操作不可恢复！"
    echo ""
    
    printf "确定要继续卸载吗? (yes/no): "
    read CONFIRM
    
    if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "YES" ] && [ "$CONFIRM" != "Y" ]; then
        print_info "取消卸载操作"
        exit 0
    fi
    
    echo ""
    print_info "开始卸载..."
}

# 停止服务 - OpenRC
stop_service_openrc() {
    if [ -f /etc/init.d/v2ray ]; then
        print_step "停止 V2Ray 服务 (OpenRC)..."
        
        # 检查服务是否在运行
        if rc-service v2ray status >/dev/null 2>&1; then
            rc-service v2ray stop || true
            print_info "V2Ray 服务已停止"
        else
            print_info "V2Ray 服务未在运行"
        fi
        
        # 从开机自启中移除
        if rc-update show default | grep -q v2ray; then
            rc-update del v2ray default || true
            print_info "已从开机自启中移除"
        fi
    else
        print_info "未找到 V2Ray OpenRC 服务"
    fi
}

# 停止服务 - Systemd
stop_service_systemd() {
    if systemctl list-unit-files | grep -q v2ray; then
        print_step "停止 V2Ray 服务 (Systemd)..."
        
        # 检查服务是否在运行
        if systemctl is-active --quiet v2ray 2>/dev/null; then
            systemctl stop v2ray || true
            print_info "V2Ray 服务已停止"
        else
            print_info "V2Ray 服务未在运行"
        fi
        
        # 禁用开机自启
        if systemctl is-enabled --quiet v2ray 2>/dev/null; then
            systemctl disable v2ray || true
            print_info "已禁用开机自启"
        fi
    else
        print_info "未找到 V2Ray Systemd 服务"
    fi
}

# 停止服务
stop_service() {
    if [ "$INIT_SYSTEM" = "openrc" ]; then
        stop_service_openrc
    elif [ "$INIT_SYSTEM" = "systemd" ]; then
        stop_service_systemd
    else
        print_warning "未知的 init 系统，跳过服务停止"
    fi
}

# 使用官方脚本卸载 - Systemd 系统
uninstall_v2ray_systemd_official() {
    print_step "使用官方脚本卸载 V2Ray (Systemd 系统)..."
    
    # 检查是否能访问 GitHub
    if ! curl -s --connect-timeout 5 https://raw.githubusercontent.com >/dev/null 2>&1; then
        print_warning "无法访问 GitHub，将使用手动卸载方法"
        return 1
    fi
    
    # 创建临时文件
    TEMP_SCRIPT=$(mktemp)
    
    # 下载卸载脚本
    print_info "正在下载官方卸载脚本..."
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$TEMP_SCRIPT" https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh; then
            print_warning "下载官方卸载脚本失败，将使用手动卸载方法"
            rm -f "$TEMP_SCRIPT"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$TEMP_SCRIPT" https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh; then
            print_warning "下载官方卸载脚本失败，将使用手动卸载方法"
            rm -f "$TEMP_SCRIPT"
            return 1
        fi
    else
        print_warning "需要 curl 或 wget 来下载卸载脚本"
        rm -f "$TEMP_SCRIPT"
        return 1
    fi
    
    # 执行卸载脚本
    print_info "正在执行官方卸载脚本..."
    if command -v bash >/dev/null 2>&1; then
        if bash "$TEMP_SCRIPT" --remove; then
            rm -f "$TEMP_SCRIPT"
            print_info "官方脚本卸载成功"
            return 0
        else
            print_warning "官方卸载脚本执行失败，将使用手动卸载方法"
            rm -f "$TEMP_SCRIPT"
            return 1
        fi
    else
        if sh "$TEMP_SCRIPT" --remove; then
            rm -f "$TEMP_SCRIPT"
            print_info "官方脚本卸载成功"
            return 0
        else
            print_warning "官方卸载脚本执行失败，将使用手动卸载方法"
            rm -f "$TEMP_SCRIPT"
            return 1
        fi
    fi
}

# 手动卸载 V2Ray 二进制文件
uninstall_v2ray_binaries() {
    print_step "删除 V2Ray 二进制文件..."
    
    REMOVED=0
    
    # 删除 v2ray 主程序
    if [ -f /usr/local/bin/v2ray ]; then
        rm -f /usr/local/bin/v2ray
        print_info "已删除: /usr/local/bin/v2ray"
        REMOVED=1
    fi
    
    # 删除 v2ctl（旧版本）
    if [ -f /usr/local/bin/v2ctl ]; then
        rm -f /usr/local/bin/v2ctl
        print_info "已删除: /usr/local/bin/v2ctl"
        REMOVED=1
    fi
    
    # 删除 v2ray（在 /usr/bin 中，某些安装方式）
    if [ -f /usr/bin/v2ray ]; then
        rm -f /usr/bin/v2ray
        print_info "已删除: /usr/bin/v2ray"
        REMOVED=1
    fi
    
    if [ $REMOVED -eq 0 ]; then
        print_info "未找到 V2Ray 二进制文件"
    fi
}

# 卸载 Alpine 包
uninstall_alpine_package() {
    print_step "卸载 Alpine V2Ray 软件包..."
    
    if command -v apk >/dev/null 2>&1; then
        if apk info -e v2ray >/dev/null 2>&1; then
            apk del v2ray v2ray-openrc || true
            print_info "已卸载 Alpine V2Ray 软件包"
        else
            print_info "未通过 apk 安装 V2Ray"
        fi
    fi
}

# 删除数据文件
remove_data_files() {
    print_step "删除 V2Ray 数据文件..."
    
    REMOVED=0
    
    # 删除 share 目录（geoip.dat, geosite.dat）
    if [ -d /usr/local/share/v2ray ]; then
        rm -rf /usr/local/share/v2ray
        print_info "已删除: /usr/local/share/v2ray"
        REMOVED=1
    fi
    
    # 删除其他可能的数据目录
    if [ -d /usr/share/v2ray ]; then
        rm -rf /usr/share/v2ray
        print_info "已删除: /usr/share/v2ray"
        REMOVED=1
    fi
    
    if [ $REMOVED -eq 0 ]; then
        print_info "未找到 V2Ray 数据文件"
    fi
}

# 删除配置文件
remove_config_files() {
    print_step "删除 V2Ray 配置文件..."
    
    REMOVED=0
    
    # 删除主配置目录
    if [ -d /usr/local/etc/v2ray ]; then
        rm -rf /usr/local/etc/v2ray
        print_info "已删除: /usr/local/etc/v2ray"
        REMOVED=1
    fi
    
    # 删除其他可能的配置目录
    if [ -d /etc/v2ray ]; then
        rm -rf /etc/v2ray
        print_info "已删除: /etc/v2ray"
        REMOVED=1
    fi
    
    if [ $REMOVED -eq 0 ]; then
        print_info "未找到 V2Ray 配置文件"
    fi
}

# 删除日志文件
remove_log_files() {
    print_step "删除 V2Ray 日志文件..."
    
    if [ -d /var/log/v2ray ]; then
        rm -rf /var/log/v2ray
        print_info "已删除: /var/log/v2ray"
    else
        print_info "未找到 V2Ray 日志文件"
    fi
}

# 删除服务文件 - Systemd
remove_systemd_service() {
    print_step "删除 Systemd 服务文件..."
    
    REMOVED=0
    
    # 删除主服务文件
    if [ -f /etc/systemd/system/v2ray.service ]; then
        rm -f /etc/systemd/system/v2ray.service
        print_info "已删除: /etc/systemd/system/v2ray.service"
        REMOVED=1
    fi
    
    # 删除实例服务文件
    if [ -f /etc/systemd/system/v2ray@.service ]; then
        rm -f /etc/systemd/system/v2ray@.service
        print_info "已删除: /etc/systemd/system/v2ray@.service"
        REMOVED=1
    fi
    
    # 删除服务配置目录
    if [ -d /etc/systemd/system/v2ray.service.d ]; then
        rm -rf /etc/systemd/system/v2ray.service.d
        print_info "已删除: /etc/systemd/system/v2ray.service.d"
        REMOVED=1
    fi
    
    if [ -d /etc/systemd/system/v2ray@.service.d ]; then
        rm -rf /etc/systemd/system/v2ray@.service.d
        print_info "已删除: /etc/systemd/system/v2ray@.service.d"
        REMOVED=1
    fi
    
    # 重载 systemd
    if [ $REMOVED -eq 1 ]; then
        systemctl daemon-reload || true
        print_info "已重载 Systemd"
    else
        print_info "未找到 Systemd 服务文件"
    fi
}

# 删除服务文件 - OpenRC
remove_openrc_service() {
    print_step "删除 OpenRC 服务文件..."
    
    if [ -f /etc/init.d/v2ray ]; then
        rm -f /etc/init.d/v2ray
        print_info "已删除: /etc/init.d/v2ray"
    else
        print_info "未找到 OpenRC 服务文件"
    fi
}

# 删除服务文件
remove_service_files() {
    if [ "$INIT_SYSTEM" = "systemd" ]; then
        remove_systemd_service
    elif [ "$INIT_SYSTEM" = "openrc" ]; then
        remove_openrc_service
    else
        print_warning "未知的 init 系统，跳过服务文件删除"
    fi
}

# 删除连接信息文件
remove_info_file() {
    print_step "删除连接信息文件..."
    
    if [ -f /root/v2ray_info.txt ]; then
        rm -f /root/v2ray_info.txt
        print_info "已删除: /root/v2ray_info.txt"
    else
        print_info "未找到连接信息文件"
    fi
}

# 删除其他残留文件
remove_other_files() {
    print_step "检查其他残留文件..."
    
    REMOVED=0
    
    # 检查 /usr/bin/v2ray 目录（旧安装方式）
    if [ -d /usr/bin/v2ray ]; then
        rm -rf /usr/bin/v2ray
        print_info "已删除: /usr/bin/v2ray"
        REMOVED=1
    fi
    
    # 检查其他可能的配置备份
    if [ -f /root/config.json.backup ]; then
        print_info "发现配置备份: /root/config.json.backup (保留)"
    fi
    
    if [ $REMOVED -eq 0 ]; then
        print_info "未发现其他残留文件"
    fi
}

# 清理依赖（可选）
suggest_cleanup_dependencies() {
    echo ""
    print_step "依赖清理建议"
    
    echo "以下工具是安装时安装的依赖，如果不再需要可以手动删除："
    echo ""
    
    case "$PKG_MANAGER" in
        apt)
            echo "  apt purge curl wget unzip"
            ;;
        dnf)
            echo "  dnf remove curl wget unzip"
            ;;
        yum)
            echo "  yum remove curl wget unzip"
            ;;
        apk)
            echo "  apk del curl wget unzip"
            ;;
        zypper)
            echo "  zypper remove curl wget unzip"
            ;;
        pacman)
            echo "  pacman -Rs curl wget unzip"
            ;;
        *)
            echo "  请根据您的包管理器手动删除 curl wget unzip"
            ;;
    esac
    
    echo ""
    print_warning "注意: 这些工具可能被其他程序使用，请谨慎删除！"
}

# 验证卸载
verify_uninstall() {
    echo ""
    print_step "验证卸载结果..."
    
    FOUND=0
    
    # 检查二进制文件
    if [ -f /usr/local/bin/v2ray ] || [ -f /usr/bin/v2ray ]; then
        print_warning "发现残留的 V2Ray 二进制文件"
        FOUND=1
    fi
    
    # 检查配置文件
    if [ -d /usr/local/etc/v2ray ] || [ -d /etc/v2ray ]; then
        print_warning "发现残留的配置文件"
        FOUND=1
    fi
    
    # 检查服务文件
    if [ -f /etc/systemd/system/v2ray.service ] || [ -f /etc/init.d/v2ray ]; then
        print_warning "发现残留的服务文件"
        FOUND=1
    fi
    
    if [ $FOUND -eq 0 ]; then
        print_info "✓ 卸载验证通过，未发现残留文件"
    else
        print_warning "! 发现部分残留文件，可能需要手动清理"
    fi
}

# 显示卸载总结
show_summary() {
    echo ""
    echo "=========================================="
    echo "  V2Ray 卸载完成"
    echo "=========================================="
    echo ""
    echo "已删除的内容："
    echo "  ✓ V2Ray 二进制文件"
    echo "  ✓ V2Ray 数据文件 (geoip.dat, geosite.dat)"
    echo "  ✓ V2Ray 配置文件"
    echo "  ✓ V2Ray 日志文件"
    echo "  ✓ V2Ray 服务文件"
    echo "  ✓ V2Ray 连接信息文件"
    echo ""
    
    if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "redhat" ] || [ "$OS_TYPE" = "suse" ]; then
        echo "卸载方式: 官方脚本 + 手动清理"
    else
        echo "卸载方式: 手动清理"
    fi
    
    echo ""
    print_info "感谢使用 V2Ray！"
    echo ""
}

# 主函数
main() {
    echo "=========================================="
    echo "  V2Ray 卸载脚本 - 通用版本"
    echo "=========================================="
    echo ""
    
    check_root
    detect_os
    # confirm_uninstall

    print_info "开始自动卸载..."
    
    # 停止服务
    stop_service
    
    # 根据系统类型选择卸载方式
    if [ "$OS_TYPE" = "alpine" ]; then
        # Alpine 系统
        uninstall_alpine_package
        uninstall_v2ray_binaries
        remove_data_files
        remove_config_files
        remove_log_files
        remove_openrc_service
    elif [ "$INIT_SYSTEM" = "systemd" ] && [ "$OS_TYPE" != "unknown" ]; then
        # Systemd 系统，优先使用官方脚本
        if ! uninstall_v2ray_systemd_official; then
            # 官方脚本失败，使用手动方法
            uninstall_v2ray_binaries
            remove_data_files
        fi
        # 清理其他文件（官方脚本不会删除这些）
        remove_config_files
        remove_log_files
        remove_systemd_service
    else
        # 其他系统或未知系统，使用手动方法
        uninstall_v2ray_binaries
        remove_data_files
        remove_config_files
        remove_log_files
        remove_service_files
    fi
    
    # 删除通用文件
    remove_info_file
    remove_other_files
    
    # 验证卸载
    verify_uninstall
    
    # 显示总结
    show_summary
    
    # 依赖清理建议
    suggest_cleanup_dependencies
}

# 执行主函数
main
