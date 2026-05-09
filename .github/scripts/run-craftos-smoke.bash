#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
CRAFTOS_PC_BIN="${CRAFTOS_PC_BIN:-${1:-}}"
SMOKE_TEST_TIMEOUT_DURATION="${SMOKE_TEST_TIMEOUT_DURATION:-60s}"

if [ -z "$CRAFTOS_PC_BIN" ]; then
  echo "Set CRAFTOS_PC_BIN or pass the CraftOS-PC executable path as the first argument." >&2
  exit 1
fi

for required_command in python3 timeout; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

workdir="$(mktemp -d)"
disk_root="$workdir/disk"
log_file="$workdir/craftos-smoke.log"

cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$disk_root"
(cd "$REPO_ROOT" && tar --exclude=.git -cf - .) | (cd "$disk_root" && tar -xf -)

mkdir -p "$disk_root/etc/apt/list" "$disk_root/usr/minux-main/data"
cp "$disk_root/etc/apt/manifest/minux-main.db" "$disk_root/etc/apt/list/minux-main.db"
# Skip the first-run updater so the smoke test exercises the checked-out tree only.
printf 'done\n' > "$disk_root/usr/minux-main/data/firstrun.db"
cat > "$disk_root/usr/minux-main/settings.cfg" <<'CFG'
login=disabled
ui=prompt
debug=disabled
network=disabled
update=disabled
welcome=disabled
encrypt=disabled
crashhandler=enabled
clearlogin=disabled
mapcleanup=disabled
CFG

python3 - "$disk_root/boot/init.sys" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
start = source.find("local initput = read()")
launch_ui = source.find("-- Launch configured UI", start)
if start == -1 or launch_ui == -1:
    raise SystemExit(
        "Failed to patch boot/init.sys: the welcome prompt block was not found. "
        "The boot flow likely changed and the CraftOS-PC smoke test needs updating."
    )
block = source[start:launch_ui]
if "while initput ~= nil do" not in block:
    raise SystemExit(
        "Failed to patch boot/init.sys: the welcome prompt loop was not found. "
        "The boot flow likely changed and the CraftOS-PC smoke test needs updating."
    )
path.write_text(source[:start] + "local initput = nil\n" + source[launch_ui:])
PY

set +e
SDL_AUDIODRIVER=dummy timeout "$SMOKE_TEST_TIMEOUT_DURATION" "$CRAFTOS_PC_BIN" --headless "-c=$disk_root" --script "$SCRIPT_DIR/craftos-smoke.lua" >"$log_file" 2>&1
status=$?
set -e

cat "$log_file"

if [ "$status" -ne 0 ]; then
  echo "CraftOS-PC exited with status $status" >&2
  exit "$status"
fi

if ! grep -q 'CRAFTOS_TEST_PASS' "$log_file"; then
  echo "CraftOS-PC smoke test did not report success." >&2
  exit 1
fi
