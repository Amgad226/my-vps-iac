#!/bin/bash

install_git() {
  if command -v git &> /dev/null
  then
    echo "✅ Git already installed"
  else
    echo "🚀 Installing Git..."
    apt update -y
    apt install git -y
    echo "✅ Git installed"
  fi
}