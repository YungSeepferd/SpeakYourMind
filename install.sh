#!/bin/bash
set -e

echo "🔨 Building SpeakYourMind..."

cd "/Users/dinz/Coding Projects/lpointer"

# Clean previous build
rm -rf .build/release

# Build release version
swift build -c release

# Create Applications directory if it doesn't exist
mkdir -p ~/Applications

# Remove old version if exists
if [ -d ~/Applications/SpeakYourMind.app ]; then
    echo "🗑️  Removing old version..."
    rm -rf ~/Applications/SpeakYourMind.app
fi

# Create app bundle structure
echo "📦 Creating app bundle..."
mkdir -p ~/Applications/SpeakYourMind.app/Contents/MacOS
mkdir -p ~/Applications/SpeakYourMind.app/Contents/Resources

# Copy executable
cp .build/release/SpeakYourMind ~/Applications/SpeakYourMind.app/Contents/MacOS/

# Copy Info.plist from source
cp SpeakYourMind/Info.plist ~/Applications/SpeakYourMind.app/Contents/Info.plist

# Make executable
chmod +x ~/Applications/SpeakYourMind.app/Contents/MacOS/SpeakYourMind

echo "✅ Installation complete!"
echo "📍 Installed to: ~/Applications/SpeakYourMind.app"
echo ""
echo "To run: open ~/Applications/SpeakYourMind.app"
echo "To view logs: log stream --predicate 'subsystem == \"com.speakyourmind.app\"' --info"