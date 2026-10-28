#!/usr/bin/env bash
set -euo pipefail

port=9222
web_port="${PORT:-6080}"
browser_url="http://127.0.0.1:${port}/json/version"
file_url="http://127.0.0.1:6081/"
web_url="http://127.0.0.1:${web_port}"
browser_log=/tmp/chromerdp-chrome.log
desktop_log=/tmp/chromerdp-desktop.log
files_log=/tmp/chromerdp-files.log
file_directory=/workspaces/chromerdp-files
profile_directory=/workspaces/.chromerdp-profile
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$file_directory" "$profile_directory"
profile_preferences="${profile_directory}/Default/Preferences"
mkdir -p "$(dirname "$profile_preferences")"
if [[ ! -f "$profile_preferences" ]]; then
  printf '{"download":{"default_directory":"%s","prompt_for_download":false}}\n' \
    "$file_directory" >"$profile_preferences"
fi

if ! pgrep -x Xvfb >/dev/null; then
  nohup Xvfb :0 -screen 0 1440x900x24 -nolisten tcp >"$desktop_log" 2>&1 </dev/null &
fi

for _ in {1..15}; do
  if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
  echo "The virtual desktop did not become ready. See ${desktop_log}." >&2
  exit 1
fi

if ! pgrep -x openbox >/dev/null; then
  DISPLAY=:0 nohup openbox >"$desktop_log" 2>&1 </dev/null &
fi

if ! pgrep -x x11vnc >/dev/null; then
  nohup x11vnc -display :0 -localhost -forever -shared -nopw -rfbport 5900 \
    >>"$desktop_log" 2>&1 </dev/null &
fi

if ! curl --fail --silent "${web_url}/vnc.html" >/dev/null; then
  nohup websockify --web=/usr/share/novnc "$web_port" localhost:5900 \
    >>"$desktop_log" 2>&1 </dev/null &
fi

if ! curl --fail --silent "$file_url" >/dev/null; then
  FILE_ROOT="$file_directory" nohup python3 "${script_directory}/fileserver.py" \
    >"$files_log" 2>&1 </dev/null &
fi

chrome_pid=""
if ! curl --fail --silent "$browser_url" >/dev/null; then
  DISPLAY=:0 nohup chromium \
    --no-sandbox \
    --disable-dev-shm-usage \
    --remote-debugging-port="$port" \
    --user-data-dir="$profile_directory" \
    about:blank >"$browser_log" 2>&1 </dev/null &
  chrome_pid=$!

  for _ in {1..30}; do
    if curl --fail --silent "$browser_url" >/dev/null; then
      break
    fi
    if ! kill -0 "$chrome_pid" 2>/dev/null; then
      echo "Chromium exited during startup. See ${browser_log}." >&2
      exit 1
    fi
    sleep 1
  done

  if ! curl --fail --silent "$browser_url" >/dev/null; then
    echo "Chromium did not become ready on port ${port}. See ${browser_log}." >&2
    exit 1
  fi
fi

for _ in {1..30}; do
  if curl --fail --silent "$file_url" >/dev/null; then
    echo "Chromium is ready on port ${port}; browser UI on port ${web_port}; file transfer on port 6081."
    break
  fi
  sleep 1
done

if ! curl --fail --silent "$file_url" >/dev/null; then
  echo "The file-transfer page did not become ready on port 6081. See ${files_log}." >&2
  exit 1
fi

if [[ "${1:-}" != "--keepalive" ]]; then
  exit 0
fi

if [[ -z "$chrome_pid" ]]; then
  chrome_pid="$(pgrep -o -x chromium)" || {
    echo "Chromium is running but its process could not be found." >&2
    exit 1
  }
  while kill -0 "$chrome_pid" 2>/dev/null; do
    sleep 5
  done
  echo "Chromium exited unexpectedly. See ${browser_log}." >&2
  exit 1
fi

set +e
wait "$chrome_pid"
status=$?
set -e

echo "Chromium exited unexpectedly. See ${browser_log}." >&2
if [[ "$status" -eq 0 ]]; then
  status=1
fi
exit "$status"
