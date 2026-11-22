# xray-reality-docker

Minimal VLESS + Reality (XTLS Vision) server in Docker, using the **official** `ghcr.io/xtls/xray-core` image.
One script generates the keys, config and a ready-to-import client link.

## Why this instead of building your own image
- Official image, pinned to a current Xray release (`XRAY_VERSION`, default `26.7.28`). No custom Dockerfile to maintain.
- Fresh UUID, x25519 keypair and shortId generated per install, nothing shared across users.
- Blocks private IP ranges and BitTorrent, so clients can't reach your LAN through the proxy.
- Hardened container: read-only filesystem, config mounted read-only, all capabilities dropped except `NET_BIND_SERVICE`, `no-new-privileges`, capped logs.

## Requirements
- Docker with the Compose plugin, `openssl`, `curl`
- A free TCP port (443 by default). If nginx or something else holds 443, stop it or change the port mapping in `docker-compose.yml` and the port in the client link.
- A recent client (Xray core >= 26.3.27). Old clients may be refused.

## Usage
```bash
./setup.sh <SNI> [SERVER_IP]
docker compose up -d
docker logs xray-reality
cat client-link.txt        # import into your client
```
- `SNI` (required): the site Reality impersonates. It needs TLS 1.3 + HTTP/2, low latency from the server, not behind Cloudflare, and should not be a giant (microsoft, google...).
- `SERVER_IP`: auto-detected if omitted.

Open the port in your firewall. Note that Docker-published ports bypass `ufw`.

## Picking an SNI
A small site in the same network as your server looks the most natural.
1. Run [RealiTLScanner](https://github.com/XTLS/RealiTLScanner) from your own machine (not the VPS, to avoid abuse reports) against your server's /24.
2. Drop Cloudflare origin certs, placeholder certs, default VPS hostnames and internal-looking subdomains.
3. Check finalists from the server:
   ```bash
   openssl s_client -connect IP:443 -servername DOMAIN -tls1_3 -alpn h2 </dev/null 2>/dev/null | grep -E "Protocol|ALPN"
   curl -4 -s --resolve DOMAIN:443:IP -o /dev/null -w "connect: %{time_connect}s http: %{http_code}\n" https://DOMAIN
   ```
   You want `TLSv1.3`, `h2`, http 200/301/302 and a small connect time.
4. If the site's public DNS points elsewhere (e.g. Cloudflare) but it answers on a neighbor IP, edit `config/config.json` after setup, set `"dest": "NEIGHBOR_IP:443"` and run `docker compose restart`.

## Security notes
- `config/config.json` holds the private key and `client-link.txt` holds the UUID. Both are git-ignored. Never commit or share them.
- To rotate everything: delete `config/` and `client-link.txt`, rerun `./setup.sh`, then `docker compose up -d`.

## Updating
```bash
XRAY_VERSION=<new version> docker compose pull
XRAY_VERSION=<new version> docker compose up -d
```
Keep your client up to date as well.

---

# Русская версия

Минимальный сервер VLESS + Reality (XTLS Vision) в Docker на основе **официального** образа `ghcr.io/xtls/xray-core`.
Один скрипт генерирует ключи, конфиг и готовую ссылку для клиента.

## Почему не собственный образ
- Официальный образ с закреплённой актуальной версией Xray (`XRAY_VERSION`, по умолчанию `26.7.28`). Не нужно поддерживать свой Dockerfile.
- UUID, пара ключей x25519 и shortId генерируются заново при каждой установке, ничего общего между пользователями.
- Блокируются приватные диапазоны IP и BitTorrent, поэтому клиенты не могут добраться до твоей локальной сети через прокси.
- Усиленный контейнер: файловая система только для чтения, конфиг смонтирован только для чтения, сброшены все capabilities кроме `NET_BIND_SERVICE`, включён `no-new-privileges`, логи ограничены по размеру.

## Требования
- Docker с плагином Compose, `openssl`, `curl`
- Свободный TCP-порт (по умолчанию 443). Если его занимает nginx или что-то другое, останови это или поменяй порт в `docker-compose.yml` и в клиентской ссылке.
- Свежий клиент (ядро Xray >= 26.3.27). Старые клиенты могут не подключиться.

## Использование
```bash
./setup.sh <SNI> [SERVER_IP]
docker compose up -d
docker logs xray-reality
cat client-link.txt        # импортируй в клиент
```
- `SNI` (обязательный): сайт, под который маскируется Reality. Нужны TLS 1.3 + HTTP/2, низкая задержка от сервера, без Cloudflare, и желательно не гигант (microsoft, google и т.п.).
- `SERVER_IP`: определяется автоматически, если не указан.

Открой порт в файрволе. Учти, что порты, опубликованные Docker'ом, обходят `ufw`.

## Как выбрать SNI
Небольшой сайт из той же сети, что и твой сервер, выглядит наиболее естественно.
1. Запусти [RealiTLScanner](https://github.com/XTLS/RealiTLScanner) со своей машины (не с VPS, чтобы не получить жалобу на сканирование) по /24 своего сервера.
2. Отбрось сертификаты Cloudflare Origin, заглушки, дефолтные имена VPS и внутренние поддомены.
3. Проверь финалистов с сервера:
   ```bash
   openssl s_client -connect IP:443 -servername DOMAIN -tls1_3 -alpn h2 </dev/null 2>/dev/null | grep -E "Protocol|ALPN"
   curl -4 -s --resolve DOMAIN:443:IP -o /dev/null -w "connect: %{time_connect}s http: %{http_code}\n" https://DOMAIN
   ```
   Нужны `TLSv1.3`, `h2`, http 200/301/302 и маленькое время подключения.
4. Если публичный DNS сайта ведёт в другое место (например, в Cloudflare), но на соседнем IP он отвечает, после `setup.sh` отредактируй `config/config.json`, поставь `"dest": "СОСЕДНИЙ_IP:443"` и выполни `docker compose restart`.

## Безопасность
- В `config/config.json` лежит приватный ключ, а в `client-link.txt` UUID. Оба файла в `.gitignore`. Никогда не коммить и не показывай их.
- Чтобы сменить всё: удали `config/` и `client-link.txt`, снова запусти `./setup.sh`, затем `docker compose up -d`.

## Обновление
```bash
XRAY_VERSION=<новая версия> docker compose pull
XRAY_VERSION=<новая версия> docker compose up -d
```
Не забывай обновлять и клиент.
