#!/usr/bin/env bash
# Generates keys + config for a VLESS+Reality (Vision) Xray server and prints a client link.
# Usage: ./setup.sh [SNI] [SERVER_IP]
#   SNI        REQUIRED. Site to impersonate: TLS 1.3 + HTTP/2, low latency from this server.
#              Xray warns that big-name picks (microsoft.com etc.) get IPs blocked faster.
#   SERVER_IP  public IP (auto-detected if omitted)
set -euo pipefail
cd "$(dirname "$0")"

XRAY_VERSION="${XRAY_VERSION:-26.7.28}"
IMAGE="ghcr.io/xtls/xray-core:${XRAY_VERSION}"
SNI="${1:-}"
[[ -n "$SNI" ]] || { echo "Usage: $0 <SNI domain> [SERVER_IP]  (e.g. a TLS1.3+H2 site near your server; NOT microsoft/google/cloudflare)" >&2; exit 1; }
SERVER_IP="${2:-$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo YOUR_SERVER_IP)}"

[[ -f config/config.json ]] && { echo "config/config.json already exists - delete it to regenerate." >&2; exit 1; }

xray() { docker run --rm "$IMAGE" "$@"; }

UUID="$(xray uuid)"
KEYS="$(xray x25519)"
# Output labels changed between versions; line 1 = private key, line 2 = public key in both.
PRIV="$(sed -n '1p' <<<"$KEYS" | awk -F': ' '{print $2}')"
PUB="$(sed -n '2p' <<<"$KEYS" | awk -F': ' '{print $2}')"
SID="$(openssl rand -hex 8)"
[[ -n "$UUID" && -n "$PRIV" && -n "$PUB" ]] || { echo "key generation failed" >&2; exit 1; }

mkdir -p config
umask 077
cat > config/config.json <<JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${UUID}", "flow": "xtls-rprx-vision" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": [ "${SNI}" ],
          "privateKey": "${PRIV}",
          "shortIds": [ "${SID}" ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls", "quic" ],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "ip": [ "geoip:private" ], "outboundTag": "block" },
      { "type": "field", "protocol": [ "bittorrent" ], "outboundTag": "block" }
    ]
  }
}
JSON
chmod 644 config/config.json   # container user must read it; dir perms protect it
chmod 700 config

LINK="vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUB}&sid=${SID}&type=tcp#reality"
echo "$LINK" > client-link.txt

echo
echo "Config written. Start with:  docker compose up -d"
echo
echo "Client link (also saved to client-link.txt):"
echo "$LINK"
command -v qrencode >/dev/null && qrencode -t ANSIUTF8 "$LINK" || true
