#!/system/bin/sh
# Проба команд установки лаунчера с ВОССТАНОВЛЕНИЕМ исходного состояния.
# Проверяет: существует ли set-home-activity, кто претендент на Home, выключается ли
# сток-лаунчер и не возвращает ли его прошивка (воутч), прилипает ли preference.
set -u
STOCK=com.ertelecom.domrutvstb
NEWPKG=io.github.wingedpanther.cleanmytv.home
HQ='cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'

say() { echo "== $*"; }
home_now() { $HQ | tail -n 1 | tr -d '\r'; }
is_disabled() {
  if pm list packages -d | tr -d '\r' | grep -Fq "package:$1"; then echo "ОТКЛЮЧЁН"; else echo "включён"; fi
}

say "0. android sdk=$(getprop ro.build.version.sdk), release=$(getprop ro.build.version.release)"
echo "-- есть ли подкоманда set-home-activity --"
cmd package set-home-activity 2>&1 | head -n 2 | tr -d '\r'
echo "-- из help --"
cmd package help 2>&1 | grep -F "set-home-activity" || echo "(в help не найдена)"

say "1. Текущий Home"
COMP0=$(home_now)
echo "home = ${COMP0:-ничего}"

say "2. Все претенденты на Home"
cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r'

say "3. Состояния пакетов"
for p in $STOCK $NEWPKG; do
  case "$(pm path "$p" 2>/dev/null)" in
    package:*) echo "$p: установлен, $(is_disabled "$p")" ;;
    *)         echo "$p: НЕ установлен" ;;
  esac
done

say "4. Компонент HOME нового лаунчера ($NEWPKG)"
NEWCOMP=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME "$NEWPKG" 2>/dev/null | tail -n 1 | tr -d '\r')
echo "new comp = ${NEWCOMP:-пусто — пакет не отвечает на HOME}"

say "5. ПРОБА set-home-activity на новый лаунчер"
case "$NEWCOMP" in
  */*)
    out=$(cmd package set-home-activity --user 0 "$NEWCOMP" 2>&1 | tr -d '\r' | head -n 2)
    echo "команда сказала: ${out:-тишина (exit ok?)}"
    echo "home сразу после = $(home_now)"
    ;;
  *)
    echo "проба пропущена — нет компонента"
    ;;
esac

say "6. ПРОБА pm disable-user на сток (спим 8с — ловим воутч прошивки)"
out=$(pm disable-user --user 0 "$STOCK" 2>&1 | tr -d '\r' | head -n 2)
echo "disable-user сказал: ${out:-тишина}"
echo "сток: $(is_disabled "$STOCK")"
echo "home сразу после = $(home_now)"
sleep 8
echo "через 8 секунд — сток: $(is_disabled "$STOCK")"
echo "home через 8с = $(home_now)"

say "7. ВОССТАНОВЛЕНИЕ исходного состояния"
out=$(pm enable "$STOCK" 2>&1 | tr -d '\r' | head -n 1)
echo "enable сказал: ${out:-тишина}"
case "$COMP0" in
  */*)
    cmd package set-home-activity --user 0 "$COMP0" >/dev/null 2>&1
    echo "set-home обратно на $COMP0 выполнен"
    ;;
esac
FINAL=$(home_now)
echo "финальный home = $FINAL"
if [ "$FINAL" = "$COMP0" ]; then
  echo "РЕЗУЛЬТАТ: исходное состояние восстановлено, приставка как до пробы ✓"
else
  echo "РЕЗУЛЬТАТ: home отличается от исходного ($COMP0) — сообщи об этом!"
fi

say "8. Preferred Activities (кто прописан предпочтительным Home)"
dumpsys package 2>/dev/null | grep -A 15 "Preferred Activities" | head -n 22 | tr -d '\r'
say "probe завершён"
