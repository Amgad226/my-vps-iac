#!/bin/bash

install_tree() {
  if command -v tree &> /dev/null
  then
    echo "✅ Tree already installed"
  else
    echo "🚀 Installing Tree..."
    apt update -y
    apt install tree -y
    echo "✅ Tree installed"
  fi
}