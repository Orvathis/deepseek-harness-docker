# deepseek-harness-docker

[English](README.md) | 中文

官方 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（npm 包 `@deepseek-ai/dsh`）的 Docker 镜像：一条 `docker compose up -d`，局域网内即可打开 DSH Web UI。

- 上游：https://github.com/deepseek-ai/deepseek-harness
- 镜像：`ghcr.io/orvathis/deepseek-harness-docker`（GitHub Actions 跟随上游自动构建）
- 许可：MIT（见 [LICENSE](LICENSE)；镜像内 `/app/licenses/` 另存上游 LICENSE）

> :warning: 上游是 developer preview：版本全为预发布、会有破坏性变更；本镜像跟随上游，不保证跨版本兼容。

## 快速开始

存成 `docker-compose.yml`，同目录建 `.env` 填 `TRUSTED_HOST=<宿主 IP>`：

```yaml
services:
  dsh:
    image: ghcr.io/orvathis/deepseek-harness-docker:latest
    container_name: deepseek-harness
    restart: always
    ports:
      - "${HOST_PORT:-3080}:3080"
    volumes:
      - ./data:/data
    environment:
      TRUSTED_HOST: ${TRUSTED_HOST:-192.168.1.10}
      TZ: ${TZ:-Asia/Shanghai}
      HOST_PORT: ${HOST_PORT:-3080}
```

```sh
docker compose up -d
```

更新：`docker compose pull && docker compose up -d`。

## 环境变量

| 变量 | 值 | 说明 |
| --- | --- | --- |
| `TRUSTED_HOST` | 镜像无默认（必填）；示例值 `192.168.1.10` | 浏览器访问用的 authority；逗号分隔可写多个（IP 和域名），省略端口匹配任意端口；仅宿主回环访问时写 `localhost`；为空则容器退出、`/api` 全 403 |
| `TZ` | 镜像默认 `Etc/UTC`；示例值 `Asia/Shanghai` | 容器时区；镜像已内置 tzdata |
| `HOST_PORT` | 默认 `3080`；同时用于 compose 端口映射 | 宿主机侧端口，也用于日志里打印的访问 URL；容器内固定监听 3080 |

## 首次鉴权（必做一次）

- 取 token：`docker compose logs dsh | grep -o 'token=[^& ]*'`（PowerShell 用 `Select-String 'token='`）
- 打开日志里打印的 URL（形如 `http://192.168.1.10:3080/?token=xxxxxxxx`）；之后直接访问同一地址，cookie 30 天有效、不续期
- 重取时机：cookie 失效后（换 IP / 端口 / 域名、清 cookie 或换浏览器）。容器重启会换新 token、作废旧 token，但已签发的 cookie 仍有效，无需重登

## tag 说明

| tag | 含义 |
| --- | --- |
| `:latest` | 最新且通过 smoke 校验的版本 |
| `:<版本号>` | 每次构建即产出，如 `:0.2.1-rc.2`；回滚或钉版本用这个 |

## 安全提示

- **端口无任何保护，鉴权也只有 DSH 自带的 launch token**（无 token 访问 `GET /` 得 401；本镜像不加 Basic Auth）。
  - 仅本机：`-p 127.0.0.1:3080:3080` 配 SSH 隧道
  - 内网访问：`-p 3080:3080`，容器端口只暴露给可信内网
  - 对外发布：走反向代理，在代理上加 TLS / Basic Auth / IP 白名单
- **不能用 `network_mode: host`**：`dsh web --host` 需要具体容器 IP，host network 下没有；必须走端口映射。
- 镜像含开发工具全集（git / python3 / gcc / ripgrep …），体积 GB 量级。

## 许可

本仓库代码以 MIT 发布，见 [LICENSE](LICENSE)；镜像内其余成分（DeepSeek Harness、npm 依赖、发行版工具链）各遵循其原许可。
