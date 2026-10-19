# 开发环境搭建（换电脑 / 环境崩了照着重来）

目标：10 分钟内恢复「能写 C、能跑测试、在封锁网下能推代码」。

---

## 1. SSH 密钥（一次性，只需做一次）

```powershell
ssh-keygen -t ed25519 -C "VitalCircuit"
```

连按三次回车（口令留空）。然后在 `%USERPROFILE%\.ssh\config` 写：

```
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
```

> `HostName ssh.github.com` + `Port 443`：把 SSH 伪装成 HTTPS 端口，绕开对 22 端口和域名的封锁。

把 `id_ed25519.pub` 整行贴到 https://github.com/settings/ssh/new
（Title 随便写，Key type 选 **Authentication Key**）。

验证：

```powershell
ssh -T git@github.com
# 期望：Hi 用户名! You've successfully authenticated
```

---

## 2. git 全局配置

```powershell
git config --global user.name "VitalCircuit"
git config --global user.email "<你的数字ID>+VitalCircuit@users.noreply.github.com"
git config --global core.autocrlf input
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

- **noreply 邮箱**：提交记录里不暴露真实邮箱。数字 ID 用 `https://api.github.com/users/<用户名>` 查。
- **最后一行是关键**：任何程序（包括 GitHub Desktop 这类 GUI）内部用 `https://github.com` 做 git 操作时，会自动改走 SSH。封锁网下 GUI 工具能正常工作，靠的就是这条。

撤销：

```powershell
git config --global --unset url."git@github.com:".insteadOf
```

---

## 3. WSL2 + Ubuntu

**官方路径**（网络通时最省事）：

```powershell
wsl --install -d Ubuntu
```

**被墙时的镜像导入法**（本机用的就是这条，不需要重启）：

```powershell
New-Item -ItemType Directory -Force D:\wsl | Out-Null
curl.exe -L -o D:\wsl\ubuntu-base.tar.gz https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz
wsl --import Ubuntu D:\wsl\Ubuntu D:\wsl\ubuntu-base.tar.gz --version 2
```

验证：

```powershell
wsl -d Ubuntu -u root -- cat /etc/os-release
```

> 启动时出现 `无法配置网络 (networkingMode Nat)，回退到 Consomme` 属正常，不影响 apt 和网络。

---

## 4. WSL 里装工具链

```sh
cat > /etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

apt-get update
apt-get install -y build-essential git curl valgrind openssh-client
```

---

## 5. 让 WSL 里也能 push（可选）

```sh
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cp /mnt/c/Users/<你的Windows用户名>/.ssh/id_ed25519     /root/.ssh/
cp /mnt/c/Users/<你的Windows用户名>/.ssh/id_ed25519.pub /root/.ssh/
cp /mnt/c/Users/<你的Windows用户名>/.ssh/config         /root/.ssh/config
chmod 600 /root/.ssh/id_ed25519 /root/.ssh/config
chmod 644 /root/.ssh/id_ed25519.pub

git config --global user.name "VitalCircuit"
git config --global user.email "<你的数字ID>+VitalCircuit@users.noreply.github.com"
git config --global core.autocrlf input
```

---

## 6. 验收清单

```sh
ssh -T git@github.com                  # Hi 用户名!
cd /mnt/d/Github/http-server-from-scratch
make                                   # 编译成功
./build/server 8080 &                  # 能起
curl -i http://127.0.0.1:8080/         # 200
sh tests/m2.sh                         # 跑回归测试
git ls-remote origin                   # 能读到远端
```

全部通过 = 环境恢复完成。

---

## 常见故障对照

| 现象 | 原因 | 解法 |
|---|---|---|
| `Recv failure: Connection was reset`（HTTPS clone） | github.com 的 HTTPS 被拦 | 用 SSH 地址，或配第 2 步的 `insteadOf` |
| GUI 工具报「无法加载 xx 市场」 | 它内部用了 HTTPS | 同上；配了 `insteadOf` 后自动改走 SSH |
| 网页打不开 / 登录卡住 | 同上（网页必须 HTTPS） | 开代理或手机热点，一次性操作 |
| `connect to host github.com port 22: timed out` | 22 端口被封 | 检查 ssh config 是否走 `ssh.github.com:443` |
| `Permission denied (publickey)` | 公钥没加到账号 | 去 settings/ssh/new 贴 `id_ed25519.pub` |
| WSL 里 DNS 解析失败 | 网络模式回退 | `wsl --shutdown` 后重开 |
| `dubious ownership`（git 报仓库属主不对） | Windows 与 WSL 用户映射 | `git config --global --add safe.directory /mnt/d/...` |
