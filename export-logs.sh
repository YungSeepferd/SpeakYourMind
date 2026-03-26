#!/bin/bash

# Export logs from the last 2 hours to a file
echo "💾 Exporting SpeakYourMind logs to logs.txt..."

log show --predicate 'subsystem == "com.speakyourmind.app"' --last 2h --style compact > speakyourmind-logs-$(date +%Y%m%d-%H%M%S).txt

echo "✅ Logs saved to: $(pwd)/speakyourmind-logs-$(date +%Y%m%d-%H%M%S).txt"
