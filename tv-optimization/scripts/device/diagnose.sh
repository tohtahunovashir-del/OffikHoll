#!/system/bin/sh
# Диагностика Movix / ZTE B867RE — запускается НА приставке (Android shell).
# Собирает всё, что нужно, чтобы подобрать безопасный план ускорения.
# Вывод пишется в лог через tee (обёртка run.bat / run.sh тянет его обратно).

TMP=${CMTV_TMP:-/data/local/tmp}
HOME_QUERY='cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
HOME_CLAIMS='cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME'

echo "== Устройство =="
echo "manufacturer=$(getprop ro.product.manufacturer)"
echo "model=$(getprop ro.product.model)"
echo "device=$(getprop ro.product.device)"
echo "android=$(getprop ro.build.version.release) (sdk $(getprop ro.build.version.sdk))"
echo "build=$(getprop ro.build.display.id)"
echo "adb_secure=$(getprop ro.adb.secure)"
echo "fingerprint=$(getprop ro.build.fingerprint)"

echo ""
echo "== Кто владеет Home =="
$HOME_QUERY | tr -d '\r'
echo "-- все претенденты --"
$HOME_CLAIMS | tr -d '\r'

echo ""
echo "== Лаунчеры и ключевые пакеты =="
for p in com.ertelecom.domrutvstb com.google.android.tvlauncher \
         com.google.android.apps.tv.launcherx com.google.android.leanbacklauncher \
         io.github.wingedpanther.cleanmytv.home com.gathin.tvhome \
         com.google.android.tungsten.setupwraith; do
  out=$(pm path "$p" 2>/dev/null)
  case "$out" in
    package:*) echo "EST  $p" ;;
    *)         echo "NO   $p" ;;
  esac
done

echo ""
echo "== Пакеты оператора / ТВ =="
pm list packages | tr -d '\r' | grep -iE 'ertelecom|dom\.ru|movix|dtv|iptv|tvinput|amlogic|zte' || echo "(не найдены)"

echo ""
echo "== Сторонние приложения (установленные вами) =="
pm list packages -3 | tr -d '\r'

echo ""
echo "== Отключённые сейчас =="
pm list packages -d | tr -d '\r'

echo ""
echo "== Анимации =="
echo "window_animation_scale=$(settings get global window_animation_scale)"
echo "transition_animation_scale=$(settings get global transition_animation_scale)"
echo "animator_duration_scale=$(settings get global animator_duration_scale)"

echo ""
echo "== Память и диск =="
grep -E 'MemTotal|MemAvailable' /proc/meminfo
df /data

echo ""
echo "== ВСЕ пакеты (полный список) =="
pm list packages | tr -d '\r' | sort

echo ""
echo "== Готово =="
