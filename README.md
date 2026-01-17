# docker compose容器更新脚本

这个 sh 脚本可以帮助你在 debian / alpine 系统快速更新docker compose容器。

### 一键脚本自定义
自定义端口参数如：DC_NAME=sub-store，使用时请自行定义此参数！
```bash
DC_NAME=sub-store sh <(curl -fsSL https://raw.githubusercontent.com/hide3110/dc-update/main/update.sh)
```

### 若alpine运行出错时
使用管道来执行（兼容性最好），使用时请自行定义sub-store此参数：
```bash
curl -fsSL https://raw.githubusercontent.com/hide3110/dc-update/main/update.sh | sh -s sub-store
```

## 详细说明
- 此脚本不在定义DC_NAME时默认值为caddy。


