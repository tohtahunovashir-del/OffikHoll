#!/system/bin/sh
# Ускорение Movix / ZTE B867RE — запускается НА приставке.
# Делает три вещи, каждая с сохранением состояния для отката:
#   1) отключает бloat из movix-candidates.txt (только если он установлен);
#   2) ставит анимации 0.5x;
#   3) ОПЦИОНАЛЬНО: ставит новый лаунчер из movix-home.apk и отключает сток-лаунчер
#      (включается сам, если файл movix-home.apk передан обёрткой run.bat / run.sh).
# Откат: scripts/rollback.sh (читает movix-state.txt и movix-disabled.txt).
set -u

TMP=${CMTV_TMP:-/data/local/tmp}
STATE=$TMP/movix-state.txt
DISLIST=$TMP/movix-disabled.txt
CAND=$TMP/movix-candidates.txt
APK=$TMP/movix-home.apk
STOCK=com.ertelecom.domrutvstb
HOME_QUERY='cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'

say() { echo "== $*"; }

installed() {
  # pm path отвечает "package:..." только для установленных (в том числе отключённых).
  case "$(pm path "$1" 2>/dev/null)" in package:*) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------------ 1. резерв состояния
HOME_BEFORE=$($HOME_QUERY | tail -n 1 | tr -d '\r')
W=$(settings get global window_animation_scale | tr -d '\r')
T=$(settings get global transition_animation_scale | tr -d '\r')
A=$(settings get global animator_duration_scale | tr -d '\r')
{
  echo "created=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "home_before=$HOME_BEFORE"
  echo "window_animation_scale=$W"
  echo "transition_animation_scale=$T"
  echo "animator_duration_scale=$A"
} > "$STATE"
[ -f "$DISLIST" ] || : > "$DISLIST"
pm list packages | tr -d '\r' | sed 's/^package://' | sort > "$TMP/movix-pkgs-before.txt"

say "Home сейчас: ${HOME_BEFORE:-ничего}"
say "Состояние сохранено: $STATE"

# ------------------------------------------------------------------ 2. деблот
if [ ! -f "$CAND" ]; then
  say "нет $CAND — деблот пропущен"
else
  ALREADY=$(pm list packages -d | tr -d '\r' | sed 's/^package://' | sort)
  DONE=0; MISS=0; SKIP=0
  while IFS= read -r pkg || [ -n "$pkg" ]; do
    # убрать перевод строки, хвостовой комментарий " # note" и пробелы (без awk — его может не быть на Android 9)
    pkg=$(echo "$pkg" | tr -d '\r' | sed 's/#.*//; s/[[:space:]]*$//; s/^[[:space:]]*//')
    case "$pkg" in '') continue ;; esac
    # защитный список: даже если файл кандидатов отредактирован руками
    case "$pkg" in
      com.ertelecom.*|\
      com.google.android.tvlauncher|com.google.android.apps.tv.launcherx|\
      com.google.android.leanbacklauncher|com.mitv.tvhome|\
      com.google.android.tv.remote.service|com.google.android.apps.mediashell|\
      com.google.android.katniss|com.google.android.speech.pumpkin|\
      com.google.android.gms|com.google.android.gsf|com.android.vending|\
      com.google.android.tungsten.setupwraith|\
      com.android.bluetooth|com.android.networkstack|com.android.networkstack.*|\
      com.android.phone|com.android.settings)
        echo "GUARD  $pkg (защитный список — не трогаю)"; SKIP=$((SKIP + 1)); continue ;;
    esac
    if echo "$ALREADY" | grep -Fqx "$pkg"; then
      echo "WAS    $pkg (уже был отключён)"; SKIP=$((SKIP + 1)); continue
    fi
    if ! installed "$pkg"; then
      echo "MISS   $pkg (не установлен)"; MISS=$((MISS + 1)); continue
    fi
    out=$(pm disable-user --user 0 "$pkg" 2>&1)
    case "$out" in
      *disabled*)
        echo "$pkg" >> "$DISLIST"
        echo "OFF    $pkg"; DONE=$((DONE + 1)) ;;
      *)
        echo "FAIL   $pkg: $(echo "$out" | tr -d '\r' | head -n 1)"; SKIP=$((SKIP + 1)) ;;
    esac
  done < "$CAND"
  say "деблот: отключено $DONE, пропущено $SKIP, не установлено $MISS"
  say "список отключённых: $DISLIST"
fi

# ------------------------------------------------------------------ 3. анимации
say "ставлю анимации 0.5x (было: окно=$W переход=$T аним=$A)"
settings put global window_animation_scale 0.5
settings put global transition_animation_scale 0.5
settings put global animator_duration_scale 0.5

# ------------------------------------------------------------------ 4. опциональная смена лаунчера
if [ ! -f "$APK" ]; then
  say "файл нового лаунчера не передан — сток-лаунчер $STOCK не трогаю"
else
  say "устанавливаю новый лаунчер из $APK"
  out=$(pm install -r "$APK" 2>&1)
  case "$out" in
    *Success*)
      say "установлено" ;;
    *)
      say "pm install не удался, смена лаунчера отменена: $(echo "$out" | tr -d '\r' | head -n 2)"
      APK_FAILED=1 ;;
  esac
  if [ -z "${APK_FAILED:-}" ]; then
    # новый пакет = тот, которого не было до оптимизации (без comm — на Android 9 его может не быть)
    pm list packages | tr -d '\r' | sed 's/^package://' | sort > "$TMP/movix-pkgs-after.txt"
    NEWPKG=""
    NEWN=0
    while IFS= read -r p || [ -n "$p" ]; do
      [ -z "$p" ] && continue
      if ! grep -Fqx "$p" "$TMP/movix-pkgs-before.txt"; then
        NEWPKG="$p"
        NEWN=$((NEWN + 1))
      fi
    done < "$TMP/movix-pkgs-after.txt"
    N=$NEWN
    if [ -z "$NEWPKG" ]; then
      say "новый пакет не появился (лаунчер уже был установлен?) — сток-лаунчер не отключаю."
      say "если лаунчер уже стоит: убери файл movix-home.apk или переустанови его вручную."
    elif [ "$N" -gt 1 ]; then
      say "apk поставил $N пакетов ($N шт) — не угадаю главный, смена лаунчера отменена."
    else
      NEWCOMP=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME -p "$NEWPKG" 2>/dev/null | tail -n 1 | tr -d '\r')
      case "$NEWCOMP" in
        */*) ;;
        *) NEWCOMP="$NEWPKG/.MainActivity" ;;
      esac
      say "новый лаунчер: $NEWPKG -> $NEWCOMP"
      start=$(am start -W -n "$NEWCOMP" 2>&1)
      case "$start" in
        *"Status: ok"*)
          say "запуск: ok"
          ;;
        *)
          say "лаунчер не стартовал, смена отменена: $(echo "$start" | tr -d '\r' | head -n 2)"
          NEWCOMP=""
          ;;
      esac
      if [ -n "$NEWCOMP" ]; then
        cmd package compile -m speed -f "$NEWPKG" >/dev/null 2>&1 || true
        # по порядку upstream build-and-install.sh: выключить сток, назначить Home, проверить
        if [ "${HOME_BEFORE%%/*}" = "$STOCK" ] && installed "$STOCK"; then
          out=$(pm disable-user --user 0 "$STOCK" 2>&1)
          case "$out" in
            *disabled*) echo "$STOCK" >> "$DISLIST"; say "$STOCK выключен (отключаемый, не удалённый)" ;;
            *) say "не удалось выключить $STOCK: $out" ;;
          esac
        fi
        cmd package set-home-activity --user 0 "$NEWCOMP" >/dev/null 2>&1 || \
          echo "внимание: set-home-activity не поддерживается — полагаюсь на выключение стока"
        NOW=$($HOME_QUERY | tail -n 1 | tr -d '\r')
        case "$NOW" in
          "$NEWCOMP"*)
            say "Home теперь: $NOW — ГОТОВО"
            ;;
          *)
            say "Home = '$NOW', а не новый лаунчер. Возвращаю как было."
            if grep -qx "$STOCK" "$DISLIST"; then
              pm enable "$STOCK" >/dev/null 2>&1 || true
              grep -vx "$STOCK" "$DISLIST" > "$DISLIST.tmp" || true
              mv "$DISLIST.tmp" "$DISLIST"
            fi
            case "${HOME_BEFORE%%/*}" in
              */*) cmd package set-home-activity --user 0 "$HOME_BEFORE" >/dev/null 2>&1 || true ;;
            esac
            NOW2=$($HOME_QUERY | tail -n 1 | tr -d '\r')
            say "откатил, Home = $NOW2"
            ;;
        esac
      fi
    fi
  fi
fi

say "Готово. Рекомендуется перезагрузка приставки (вынуть питание или: adb reboot)."
say "Откат: run.bat rollback <IP>"
