#!/bin/bash

install_nginx() {
  if command -v nginx &> /dev/null
  then
    echo "✅ Nginx already installed"
  else
    echo "🚀 Installing Nginx..."

    apt update -y
    apt install nginx -y

    systemctl enable nginx
    systemctl start nginx

    echo "✅ Nginx installed and started"
  fi
}