#!/bin/zsh
# 可攜式啟動：第一次解壓縮會先自動匯入素材。
set -eu
TASK_GAME_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
launch_game() {
  local TASK_ENGINE="$1"
  if [[ ! -f "$TASK_GAME_DIR/.godot/global_script_class_cache.cfg" ]]; then
    print '第一次啟動：正在匯入遊戲素材，請稍候…'
    "$TASK_ENGINE" --headless --path "$TASK_GAME_DIR" --editor --import --quit
  fi
  exec "$TASK_ENGINE" --path "$TASK_GAME_DIR"
}
for TASK_GODOT in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$TASK_GODOT" ]]; then
    launch_game "$TASK_GODOT"
  fi
done
if command -v godot >/dev/null 2>&1; then
  launch_game "$(command -v godot)"
fi
print '請先安裝 Godot 4.7，或以 Godot 匯入此資料夾的 project.godot，再按 F5。'
read -k 1
