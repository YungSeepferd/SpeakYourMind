#!/bin/bash

# View live logs from SpeakYourMind
echo "📋 Streaming SpeakYourMind logs... (Ctrl+C to stop)"
echo ""

log stream --predicate 'subsystem == "com.speakyourmind.app"' --info --style compact
