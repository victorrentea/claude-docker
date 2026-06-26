#!/usr/bin/env bash
# Apply egress allowlist via iptables + ipset, using the domain list at
# $ALLOWLIST (default /etc/claude-docker/allowlist.txt).
#
# Designed to be re-runnable: flushes existing rules and rebuilds from
# the current allowlist file. Safe to call again after editing the list.
set -euo pipefail

ALLOWLIST="${ALLOWLIST:-/etc/claude-docker/allowlist.txt}"

if [ "$(id -u)" -ne 0 ]; then
    echo "init-firewall.sh must run as root" >&2
    exit 1
fi

if [ ! -r "$ALLOWLIST" ]; then
    echo "Allowlist not readable: $ALLOWLIST" >&2
    exit 1
fi

iptables -F
iptables -X
iptables -P INPUT  DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

ipset create allowed-ips hash:ip family inet -exist
ipset flush allowed-ips

iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS must be reachable to resolve the allowlist itself and for normal lookups.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

count=0
fails=0
while IFS= read -r raw; do
    domain="${raw%%#*}"
    domain="$(echo -n "$domain" | tr -d '[:space:]')"
    [ -z "$domain" ] && continue
    ips="$(getent ahostsv4 "$domain" 2>/dev/null | awk '{print $1}' | sort -u || true)"
    if [ -z "$ips" ]; then
        echo "[firewall] WARN: could not resolve $domain" >&2
        fails=$((fails+1))
        continue
    fi
    for ip in $ips; do
        ipset add allowed-ips "$ip" -exist
    done
    count=$((count+1))
done < "$ALLOWLIST"

iptables -A OUTPUT -p tcp -m set --match-set allowed-ips dst --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -m set --match-set allowed-ips dst --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp -m set --match-set allowed-ips dst --dport 22  -j ACCEPT

# Fast-reject anything else so apps fail in milliseconds instead of waiting for
# the OS TCP/UDP connect timeout (~75s). Required for Chromium-based tools to
# load real-world pages: page load event won't fire while sub-resource sockets
# are still hanging on blocked CDNs/trackers.
iptables -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -A OUTPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -A OUTPUT      -j REJECT --reject-with icmp-host-prohibited

ip_total="$(ipset list allowed-ips | sed -n '/^Members:/,$ p' | tail -n +2 | wc -l | tr -d ' ')"
echo "[firewall] allowlist applied: ${count} domain(s) resolved, ${ip_total} IP(s) permitted, ${fails} unresolved"
