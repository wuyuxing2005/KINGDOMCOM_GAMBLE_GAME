中世纪骰局 Linux x86_64 联机服务器

1. 将 medieval_dice_server.x86_64 上传到 /opt/medieval-dice/。
2. 执行 chmod +x /opt/medieval-dice/medieval_dice_server.x86_64。
3. 前台测试：./medieval_dice_server.x86_64 -- --port=9080
4. 正式运行可参考 medieval-dice.service。
5. 正式客户端建议通过 Caddyfile 示例提供 wss:// 地址。

服务器使用 TCP 9080。Caddy 对外提供 80/443 时，只需让游戏服务器监听本机 9080。
