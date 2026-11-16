#!/usr/bin/env bash
#
# Menjalankan PetraPark (Linux / macOS):
#   - backend  : FastAPI + YOLO  -> http://127.0.0.1:8001  (port tetap, dipakai UI)
#   - aplikasi : Flutter web      -> http://localhost:<port> (port kosong dipilih otomatis, mulai 5600)
#
# Pemakaian:
#   ./start.sh              # jalankan backend + aplikasi web, buka browser
#   ./start.sh --build      # bangun ulang aplikasi web dulu (butuh Flutter)
#   ./start.sh --no-browser # jangan buka browser
#   ./start.sh --setup      # buat .venv lalu pasang backend/requirements.txt (sekali saja)
#
# Tekan Ctrl+C untuk menghentikan keduanya.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT/backend"
UI_DIR="$ROOT/parking_ui"
WEB_DIR="$UI_DIR/build/web"

BACKEND_PORT=8001          # dikunci: parking_ui/lib/common.dart memanggil 127.0.0.1:8001
WEB_PORT_START=5600
WEB_PORT_END=5699

BUILD=0
OPEN_BROWSER=1
SETUP=0

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; cyan=$'\033[36m'; reset=$'\033[0m'

info()  { printf '%s\n' "${cyan}$*${reset}"; }
ok()    { printf '%s\n' "${green}$*${reset}"; }
warn()  { printf '%s\n' "${yellow}$*${reset}"; }
fail()  { printf '%s\n' "${red}$*${reset}" >&2; exit 1; }
usage() {
  cat <<EOF
Menjalankan PetraPark (Linux / macOS): backend di port $BACKEND_PORT dan aplikasi web di port kosong mulai $WEB_PORT_START.

Pemakaian: ./start.sh [pilihan]

  -b, --build        Bangun ulang aplikasi web dulu (butuh Flutter).
  -n, --no-browser   Jangan buka browser otomatis.
  -s, --setup        Buat .venv dan pasang backend/requirements.txt (sekali saja).
  -h, --help         Tampilkan bantuan ini.

Tekan Ctrl+C untuk menghentikan keduanya.
EOF
}

for arg in "$@"; do
  case "$arg" in
    -b|--build)      BUILD=1 ;;
    -n|--no-browser) OPEN_BROWSER=0 ;;
    -s|--setup)      SETUP=1 ;;
    -h|--help)       usage; exit 0 ;;
    *)               fail "Pilihan tidak dikenal: $arg (lihat --help)" ;;
  esac
done

# --- Python -----------------------------------------------------------------
find_python() {
  local candidate
  for candidate in "$ROOT/.venv/bin/python" "$ROOT/trial1/.venv/bin/python"; do
    if [[ -x "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
  done
  if command -v python3 >/dev/null 2>&1; then command -v python3; return 0; fi
  return 1
}

setup_python() {
  local base
  base="$(command -v python3 || true)"
  [[ -n "$base" ]] || fail "python3 tidak ditemukan. Pasang Python 3.10+ (disarankan 3.12)."
  info "Membuat virtual environment di $ROOT/.venv ..."
  "$base" -m venv "$ROOT/.venv"
  info "Memasang paket backend (PyTorch + Ultralytics, bisa beberapa menit) ..."
  "$ROOT/.venv/bin/python" -m pip install --upgrade pip
  "$ROOT/.venv/bin/python" -m pip install -r "$BACKEND_DIR/requirements.txt"
  ok "Backend siap."
}

if [[ $SETUP -eq 1 ]]; then setup_python; fi

PYTHON="$(find_python)" || fail "Python tidak ditemukan. Jalankan ./start.sh --setup atau pasang Python 3.10+."

if ! "$PYTHON" -c 'import fastapi, uvicorn, ultralytics, cv2, multipart' >/dev/null 2>&1; then
  fail "Paket backend belum terpasang untuk: $PYTHON

Siapkan dulu (sekali saja, unduhan sekitar 1 GB):
  python3 -m venv .venv
  .venv/bin/python -m pip install -r backend/requirements.txt

Atau cukup jalankan:  ./start.sh --setup"
fi

# --- Port -------------------------------------------------------------------
port_in_use() {
  local port=$1
  (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
}

free_port() {
  local port
  for ((port = WEB_PORT_START; port <= WEB_PORT_END; port++)); do
    if ! port_in_use "$port"; then printf '%s\n' "$port"; return 0; fi
  done
  return 1
}

if port_in_use "$BACKEND_PORT"; then
  fail "Port $BACKEND_PORT sedang dipakai. Hentikan aplikasi yang memakainya (mungkin PetraPark sudah berjalan), lalu coba lagi."
fi

WEB_PORT="$(free_port)" || fail "Tidak ada port kosong di $WEB_PORT_START-$WEB_PORT_END."
if [[ "$WEB_PORT" != "$WEB_PORT_START" ]]; then
  warn "Port $WEB_PORT_START sedang dipakai, aplikasi web memakai port $WEB_PORT."
fi

# --- Flutter (hanya jika perlu membangun) -----------------------------------
find_flutter() {
  local candidate
  if command -v flutter >/dev/null 2>&1; then command -v flutter; return 0; fi
  for candidate in "$HOME/flutter/bin/flutter" "$HOME/development/flutter/bin/flutter" \
                   "$HOME/snap/flutter/common/flutter/bin/flutter" "/opt/flutter/bin/flutter"; do
    if [[ -x "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
  done
  return 1
}

if [[ $BUILD -eq 1 || ! -f "$WEB_DIR/index.html" ]]; then
  FLUTTER="$(find_flutter)" || fail "Aplikasi web belum dibangun dan Flutter tidak ditemukan.
Pasang Flutter (https://docs.flutter.dev/get-started/install) atau tambahkan folder bin-nya ke PATH."
  info "Membangun aplikasi web (sekitar 1 menit)..."
  (cd "$UI_DIR" && "$FLUTTER" build web) || fail "Gagal membangun aplikasi web."
fi

# --- Jalankan ---------------------------------------------------------------
PIDS=()

start_bg() {
  local dir=$1
  shift
  (cd "$dir" && exec "$@") &
  LAST_PID=$!
  PIDS+=("$LAST_PID")
}

cleanup() {
  local pid
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    if command -v pkill >/dev/null 2>&1; then
      pkill -TERM -P "$pid" 2>/dev/null || true
    fi
  done
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${PIDS[@]:-}"; do
    [[ -z "$pid" ]] && continue
    wait "$pid" 2>/dev/null || true
  done
  printf '%s\n' "${cyan}PetraPark dihentikan.${reset}"
}
trap 'exit 130' INT TERM
trap cleanup EXIT

info "Menjalankan backend di http://127.0.0.1:$BACKEND_PORT ..."
start_bg "$BACKEND_DIR" "$PYTHON" main2.py
BACKEND_PID="$LAST_PID"

# Tunggu backend siap (memuat model YOLO butuh beberapa detik).
http_ok() {
  local url=$1
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 2 "$url" >/dev/null 2>&1
  else
    "$PYTHON" - "$url" <<'PY' >/dev/null 2>&1
import sys, urllib.request
urllib.request.urlopen(sys.argv[1], timeout=2).read()
PY
  fi
}

READY=0
for _ in $(seq 1 90); do
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    fail "Backend berhenti saat start. Lihat pesan error di atas."
  fi
  if http_ok "http://127.0.0.1:$BACKEND_PORT/api/health"; then READY=1; break; fi
  sleep 1
done
[[ $READY -eq 1 ]] || fail "Backend tidak siap setelah 90 detik. Lihat pesan error di atas."

info "Menjalankan aplikasi web di http://localhost:$WEB_PORT ..."
start_bg "$ROOT" "$PYTHON" -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$WEB_DIR"
WEB_PID="$LAST_PID"

URL="http://localhost:$WEB_PORT"
printf '\n'
ok "PetraPark siap: $URL"
ok "Tekan Ctrl+C untuk menghentikan backend dan aplikasi web."
printf '\n'

if [[ $OPEN_BROWSER -eq 1 ]]; then
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 &
  else warn "Buka manual: $URL"; fi
fi

# Berjalan sampai Ctrl+C atau salah satu proses berhenti.
while kill -0 "$BACKEND_PID" 2>/dev/null && kill -0 "$WEB_PID" 2>/dev/null; do
  sleep 1
done
kill -0 "$BACKEND_PID" 2>/dev/null || warn "Backend berhenti."
kill -0 "$WEB_PID" 2>/dev/null || warn "Aplikasi web berhenti."
