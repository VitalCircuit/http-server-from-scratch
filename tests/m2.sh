#!/bin/sh
# M2 回归测试：起一个真实的服务进程，用 curl 逐条验收。
# 用法: sh tests/m2.sh [端口]
# 退出码: 0 = 全部通过, 非 0 = 失败条数

PORT="${1:-8080}"
BASE="http://127.0.0.1:$PORT"
BIN="./build/server"
PASS=0
FAIL=0
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

ok()   { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

# 期望状态码
expect_code() {
  desc="$1"; path="$2"; want="$3"; method="${4:-GET}"
  got=$(curl -s -o /dev/null -w '%{http_code}' -X "$method" --max-time 5 "$BASE$path" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    ok "$desc ($method $path -> $got)"
  else
    bad "$desc ($method $path -> $got, 期望 $want)"
  fi
}

# 期望 Content-Length 与真实 body 字节数一致
expect_length() {
  desc="$1"; path="$2"
  body_len=$(curl -s --max-time 5 "$BASE$path" 2>/dev/null | wc -c | tr -d ' ')
  hdr_len=$(curl -s -D - -o /dev/null --max-time 5 "$BASE$path" 2>/dev/null \
    | tr -d '\r' | tr 'A-Z' 'a-z' | awk -F': *' '/^content-length:/{print $2}' | tail -1)
  if [ -n "$hdr_len" ] && [ "$hdr_len" = "$body_len" ]; then
    ok "$desc (Content-Length=$hdr_len 与实际 $body_len 一致)"
  else
    bad "$desc (Content-Length=${hdr_len:-缺失}, 实际 $body_len)"
  fi
}

echo "== 构建 =="
if ! make >/dev/null 2>&1; then
  echo "构建失败，先跑 make 看看报错"; exit 1
fi
[ -x "$BIN" ] || { echo "找不到 $BIN"; exit 1; }

echo "== 启动服务 (端口 $PORT) =="
"$BIN" "$PORT" >/tmp/m2-server.log 2>&1 &
SERVER_PID=$!

ready=0
i=0
while [ $i -lt 30 ]; do
  if curl -s -o /dev/null --max-time 1 "$BASE/"; then ready=1; break; fi
  i=$((i + 1)); sleep 0.2
done
if [ "$ready" -ne 1 ]; then
  echo "服务没起来，日志："; cat /tmp/m2-server.log; exit 1
fi

echo "== 路由 =="
expect_code "根路径"            "/"        200
expect_code "已知路径"          "/hello"   200
expect_code "未知路径返回 404"  "/nope"    404

echo "== 方法 =="
expect_code "POST 应拒绝"       "/"        405 POST

echo "== 响应头 =="
expect_length "根路径长度一致"      "/"
expect_length "已知路径长度一致"    "/hello"

echo "== 边界 =="
LONG=$(printf 'a%.0s' $(seq 1 9000))
got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$BASE/$LONG" 2>/dev/null)
case "$got" in
  400|414) ok "超长路径被拒 ($got)" ;;
  *)       bad "超长路径应返回 400/414，实际 $got" ;;
esac

i=0; loop_ok=1
while [ $i -lt 50 ]; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$BASE/" 2>/dev/null)
  [ "$c" = "200" ] || { loop_ok=0; break; }
  i=$((i + 1))
done
if [ "$loop_ok" -eq 1 ]; then ok "连续 50 次请求全部 200"; else bad "第 $((i + 1)) 次请求失败"; fi

if kill -0 "$SERVER_PID" 2>/dev/null; then ok "服务存活（没崩）"; else bad "服务已退出"; fi

echo
printf '== 结果: \033[32m%d 通过\033[0m, \033[31m%d 失败\033[0m ==\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || echo "（失败条目不一定是 bug，M2 还没做完时属正常）"
exit "$FAIL"
