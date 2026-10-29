#!/usr/bin/env bash
# Ускорение Movix / ZTE B867RE (Дом.ру) через ADB по сети. macOS / Linux.
# Использование:
#   ./run.sh diagnose                    — информация о приставке (первая команда!)
#   ./run.sh optimize [IP] [путь/к/home.apk] — бloat + анимации (+ опционально смена лаунчера)
#   ./run.sh rollback  [IP]              — вернуть всё как было
#   ./run.sh probe     [IP]              — проба команд установки с откатом (диагноз ошибки Home)
set -euo pipefail
MODE=${1:-diagnose}
IP=${2:-}
APK=${3:-}
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/logs"

case "$MODE" in diagnose|optimize|rollback|probe) ;; *)
  echo "Неизвестная команда: $MODE (нужна diagnose | optimize | rollback | probe)" >&2; exit 1 ;;
esac

# ---------- найти adb: PATH, затем папка CleanMyTV, затем Android SDK
ADB=$(command -v adb || true)
if [ -z "$ADB" ]; then
  for c in \
    "$HOME/Library/Application Support/CleanMyTV/tools/platform-tools/adb" \
    "$HOME/AppData/Local/CleanMyTV/tools/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "$HOME/Android/Sdk/platform-tools/adb"; do
    if [ -x "$c" ]; then ADB=$c; break; fi
  done
fi
if [ -z "$ADB" ]; then
  echo "[!] adb не найден. Поставь Android platform-tools и добавь в PATH:" >&2
  echo "    https://developer.android.com/tools/releases/platform-tools" >&2
  exit 1
fi

# ---------- IP приставки
if [ -z "$IP" ]; then
  read -r -p "IP-адрес приставки (Настройки -> Сеть, или в роутере): " IP
fi
[ -n "$IP" ] || { echo "[!] IP не указан" >&2; exit 1; }
T="$IP:5555"

echo "== Подключаюсь к $T ..."
"$ADB" connect "$T" || true

if [ "$MODE" = optimize ]; then
  echo "== Пушу список кандидатов"
  "$ADB" -s "$T" push "$DIR/debloat-candidates.txt" /data/local/tmp/movix-candidates.txt
  if [ -n "$APK" ]; then
    echo "== Пушу лаунчер: $APK"
    "$ADB" -s "$T" push "$APK" /data/local/tmp/movix-home.apk
  else
    echo "== ЛАУНЧЕР НЕ УКАЗАН — смена лаунчера пропущена (нужен путь к home.apk)"
  fi
fi

echo "== Пушу скрипт $MODE.sh"
"$ADB" -s "$T" push "$DIR/device/$MODE.sh" "/data/local/tmp/movix-$MODE.sh"
echo "== Выполняю на приставке (лог ниже и в logs/)..."
"$ADB" -s "$T" shell "sh /data/local/tmp/movix-$MODE.sh 2>&1 | tee /data/local/tmp/movix-log.txt"

# ---------- забрать логи
"$ADB" -s "$T" pull /data/local/tmp/movix-log.txt "$DIR/logs/$MODE-log.txt" >/dev/null 2>&1 || true
if [ "$MODE" != diagnose ]; then
  "$ADB" -s "$T" pull /data/local/tmp/movix-state.txt "$DIR/logs/movix-state.txt" >/dev/null 2>&1 || true
  "$ADB" -s "$T" pull /data/local/tmp/movix-disabled.txt "$DIR/logs/movix-disabled.txt" >/dev/null 2>&1 || true
fi
echo
echo "== Лог сохранён: $DIR/logs/$MODE-log.txt"
