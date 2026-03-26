#!/bin/bash
set -e

echo "🧹 Cleaning build artifacts..."

cd "/Users/dinz/Coding Projects/lpointer"

# Remove build directory
rm -rf .build

# Remove installed app
if [ -d ~/Applications/SpeakYourMind.app ]; then
    echo "🗑️  Removing installed app..."
    rm -rf ~/Applications/SpeakYourMind.app
fi

# Kill running instance if exists
pkill -f SpeakYourMind 2>/dev/null || true

echo "✅ Clean complete!"
