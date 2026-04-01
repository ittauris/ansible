#!/bin/bash
# Názov:   install_ansible.sh
# Popis:   Inštalácia Ansible + pywinrm (venv, bez PPA)
# Autor:   (doplň)
# Verzia:  1.2

set -euo pipefail

VENV_DIR="/opt/ansible-venv"

echo "[INFO] Aktualizácia zoznamu balíkov..."
sudo apt update

echo "[INFO] Inštalácia závislostí..."
sudo apt install -y python3 python3-venv python3-full

echo "[INFO] Vytvorenie virtuálneho prostredia: $VENV_DIR"
sudo python3 -m venv "$VENV_DIR"

echo "[INFO] Inštalácia Ansible + pywinrm do venv..."
sudo "$VENV_DIR/bin/pip" install --upgrade pip
sudo "$VENV_DIR/bin/pip" install ansible pywinrm

echo "[INFO] Pridanie symlinku do /usr/local/bin..."
sudo ln -sf "$VENV_DIR/bin/ansible" /usr/local/bin/ansible
sudo ln -sf "$VENV_DIR/bin/ansible-playbook" /usr/local/bin/ansible-playbook

echo "[INFO] Overenie inštalácie..."
ansible --version
