# M2 任务清单：解析请求 + 路由

目标：从 M1 的“固定返回”升级到“看懂请求，按路径回答”。

改完每个步骤跑一次 `sh tests/m2.sh`，看到 PASS 变绿再往下走。

---

## 步骤 1：把请求拆成「请求行 + headers」

现在 `recv` 到的是一个整块，先按 `\r\n\r\n` 切开。

**要点**：HTTP 头以空行结束，分隔符是 `\r\n\r\n`（不是 `\n\n`）。

**验收**：能打印出第一行，形如 `GET /hello HTTP/1.1`。

---

## 步骤 2：解析请求行

`GET /hello?x=1 HTTP/1.1` → method=`GET`、path=`/hello`、version=`HTTP/1.1`。

**要点**：
- 空格分隔三段，method 和 path 之间、path 和 version 之间各一个空格
- path 里的 `?` 之后是 query，路由时先截掉
- 别用 `strtok` 直接切原缓冲区（会破坏后面的数据），先拷一份或手工定位空格

**验收**：`/hello?x=1` 能取到路径 `/hello`。

---

## 步骤 3：路由

| 请求 | 期望 |
|---|---|
| `GET /` | 200 |
| `GET /hello` | 200 |
| 其他路径 | 404 |

**要点**：404 也要带 `Content-Length`（可以是 0），否则浏览器/curl 会一直等。

**验收**：`curl -i http://127.0.0.1:8080/nope` 返回 `404`。

---

## 步骤 4：方法校验

只接受 `GET`，其他方法（POST/PUT/DELETE/HEAD）返回 `405 Method Not Allowed`。

**要点**：405 响应最好带一个 `Allow: GET` 头。

**验收**：`curl -i -X POST http://127.0.0.1:8080/` 返回 `405`。

---

## 步骤 5：Content-Length 必须真实

**新手最常错**：`Content-Length` 写死成固定值，或者用了 `strlen(body)` 但 body 里有 `\0`。

**要点**：`Content-Length` = 实际发送的字节数，一个不多一个不少。

**验收**：`curl -s -D- -o /dev/null URL` 里的 `Content-Length` 与 `curl -s URL | wc -c` 相等。

---

## 步骤 6：边界（不崩即合格）

| 场景 | 期望 |
|---|---|
| 路径超长（> 8000 字节） | 返回 414 或 400，**服务不崩** |
| 只发一半就断开 | 不崩，`recv` 返回 0 或负数要处理 |
| 完全没数据的连接 | 不崩 |
| 同一端口连续 100 次请求 | 全部正常 |

**验收**：跑完 `tests/m2.sh` 后服务仍然活着。

---

## 常见坑

1. **`\r\n` 和 `\n`**：Linux 客户端发 `\r\n`，但手测时容易用 `\n`，别把两者混用。
2. **`recv` 一次读不全**：请求体可能分多包到达，M2 只处理 headers，也要留出“没读到 `\r\n\r\n` 就再读一次”的余地（M4 会正式处理）。
3. **`send` 短写**：`send` 可能只发出一部分，返回值要检查（简单场景可忽略，但要心里有数，M5 会处理）。
4. **字符串没结束符**：`recv` 之后一定要 `buf[n] = '\0'`。
5. **改了路由忘了改 Content-Length**：body 变了长度必须跟着变。

---

## 提交规范

每完成一个步骤提交一次：

```
feat: parse request line and route by path (M2)
fix: keep Content-Length in sync with body
```

一个 commit 只做一件事，面试时翻提交历史能看出你的思路。
