# legacyray server helper. the app prepends the LR_* variables and runs this
# as root over ssh (legacyray-ssh), the way the amnezia client sets up and
# manages a user's own server. it speaks in marked lines the app reads:
#
#   LR-STEP <text>              progress
#   LR-INFO <key> <value>       facts (os, services, ports)
#   LR-LINK <vless link>        a client link for xray reality
#   LR-CONF <base64>            a client config for amneziawg
#   LR-CLIENT <proto> <name>    one client, from "clients"
#   LR-ERROR <text>             what went wrong; the script stops
#   LR-DONE                     finished
#
# commands (LR_CMD): probe, install-xray, install-awg, add-client, remove-client,
# clients, status, restart, uninstall. LR_NAME names a client, LR_PROTO picks
# xray or awg, LR_SNI and LR_PORT tune the xray install.

set -u
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

STATE=/etc/legacyray
XRAY=/usr/local/bin/xray
XRAY_CONF=/usr/local/etc/xray/config.json
AWG_DIR=/etc/amnezia/amneziawg
AWG_CONF=$AWG_DIR/awg0.conf

say()  { echo "LR-STEP $*"; }
info() { echo "LR-INFO $*"; }
fail() { echo "LR-ERROR $*"; exit 1; }

need_root() { [ "$(id -u)" = 0 ] || fail "root rights are needed (log in as root or allow sudo)"; }

pm() {
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v yum >/dev/null 2>&1; then echo yum
    else echo none; fi
}

install_pkgs() {
    case "$(pm)" in
        apt) apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq "$@" >/dev/null 2>&1 ;;
        dnf) dnf install -y -q "$@" >/dev/null 2>&1 ;;
        yum) yum install -y -q "$@" >/dev/null 2>&1 ;;
        *) fail "no supported package manager (apt, dnf or yum)" ;;
    esac
}

public_ip() {
    ip=""
    if [ -f "$STATE/ip" ]; then ip=$(cat "$STATE/ip"); fi
    if [ -z "$ip" ]; then
        ip=$(curl -4 -s --max-time 8 https://api.ipify.org 2>/dev/null || true)
        [ -n "$ip" ] || ip=$(curl -4 -s --max-time 8 https://ifconfig.me 2>/dev/null || true)
        [ -n "$ip" ] || ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        mkdir -p "$STATE" && echo "$ip" > "$STATE/ip"
    fi
    echo "$ip"
}

default_iface() { ip -4 route show default 2>/dev/null | awk '{print $5; exit}'; }

open_port() {
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "$1/$2" >/dev/null 2>&1
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$1/$2" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
}

port_busy() { ss -lntu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$1\$"; }

rand_port() {
    while :; do
        p=$(( (RANDOM % 25000) + 30000 ))
        port_busy "$p" || { echo "$p"; return; }
    done
}

rand_u32() { od -An -N4 -tu4 /dev/urandom | tr -d ' '; }

safe_name() { echo "${1:-client}" | tr -cd 'A-Za-z0-9._-' | cut -c1-32; }

# ---- probe -------------------------------------------------------------

cmd_probe() {
    . /etc/os-release 2>/dev/null
    info os "${PRETTY_NAME:-unknown}"
    info arch "$(uname -m)"
    info root "$( [ "$(id -u)" = 0 ] && echo yes || echo no)"
    info ip "$(public_ip)"
    if [ -x "$XRAY" ] && [ -f "$STATE/xray.pbk" ]; then info xray "$(systemctl is-active xray 2>/dev/null)"; else info xray none; fi
    if [ -f "$AWG_CONF" ]; then info awg "$(systemctl is-active awg-quick@awg0 2>/dev/null)"; else info awg none; fi
    echo "LR-DONE"
}

# ---- xray reality ------------------------------------------------------

xray_link() { # uuid name
    pbk=$(cat "$STATE/xray.pbk"); sid=$(cat "$STATE/xray.sid")
    sni=$(cat "$STATE/xray.sni"); port=$(cat "$STATE/xray.port")
    echo "LR-LINK vless://$1@$(public_ip):$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pbk&sid=$sid&type=tcp#$2"
}

cmd_install_xray() {
    need_root
    command -v systemctl >/dev/null 2>&1 || fail "this server has no systemd"
    name=$(safe_name "${LR_NAME:-legacyray}")
    sni="${LR_SNI:-www.microsoft.com}"
    say "installing packages"
    install_pkgs curl ca-certificates openssl jq unzip
    command -v jq >/dev/null 2>&1 || fail "jq could not be installed"
    say "installing Xray"
    curl -fsSL -o /tmp/xray-install.sh https://github.com/XTLS/Xray-install/raw/main/install-release.sh ||
        fail "the Xray installer could not be downloaded"
    bash /tmp/xray-install.sh install >/dev/null 2>&1 || fail "the Xray installer failed"
    rm -f /tmp/xray-install.sh
    [ -x "$XRAY" ] || fail "xray is missing after the install"
    port="${LR_PORT:-443}"
    if port_busy "$port" && ! systemctl is-active --quiet xray; then port=$(rand_port); fi
    say "generating keys"
    keys=$("$XRAY" x25519)
    priv=$(echo "$keys" | awk -F': *' '/^Private/ {print $2; exit}')
    pub=$(echo "$keys" | awk -F': *' '/^(Public key|Password)/ {print $2; exit}')
    [ -n "$priv" ] && [ -n "$pub" ] || fail "xray did not produce a key pair"
    uuid=$("$XRAY" uuid)
    sid=$(openssl rand -hex 8)
    mkdir -p "$STATE" /usr/local/etc/xray
    echo "$pub" > "$STATE/xray.pbk"; echo "$sid" > "$STATE/xray.sid"
    echo "$sni" > "$STATE/xray.sni"; echo "$port" > "$STATE/xray.port"
    say "writing the configuration"
    cat > "$XRAY_CONF" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "listen": "0.0.0.0", "port": $port, "protocol": "vless", "tag": "reality",
    "settings": { "clients": [ { "id": "$uuid", "flow": "xtls-rprx-vision", "email": "$name" } ],
                  "decryption": "none" },
    "streamSettings": { "network": "tcp", "security": "reality",
      "realitySettings": { "dest": "$sni:443", "serverNames": ["$sni"],
                           "privateKey": "$priv", "shortIds": ["$sid"] } },
    "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
  }],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" },
                 { "protocol": "blackhole", "tag": "block" } ]
}
EOF
    # the helper runs with umask 077 and xray's service user is nobody
    chmod 644 "$XRAY_CONF"
    say "starting Xray"
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray || fail "xray did not start"
    sleep 1
    systemctl is-active --quiet xray || fail "xray stopped right after starting"
    open_port "$port" tcp
    info xray-port "$port"
    xray_link "$uuid" "$name"
    echo "LR-DONE"
}

xray_add() {
    [ -f "$XRAY_CONF" ] || fail "xray is not installed here"
    name=$(safe_name "$1")
    uuid=$("$XRAY" uuid)
    tmp=$(mktemp)
    jq --arg id "$uuid" --arg e "$name" \
       '.inbounds[0].settings.clients += [{"id": $id, "flow": "xtls-rprx-vision", "email": $e}]' \
       "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF" || fail "the xray configuration could not be changed"
    chmod 644 "$XRAY_CONF"
    systemctl restart xray || fail "xray did not restart"
    xray_link "$uuid" "$name"
}

xray_remove() {
    [ -f "$XRAY_CONF" ] || fail "xray is not installed here"
    tmp=$(mktemp)
    jq --arg e "$1" '.inbounds[0].settings.clients |= map(select(.email != $e))' \
       "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF" || fail "the xray configuration could not be changed"
    chmod 644 "$XRAY_CONF"
    systemctl restart xray || fail "xray did not restart"
}

xray_clients() {
    [ -f "$XRAY_CONF" ] || return 0
    jq -r '.inbounds[0].settings.clients[] | .email' "$XRAY_CONF" 2>/dev/null | while read -r n; do
        echo "LR-CLIENT xray $n"
    done
}

xray_share() { # name: print the link of an existing client
    uuid=$(jq -r --arg e "$1" '.inbounds[0].settings.clients[] | select(.email == $e) | .id' "$XRAY_CONF" | head -n1)
    [ -n "$uuid" ] || fail "no such client"
    xray_link "$uuid" "$1"
}

# ---- amneziawg ---------------------------------------------------------

awg_param() { awk -F' *= *' -v k="$1" '$1 == k {print $2; exit}' "$AWG_CONF"; }

awg_client_conf() { # priv addr psk
    srv_pub=$(cat "$STATE/awg.pub")
    port=$(awg_param ListenPort)
    cat <<EOF
[Interface]
PrivateKey = $1
Address = $2/32
DNS = 1.1.1.1, 1.0.0.1
Jc = $(awg_param Jc)
Jmin = $(awg_param Jmin)
Jmax = $(awg_param Jmax)
S1 = $(awg_param S1)
S2 = $(awg_param S2)
H1 = $(awg_param H1)
H2 = $(awg_param H2)
H3 = $(awg_param H3)
H4 = $(awg_param H4)

[Peer]
PublicKey = $srv_pub
PresharedKey = $3
Endpoint = $(public_ip):$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
}

awg_add() {
    [ -f "$AWG_CONF" ] || fail "amneziawg is not installed here"
    name=$(safe_name "$1")
    grep -q "^# LR-NAME $name\$" "$AWG_CONF" && fail "a client with that name exists"
    used=$(grep -oE '10\.8\.1\.[0-9]+' "$AWG_CONF" | awk -F. '{print $4}')
    n=2
    while echo "$used" | grep -qx "$n"; do n=$((n + 1)); done
    [ "$n" -lt 255 ] || fail "no free addresses left"
    priv=$(awg genkey); pub=$(echo "$priv" | awg pubkey); psk=$(awg genpsk)
    cat >> "$AWG_CONF" <<EOF

[Peer]
# LR-NAME $name
PublicKey = $pub
PresharedKey = $psk
AllowedIPs = 10.8.1.$n/32
EOF
    awg syncconf awg0 <(awg-quick strip awg0) 2>/dev/null || systemctl restart awg-quick@awg0
    conf=$(awg_client_conf "$priv" "10.8.1.$n" "$psk")
    echo "LR-CONF $(printf '%s\n' "$conf" | base64 | tr -d '\n')"
}

awg_remove() {
    [ -f "$AWG_CONF" ] || fail "amneziawg is not installed here"
    tmp=$(mktemp)
    awk -v n="# LR-NAME $1" '
        /^\[Peer\]/ { if (block != "" && !drop) printf "%s", block; block = $0 "\n"; drop = 0; inpeer = 1; next }
        inpeer { block = block $0 "\n"; if ($0 == n) drop = 1; next }
        { print }
        END { if (block != "" && !drop) printf "%s", block }
    ' "$AWG_CONF" > "$tmp" && mv "$tmp" "$AWG_CONF" || fail "the amneziawg configuration could not be changed"
    chmod 600 "$AWG_CONF"
    awg syncconf awg0 <(awg-quick strip awg0) 2>/dev/null || systemctl restart awg-quick@awg0
}

awg_clients() {
    [ -f "$AWG_CONF" ] || return 0
    grep '^# LR-NAME ' "$AWG_CONF" | while read -r _ _ n; do echo "LR-CLIENT awg $n"; done
}

cmd_install_awg() {
    need_root
    command -v systemctl >/dev/null 2>&1 || fail "this server has no systemd"
    . /etc/os-release 2>/dev/null
    [ "${ID:-}" = ubuntu ] || fail "AmneziaWG setup needs Ubuntu 20.04 or newer (Xray Reality works on other systems)"
    name=$(safe_name "${LR_NAME:-legacyray}")
    say "installing packages"
    install_pkgs software-properties-common curl iptables gnupg2 ||
        fail "the base packages could not be installed"
    install_pkgs "linux-headers-$(uname -r)" ||
        say "no kernel headers for $(uname -r) in the repository; the module build may fail"
    say "adding the AmneziaWG repository"
    add-apt-repository -y ppa:amnezia/ppa >/dev/null 2>&1 || fail "the AmneziaWG repository could not be added"
    say "installing AmneziaWG (building the kernel module takes a few minutes)"
    install_pkgs amneziawg amneziawg-tools
    command -v awg >/dev/null 2>&1 || fail "AmneziaWG could not be installed"
    modprobe amneziawg 2>/dev/null || fail "the AmneziaWG kernel module did not load; this VPS may not allow kernel modules (OpenVZ / LXC)"
    mkdir -p "$AWG_DIR" "$STATE"
    chmod 700 "$AWG_DIR"
    if [ ! -f "$AWG_CONF" ]; then
        say "generating keys"
        srv_priv=$(awg genkey)
        echo "$srv_priv" | awg pubkey > "$STATE/awg.pub"
        port=$(rand_port)
        jc=$(( RANDOM % 6 + 4 )); jmin=40; jmax=70
        s1=$(( RANDOM % 90 + 15 )); s2=$(( RANDOM % 90 + 15 ))
        [ $((s1 + 56)) -eq "$s2" ] && s2=$((s2 + 1))
        h1=$(rand_u32); h2=$(rand_u32); h3=$(rand_u32); h4=$(rand_u32)
        iface=$(default_iface)
        [ -n "$iface" ] || fail "no default network interface"
        cat > "$AWG_CONF" <<EOF
[Interface]
PrivateKey = $srv_priv
Address = 10.8.1.1/24
ListenPort = $port
Jc = $jc
Jmin = $jmin
Jmax = $jmax
S1 = $s1
S2 = $s2
H1 = $h1
H2 = $h2
H3 = $h3
H4 = $h4
PostUp = iptables -t nat -A POSTROUTING -s 10.8.1.0/24 -o $iface -j MASQUERADE; iptables -A FORWARD -i awg0 -j ACCEPT; iptables -A FORWARD -o awg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s 10.8.1.0/24 -o $iface -j MASQUERADE; iptables -D FORWARD -i awg0 -j ACCEPT; iptables -D FORWARD -o awg0 -j ACCEPT
EOF
        chmod 600 "$AWG_CONF"
    fi
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-legacyray.conf
    say "starting AmneziaWG"
    systemctl enable awg-quick@awg0 >/dev/null 2>&1
    systemctl restart awg-quick@awg0 || fail "AmneziaWG did not start"
    open_port "$(awg_param ListenPort)" udp
    info awg-port "$(awg_param ListenPort)"
    awg_add "$name"
    echo "LR-DONE"
}

# ---- shared ------------------------------------------------------------

cmd_add_client() {
    need_root
    case "${LR_PROTO:-}" in
        xray) xray_add "${LR_NAME:-client}" ;;
        awg)  awg_add "${LR_NAME:-client}" ;;
        *) fail "unknown protocol" ;;
    esac
    echo "LR-DONE"
}

cmd_share_client() {
    need_root
    case "${LR_PROTO:-}" in
        xray) xray_share "${LR_NAME:-}" ;;
        *) fail "an amneziawg client key is only shown once, when it is made; add a new client instead" ;;
    esac
    echo "LR-DONE"
}

cmd_remove_client() {
    need_root
    case "${LR_PROTO:-}" in
        xray) xray_remove "${LR_NAME:-}" ;;
        awg)  awg_remove "${LR_NAME:-}" ;;
        *) fail "unknown protocol" ;;
    esac
    echo "LR-DONE"
}

cmd_clients() {
    xray_clients
    awg_clients
    echo "LR-DONE"
}

cmd_status() {
    if [ -f "$XRAY_CONF" ]; then
        info xray "$(systemctl is-active xray 2>/dev/null)"
        info xray-port "$(cat "$STATE/xray.port" 2>/dev/null)"
    fi
    if [ -f "$AWG_CONF" ]; then
        info awg "$(systemctl is-active awg-quick@awg0 2>/dev/null)"
        info awg-port "$(awg_param ListenPort)"
        info awg-peers "$(awg show awg0 peers 2>/dev/null | wc -l)"
    fi
    info uptime "$(uptime -p 2>/dev/null || uptime)"
    info load "$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
    xray_clients
    awg_clients
    echo "LR-DONE"
}

cmd_restart() {
    need_root
    [ -f "$XRAY_CONF" ] && systemctl restart xray
    [ -f "$AWG_CONF" ] && systemctl restart awg-quick@awg0
    echo "LR-DONE"
}

cmd_uninstall() {
    need_root
    case "${LR_PROTO:-all}" in
        xray|all)
            if [ -f "$XRAY_CONF" ]; then
                say "removing Xray"
                systemctl disable --now xray >/dev/null 2>&1
                curl -fsSL -o /tmp/xray-install.sh https://github.com/XTLS/Xray-install/raw/main/install-release.sh &&
                    bash /tmp/xray-install.sh remove --purge >/dev/null 2>&1
                rm -f /tmp/xray-install.sh "$STATE"/xray.*
            fi ;;
    esac
    case "${LR_PROTO:-all}" in
        awg|all)
            if [ -f "$AWG_CONF" ]; then
                say "removing AmneziaWG"
                systemctl disable --now awg-quick@awg0 >/dev/null 2>&1
                rm -f "$AWG_CONF" "$STATE/awg.pub"
            fi ;;
    esac
    [ -z "$(ls -A "$STATE" 2>/dev/null | grep -v '^ip$')" ] && rm -rf "$STATE"
    echo "LR-DONE"
}

case "${LR_CMD:-probe}" in
    probe)          cmd_probe ;;
    install-xray)   cmd_install_xray ;;
    install-awg)    cmd_install_awg ;;
    add-client)     cmd_add_client ;;
    share-client)   cmd_share_client ;;
    remove-client)  cmd_remove_client ;;
    clients)        cmd_clients ;;
    status)         cmd_status ;;
    restart)        cmd_restart ;;
    uninstall)      cmd_uninstall ;;
    *) fail "unknown command" ;;
esac
