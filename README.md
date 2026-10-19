# http-server-from-scratch

从零手写一个 HTTP 服务器（C + epoll），不依赖任何 HTTP 框架，用来吃透 TCP、HTTP 协议和 IO 多路复用。

## 为什么做这个

- 面试能深挖：socket 生命周期、epoll 的触发模式、协议解析、缓冲区与内存管理
- 产出可量化：`wrk` 压测的 QPS / 延迟数据，比“我做过一个项目”有说服力

## 环境

`epoll` 是 Linux 的 API，Windows 上跑不了，请在 **WSL2 + Ubuntu** 里开发：

```powershell
# PowerShell（管理员）
wsl --install -d Ubuntu
```

装完后在 Ubuntu 里补齐工具链：

```sh
sudo apt update && sudo apt install -y build-essential valgrind wrk
```

## 构建与运行

```sh
make              # 产出 build/server
./build/server 8080
curl -v http://127.0.0.1:8080/
```

## 里程碑

| # | 目标 | 状态 |
|---|---|---|
| M1 | 能接受连接、打印请求行、返回固定响应 | ✅ 已编译验证（gcc 13.3） |
| M2 | 解析请求行与 headers，按 path 路由 | ⬜ [任务清单](docs/m2-checklist.md) |
| M3 | 静态文件：200 / 404、Content-Length、Content-Type | ⬜ |
| M4 | keep-alive 与读超时 | ⬜ |
| M5 | epoll 非阻塞事件循环（替换阻塞 accept） | ⬜ |
| M6 | `wrk` 压测 + 瓶颈分析，数据记到 `bench/` | ⬜ |
| M7 | 日志、配置、Dockerfile（可选） | ⬜ |

## 目录

```
src/      源码
tests/    回归测试（起真实进程 + curl 验收）
bench/    压测脚本与结果
docs/     设计笔记与任务清单
```

## 环境重建

换电脑或环境崩了？照 [docs/env-setup.md](docs/env-setup.md) 重来一遍，约 10 分钟。

## 测试

```sh
sh tests/m2.sh        # 默认 8080 端口
sh tests/m2.sh 9090   # 换端口
```

脚本会自己构建、起服务、逐条跑验收，最后打印通过/失败条数。退出码即失败条数，方便以后接 CI。

## 约定

- 一个里程碑一个 commit，提交信息写清楚做了什么
- 关键决策记进 `docs/notes.md`：为什么这么设计、踩了什么坑（这部分面试时最值钱）
