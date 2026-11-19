#!/usr/bin/env zsh

function tailscale_stop_and_disable(){
  sudo tailscale down  
  sudo systemctl stop tailscaled.service 
  sudo systemctl disable tailscaled.service 
}

function tailscale_start_and_enable(){
  sudo systemctl start tailscaled.service
  sudo tailscale up
  sudo systemctl enable tailscaled.service 
}

function tailscale_start_and_enable(){
  sudo systemctl start tailscaled.service
  sudo tailscale up
}