#!/bin/bash
# RunLog launcher for Mac. Checks for a new RunLog, downloads it if there is one, and opens it.
# Your data is never touched: it lives in your browser. Works offline with the copy you have.
BASE="${RUNLOG_BASE:-https://raw.githubusercontent.com/runlog-app/runlog/main}"
DIR="$HOME/Library/Application Support/RunLog"
HTML="$DIR/RunLog.html"
VER="$DIR/version.txt"
mkdir -p "$DIR"

remote=$(curl -fsSL --max-time 10 "$BASE/version.txt" 2>/dev/null | tr -d '\r' | head -n 1)
if [[ "$remote" =~ ^[^[:space:]]+[[:space:]]+[0-9a-f]{64}$ ]] && { [ ! -f "$HTML" ] || [ "$remote" != "$(cat "$VER" 2>/dev/null)" ]; }; then
  sha="${remote##* }"
  if curl -fsSL --max-time 120 "$BASE/RunLog.html" -o "$HTML.download" \
     && [ "$(shasum -a 256 "$HTML.download" | cut -d ' ' -f 1)" = "$sha" ]; then
    [ -f "$HTML" ] && cp "$HTML" "$DIR/RunLog.previous.html"
    mv "$HTML.download" "$HTML"
    echo "$remote" > "$VER"
  else
    rm -f "$HTML.download"
  fi
fi

if [ ! -f "$HTML" ]; then
  osascript -e 'display alert "RunLog could not be downloaded" message "Check your internet connection and try again."'
  exit 1
fi

URL="file://${HTML// /%20}"
if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="$URL"
elif [ -d "/Applications/Microsoft Edge.app" ]; then
  open -na "Microsoft Edge" --args --app="$URL"
else
  open "$HTML"
fi
