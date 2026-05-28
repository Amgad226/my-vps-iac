#!/bin/bash

install_certbot() {
  if command -v certbot &> /dev/null
  then
    echo "✅ Certbot already installed"
  else
    echo "🚀 Installing Certbot..."

    apt update -y
    apt install certbot python3-certbot-nginx -y

    echo "✅ Certbot installed"
  fi
}
