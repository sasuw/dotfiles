#!/usr/bin/env zsh

ip_my(){
  ip a s | grep -E 'inet 192[0-9.]{6,12}' | grep -Eo '192[0-9.]{6,12}' | head -n1
}

ip_no_virt() {
  rg -F -v -e virbr -e veth -e 'br-' | rg -F --color=never ': '
}

ip_link_nv(){
  ip link | ip_no_virt
}

# Physical interfaces (excludes virtual interfaces)
# Linux exposes interfaces through /sys/class/net; physical ones have a device entry.
ipr() {
  local nic
  for nic in /sys/class/net/*(N); do
    [[ -e "$nic/device" ]] || continue
    command ip "$@" dev "${nic:t}"
  done
}

ipasd() {
  local nic
  for nic in /sys/class/net/*(N); do
    [[ -e "$nic/device" ]] || continue
    command ip -br addr show dev "${nic:t}"
  done
}
