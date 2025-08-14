#!/bin/bash
BACKUP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# LibreWolf
cp -r ~/.librewolf/user $BACKUP/../backup/.librewolf/user

# VSCodium
cp -r ~/.config/VSCodium/User $BACKUP/../backup/VSCodium/User

# GPG
cp -r ~/.gnupg $BACKUP/../backup/.gnupg

# KeePassXC Database
cp ~/.local/.kdbx $BACKUP/../backup/.kdbx

# Git
cp ~/.gitconfig $BACKUP/../backup/.gitconfig

# Bash History
cp ~/.bash_history $BACKUP/../backup/.bash_history