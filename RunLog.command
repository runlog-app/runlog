#!/bin/bash
# RunLog launcher for Mac. Checks for a new RunLog, downloads it if there is one, and opens it.
# The same script opens RunLog Coach when APP=Coach (the "RunLog Coach.command" copy sets it).
# Your data is never touched: it lives in your browser. Works offline with the copy you have.
BASE="${RUNLOG_BASE:-https://raw.githubusercontent.com/runlog-app/runlog/main}"
DIR="$HOME/Library/Application Support/RunLog"
APP="${APP:-RunLog}"
HTML="$DIR/$APP.html"
VERNAME=$([ "$APP" = "Coach" ] && echo coach-version.txt || echo version.txt)
VER="$DIR/$VERNAME"
mkdir -p "$DIR"

remote=$(curl -fsSL --max-time 10 "$BASE/$VERNAME" 2>/dev/null | tr -d '\r' | head -n 1)
if [[ "$remote" =~ ^[^[:space:]]+[[:space:]]+[0-9a-f]{64}$ ]] && { [ ! -f "$HTML" ] || [ "$remote" != "$(cat "$VER" 2>/dev/null)" ]; }; then
  sha="${remote##* }"
  if curl -fsSL --max-time 120 "$BASE/$APP.html" -o "$HTML.download" \
     && [ "$(shasum -a 256 "$HTML.download" | cut -d ' ' -f 1)" = "$sha" ]; then
    [ -f "$HTML" ] && cp "$HTML" "$DIR/$APP.previous.html"
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

# First time only: older RunLog files saved by hand on the Desktop or in Downloads or Documents are
# moved (never deleted) into the RunLog folder, after asking. Data lives in the browser, not the file.
if [ ! -f "$DIR/.old-copies-checked" ]; then
  touch "$DIR/.old-copies-checked"
  old=()
  for f in "$HOME/Desktop"/*.htm* "$HOME/Downloads"/*.htm* "$HOME/Documents"/*.htm*; do
    [ -f "$f" ] && head -c 4096 "$f" 2>/dev/null | grep -qE '<title>RunLog( Coach)?</title>' && old+=("$f")
  done
  if [ ${#old[@]} -gt 0 ]; then
    list=$(for f in "${old[@]}"; do echo "${f/#$HOME/~}"; done)
    if osascript -e "display dialog \"Found older RunLog files you saved yourself:\n\n$list\n\nYour data is kept: it lives in your browser. Move these into the RunLog folder so only the up-to-date apps are left?\" buttons {\"Leave them\", \"Move\"} default button \"Move\" with title \"RunLog\"" 2>/dev/null | grep -q Move; then
      keep="$DIR/Old copies/$(date +%Y-%m-%d)"; mkdir -p "$keep"
      for f in "${old[@]}"; do mv -n "$f" "$keep/" ; done
    fi
  fi
fi

URL="file://${HTML// /%20}"
if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="$URL"
elif [ -d "/Applications/Microsoft Edge.app" ]; then
  open -na "Microsoft Edge" --args --app="$URL"
else
  open "$HTML"
fi
