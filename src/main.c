/*
 * M1：最小可用的 TCP 服务器骨架。
 *
 * 现在能做的：接受连接 -> 打印请求行 -> 返回固定响应 -> 关闭。
 * 下一步（M2）：解析请求行和 headers，按 path 路由。
 * 再往后（M5）：把阻塞 accept 换成 epoll 非阻塞事件循环。
 */
#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define REQ_MAX 8192

int main(int argc, char **argv) {
    int port = argc > 1 ? atoi(argv[1]) : 8080;

    int server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) {
        perror("socket");
        return 1;
    }

    int yes = 1;
    if (setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes) < 0) {
        perror("setsockopt");
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons((unsigned short)port);

    if (bind(server, (struct sockaddr *)&addr, sizeof addr) < 0) {
        perror("bind");
        close(server);
        return 1;
    }
    if (listen(server, 128) < 0) {
        perror("listen");
        close(server);
        return 1;
    }

    printf("listening on http://127.0.0.1:%d\n", port);
    fflush(stdout);

    for (;;) {
        int client = accept(server, NULL, NULL);
        if (client < 0) {
            perror("accept");
            continue;
        }

        char buf[REQ_MAX];
        ssize_t n = recv(client, buf, sizeof buf - 1, 0);
        if (n > 0) {
            buf[n] = '\0';
            char *line_end = strstr(buf, "\r\n");
            if (line_end != NULL) {
                *line_end = '\0';
            }
            printf("request: %s\n", buf);
            fflush(stdout);
        }

        const char *body = "hello from a hand-written server\n";
        char resp[512];
        int len = snprintf(resp, sizeof resp,
                           "HTTP/1.1 200 OK\r\n"
                           "Content-Type: text/plain; charset=utf-8\r\n"
                           "Content-Length: %zu\r\n"
                           "Connection: close\r\n"
                           "\r\n"
                           "%s",
                           strlen(body), body);
        if (len > 0) {
            send(client, resp, (size_t)len, 0);
        }
        close(client);
    }

    close(server);
    return 0;
}
