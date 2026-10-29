@echo off
setlocal EnableExtensions
rem ============================================================================
rem Ускорение Movix / ZTE B867RE (Дом.ру) через ADB по сети.
rem Использование:
rem   run.bat diagnose            — собрать информацию о приставке (первая команда!)
rem   run.bat optimize [IP] [путь\к\home.apk]  — отключить бloat + анимации (+ смена лаунчера)
rem   run.bat rollback  [IP]      — вернуть всё как было
rem IP можно не указывать — скрипт спросит.
rem ============================================================================
set "MODE=%~1"
if "%MODE%"=="" set "MODE=diagnose"
if /I not "%MODE%"=="diagnose" if /I not "%MODE%"=="optimize" if /I not "%MODE%"=="rollback" (
  echo Неизвестная команда: %MODE%. Нужна diagnose ^| optimize ^| rollback.
  exit /b 1
)
set "IP=%~2"
set "APK=%~3"
set "DIR=%~dp0"
if not exist "%DIR%logs" mkdir "%DIR%logs"

rem ---------- найти adb: PATH, затем папка CleanMyTV (он сам скачивает platform-tools), затем SDK
set "ADB="
where adb >nul 2>nul && set "ADB=adb"
if not defined ADB if exist "%APPDATA%\CleanMyTV\tools\platform-tools\adb.exe" set "ADB=%APPDATA%\CleanMyTV\tools\platform-tools\adb.exe"
if not defined ADB if exist "%APPDATA%\CleanMyTV\tools\adb.exe" set "ADB=%APPDATA%\CleanMyTV\tools\adb.exe"
if not defined ADB if exist "%LOCALAPPDATA%\Programs\CleanMyTV\resources\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Programs\CleanMyTV\resources\platform-tools\adb.exe"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB (
  echo [!] adb не найден. Варианты:
  echo     1^) поставь Android platform-tools: https://developer.android.com/tools/releases/platform-tools
  echo        ^(zip -^> распаковать -^> папка в PATH^)
  echo     2^) если CleanMyTV предлагал качать platform-tools - возьми adb.exe оттуда:
  echo        %APPDATA%\CleanMyTV\tools\platform-tools\
  exit /b 1
)

rem ---------- IP приставки
if "%IP%"=="" set /p IP=IP-адрес приставки (Настройки -^> Сеть, или в роутере^): 
if "%IP%"=="" (
  echo [!] IP не указан.
  exit /b 1
)
set "T=%IP%:5555"

echo == Подключаюсь к %T% ...
"%ADB%" connect "%T%"
if /I "%MODE%"=="optimize" (
  echo == Пушу список кандидатов
  "%ADB%" -s "%T%" push "%DIR%debloat-candidates.txt" /data/local/tmp/movix-candidates.txt
  if not "%APK%"=="" (
    echo == Пушу лаунчер: %APK%
    "%ADB%" -s "%T%" push "%APK%" /data/local/tmp/movix-home.apk
  ) else (
    echo == ЛАУНЧЕР НЕ УКАЗАН - смена лаунчера пропущена ^(нужен путь к home.apk^)
  )
)
echo == Пушу скрипт %MODE%.sh
"%ADB%" -s "%T%" push "%DIR%device\%MODE%.sh" "/data/local/tmp/movix-%MODE%.sh"
echo == Выполняю на приставке (лог ниже и в logs\^)...
"%ADB%" -s "%T%" shell "sh /data/local/tmp/movix-%MODE%.sh 2>&1 | tee /data/local/tmp/movix-log.txt"

rem ---------- забрать логи
"%ADB%" -s "%T%" pull /data/local/tmp/movix-log.txt "%DIR%logs\%MODE%-log.txt" >nul 2>nul
if /I not "%MODE%"=="diagnose" (
  "%ADB%" -s "%T%" pull /data/local/tmp/movix-state.txt "%DIR%logs\movix-state.txt" >nul 2>nul
  "%ADB%" -s "%T%" pull /data/local/tmp/movix-disabled.txt "%DIR%logs\movix-disabled.txt" >nul 2>nul
)
echo.
echo == Лог сохранён: %DIR%logs\%MODE%-log.txt
if /I "%MODE%"=="diagnose" echo Открой его и пришли мне содержимое.
exit /b 0
