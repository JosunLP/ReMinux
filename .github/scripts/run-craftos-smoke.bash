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
target = """if pocket or turtle then
print("Hit Enter to start")
else
print("Welcome to ReMinux. Hit Enter to start.")
end
local initput = read()
while initput ~= nil do
if initput == "bash" then
minux.debug("launching prompt", "minux")
shell.run(bash)
elseif initput == "update" then
apt.update("-f")
initput = read()
elseif initput == "reboot" or initput == "restart" then
minux.restart()
elseif initput == "halt" or initput == "shutdown" then
minux.halt()
else
initput = nil
end
end"""
replacement = """if pocket or turtle then
print("Hit Enter to start")
else
print("Welcome to ReMinux. Hit Enter to start.")
end
local initput = nil"""

if target not in source:
    raise SystemExit(
        "Failed to patch boot/init.sys: the expected interactive boot prompt block was not found. "
        "The boot flow likely changed and the CraftOS-PC smoke test needs updating."
    )

path.write_text(source.replace(target, replacement, 1))
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
