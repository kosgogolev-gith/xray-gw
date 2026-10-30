#!/bin/sh
# Прозрачный шлюз: трафик, пришедший на uplink контейнера, уходит в TUN Xray.
# Собственные соединения Xray к VPS идут по main через uplink.
# Если Xray/TUN нет — транзит блокируется (fail-closed, правило unreachable).
set -eu

XRAY_BIN=${XRAY_BIN:-/usr/local/bin/xray}
CONFIG=${XRAY_CONFIG:-/etc/xray/config.json}
TUN=${TUN_NAME:-xray0}
TABLE=${TUN_TABLE:-100}
PRIO=${RULE_PRIORITY:-300}

log() { echo "[xray-gw] $*"; }

[ -r "$CONFIG" ] || { log "config not found: $CONFIG"; exit 1; }

UPLINK=${UPLINK:-$(ip -4 route show default | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')}
[ -n "$UPLINK" ] || { log "no IPv4 default route, cannot detect uplink"; exit 1; }
log "uplink=$UPLINK tun=$TUN table=$TABLE"

sysctl -qw net.ipv4.ip_forward=1
sysctl -qw net.ipv4.conf.all.rp_filter=2
sysctl -qw net.ipv4.conf.default.rp_filter=2

# RouterOS 7.22+ может ставить lookup main/default раньше наших правил: переносим их в конец.
for spec in "main:32766" "default:32767"; do
  tbl=${spec%%:*}; dst=${spec#*:}
  for pr in $(ip -4 rule show | awk -v t="lookup $tbl" 'index($0,t){sub(":","",$1); print $1}'); do
    if [ "$pr" -lt "$PRIO" ]; then
      ip -4 rule del priority "$pr" || true
      ip -4 rule show | grep -q "^$dst:" || ip -4 rule add priority "$dst" lookup "$tbl"
      log "moved rule $pr (lookup $tbl) -> $dst"
    fi
  done
done

# Fail-closed: транзит с uplink только через таблицу TUN, иначе unreachable.
ip -4 rule del priority "$PRIO" 2>/dev/null || true
ip -4 rule del priority $((PRIO+1)) 2>/dev/null || true
ip -4 rule add priority $((PRIO+1)) iif "$UPLINK" unreachable
ip -4 rule add priority "$PRIO" iif "$UPLINK" lookup "$TABLE"
ip -4 route flush table "$TABLE" 2>/dev/null || true

"$XRAY_BIN" run -config "$CONFIG" &
XPID=$!
trap 'log "stopping"; kill -TERM $XPID 2>/dev/null; wait $XPID; exit 0' TERM INT

i=0
until ip link show "$TUN" >/dev/null 2>&1; do
  i=$((i+1))
  kill -0 $XPID 2>/dev/null || { log "xray exited before creating $TUN"; wait $XPID || true; exit 1; }
  [ $i -ge 30 ] && { log "timeout waiting for $TUN"; kill -TERM $XPID; exit 1; }
  sleep 1
done
ip link set "$TUN" up
sysctl -qw "net.ipv4.conf.$TUN.rp_filter=0" 2>/dev/null || true
ip -4 route replace table "$TABLE" default dev "$TUN"
log "ready: $(ip -4 rule show | tr '\n' ';')"
log "table $TABLE: $(ip -4 route show table "$TABLE" | tr '\n' ';')"

wait $XPID
RC=$?
log "xray exited rc=$RC"
exit $RC
