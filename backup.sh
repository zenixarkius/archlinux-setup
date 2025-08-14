#!/bin/bash
BACKUP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# LibreWolf
cp -r ~/.librewolf/user $BACKUP/temp/.librewolf/user

# VSCodium
cp -r ~/.config/VSCodium/User $BACKUP/temp/.vscodium/User

# GPG
cp -r ~/.gnupg $BACKUP/temp/.gnupg

# KeePassXC Database
cp ~/.local/.kdbx $BACKUP/temp/.kdbx

# Git
cp ~/.gitconfig $BACKUP/temp/.gitconfig

# Bash History
cp ~/.bash_history $BACKUP/temp/.bash_history