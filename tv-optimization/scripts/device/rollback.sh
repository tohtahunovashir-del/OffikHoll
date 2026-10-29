#!/system/bin/sh
# Откат изменений, сделанных optimize.sh — запускается НА приставке.
# 1) обратно включает всё, что отключил optimize (movix-disabled.txt);
# 2) возвращает анимации как было (movix-state.txt);
# 3) возвращает Home (movix-state.txt / сток-лаунчер).
set -u

TMP=${CMTV_TMP:-/data/local/tmp}
STATE=$TMP/movix-state.txt
DISLIST=$TMP/movix-disabled.txt
STOCK=com.ertelecom.domrutvstb
HOME_QUERY='cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'

say() { echo "== $*"; }

# ------------------------------------------------------------------ 1. включить пакеты
if [ -f "$DISLIST" ]; then
  OK=0; BAD=0
  while IFS= read -r pkg || [ -n "$pkg" ]; do
    pkg=$(echo "$pkg" | tr -d '\r')
    case "$pkg" in '') continue ;; esac
    out=$(pm enable "$pkg" 2>&1)
    case "$out" in
      *enabled*) echo "ON     $pkg"; OK=$((OK + 1)) ;;
      *)         echo "SKIP   $pkg: $(echo "$out" | tr -d '\r' | head -n 1)"; BAD=$((BAD + 1)) ;;
    esac
  done < "$DISLIST"
  say "включено обратно: $OK, пропущено: $BAD"
else
  say "нет $DISLIST — нечего включать"
fi

# ------------------------------------------------------------------ 2. анимации как были
if [ -f "$STATE" ]; then
  W=$(grep '^window_animation_scale=' "$STATE" | head -n 1 | cut -d= -f2-)
  T=$(grep '^transition_animation_scale=' "$STATE" | head -n 1 | cut -d= -f2-)
  A=$(grep '^animator_duration_scale=' "$STATE" | head -n 1 | cut -d= -f2-)
  for kv in "window_animation_scale:$W" "transition_animation_scale:$T" "animator_duration_scale:$A"; do
    key=${kv%%:*}; val=${kv#*:}
    if [ -z "$val" ] || [ "$val" = "null" ]; then
      settings delete global "$key" >/dev/null 2>&1 || true
    else
      settings put global "$key" "$val"
    fi
  done
  say "анимации восстановлены (окно=${W:-?} переход=${T:-?} аним=${A:-?})"
else
  say "нет $STATE — анимации не трогаю"
fi

# ------------------------------------------------------------------ 3. Home как было
HB=""
[ -f "$STATE" ] && HB=$(grep '^home_before=' "$STATE" | head -n 1 | cut -d= -f2-)
# сток-лаунчер включаем ДО resolve/set-home, но только если его выключали мы или он был Home
NEED_STOCK=0
grep -Fqx "$STOCK" "$DISLIST" 2>/dev/null && NEED_STOCK=1
[ "$(echo "${HB:-}" | cut -d/ -f1)" = "$STOCK" ] && NEED_STOCK=1
[ "$NEED_STOCK" = 1 ] && pm enable "$STOCK" >/dev/null 2>&1 || true
TARGET=""
case "$HB" in */*) TARGET="$HB" ;; esac
if [ -z "$TARGET" ]; then
  # компонент стока: resolve с указанием пакета
  TARGET=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME "$STOCK" 2>/dev/null | tail -n 1 | tr -d '\r')
fi
case "$TARGET" in
  */*)
    cmd package set-home-activity --user 0 "$TARGET" >/dev/null 2>&1 || true
    NOW=$($HOME_QUERY | tail -n 1 | tr -d '\r')
    if [ "$NOW" = "$TARGET" ]; then
      say "Home восстановлен: $NOW"
      # состояние потреблено — следующая оптимизация запишет свежее
      rm -f "$STATE" "$DISLIST"
    else
      say "Home = '$NOW' (ожидал '$TARGET'). Если это не то — выбери Home вручную:"
      say "  adb shell cmd package set-home-activity --user 0 \$($HOME_QUERY $STOCK | tail -n 1)"
    fi
    ;;
  *)
    say "не смог определить компонент Home; выключаю... включаю сток и проверяю:"
    pm enable "$STOCK" >/dev/null 2>&1 || true
    NOW=$($HOME_QUERY | tail -n 1 | tr -d '\r')
    say "Home сейчас: $NOW"
    ;;
esac

say "Откат завершён. Новый лаунчер (если ставился) остался установлен — удалить:"
say "  adb shell pm uninstall <его.пакет>"
