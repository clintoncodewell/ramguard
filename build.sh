#!/bin/bash
set -e
mkdir -p RamGuard.app/Contents/MacOS
swiftc -Osize -o RamGuard.app/Contents/MacOS/ramguard main.swift \
  -framework Cocoa \
  -framework UserNotifications
strip RamGuard.app/Contents/MacOS/ramguard
echo "Built RamGuard.app ($(du -h RamGuard.app/Contents/MacOS/ramguard | cut -f1 | xargs))"
