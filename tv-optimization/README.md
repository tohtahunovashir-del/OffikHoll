# Ускорение Movix (ZTE B867RE, Дом.ру)

Комплект для отчистки и ускорения приставки + патч для CleanMyTV, чтобы обойти ошибку:

> **Home resolves to 'com.ertelecom.domrutvstb', which is not a stock launcher this app knows.**

## Почему появилась эта ошибка

В CleanMyTV есть жёсткий белый список стоковых лаунчеров
(`KNOWN_STOCK_LAUNCHERS` в `src/main/debloat.ts`):

```js
['com.google.android.tvlauncher', 'com.google.android.apps.tv.launcherx',
 'com.google.android.leanbacklauncher', 'com.mitv.tvhome']
```

У твоей приставки домашний экран — это лаунчер оператора `com.ertelecom.domrutvstb`
(софт ЭР-Телеком для Movix). Его в списке нет, поэтому приложение отказывается
ставить свой лаунчер: оно хочет заранее знать, **какой лаунчер выключать и на
какой откатывать**, если что-то пойдёт не так. Это защита, а не поломка.

**Решение:** добавить `com.ertelecom.domrutvstb` в этот список (патч ниже) —
и весь сценарий CleanMyTV заработает как задумано.

## Состав комплекта

```
tv-optimization/
├── README.md                      ← эта инструкция
├── patch/
│   └── cleanmytv-stock-launcher.patch   ← патч для CleanMyTV (патч B)
└── scripts/
    ├── run.bat                    ← обёртка Windows (для приставки по ADB)
    ├── run.sh                     ← обёртка macOS/Linux
    ├── debloat-candidates.txt     ← что отключать (правится руками)
    └── device/
        ├── diagnose.sh            ← запускается НА приставке: собирает инфо
        ├── optimize.sh            ← запускается НА приставке: ускорение
        └── rollback.sh            ← запускается НА приставке: полный откат
```

**Важно:** подключиться к приставке из моей среды нельзя — она в твоей домашней
сети, я её физически не вижу. Работаем так: ты запускаешь команды у себя,
присылаешь мне вывод логов — я разбираю и говорю, что делать дальше.

---

## Шаг 1 (обязательный): диагностика

Приставка: Настройки → О приставке → включить «Разработка» (7 нажатий на сборку) →
Developer options → USB debugging / сеть-отладка (у тебя уже включено, раз CleanMyTV
подключалась). Узнай IP (Настройки → Сеть, или список устройок в роутере).

**Windows:**

```bat
cd tv-optimization\scripts
run.bat diagnose 192.168.1.50
```

**macOS / Linux:**

```bash
cd tv-optimization/scripts
./run.sh diagnose 192.168.1.50
```

Лог сохранится в `scripts/logs/diagnose-log.txt`. **Пришли мне его содержимое** —
по нему я скажу: какие пакеты отключать, есть ли на приставке второй лаунчер
Google, отдельное приложение эфира и т.д.

> Если adb не найден: скрипт сам подскажет. CleanMyTV скачивал platform-tools в
> `%APPDATA%\CleanMyTV\tools\platform-tools\` — его достаточно добавить в PATH,
> либо взять platform-tools с developer.android.com.

---

## Шаг 2: ускорение (вариант A — скрипт, без сборки чего-либо)

Одна команда делает всё сразу: отключает бloat, ставит анимации 0.5x, а если
передать путь к лаунчеру — ставит его и делает домашним экраном:

```bat
run.bat optimize 192.168.1.50
```

```bash
./run.sh optimize 192.168.1.50
```

**С установкой лаунчера CleanMyTV Home** (нужен `home.apk` — он уже лежит у тебя
в установленном CleanMyTV, собирать ничего не надо):

```bat
run.bat optimize 192.168.1.50 "C:\Users\YOU\AppData\Local\Programs\CleanMyTV\resources\home.apk"
```

Где искать `home.apk`:
* открой папку, где лежит `CleanMyTV.exe` (обычно `C:\Users\<ты>\AppData\Local\Programs\CleanMyTV\`);
* рядом папка `resources\` — внутри `home.apk` (и `home.json`);
* на macOS: `/Applications/CleanMyTV.app/Contents/Resources/home.apk`.

Что делает скрипт (всё обратимо, ничего не удаляется — только `pm disable-user`):

| Шаг | Детали |
|-----|--------|
| Резерв | дом, значения анимаций и список отключённого → `movix-state.txt` / `movix-disabled.txt` |
| Деблот | только установленные пакеты из `debloat-candidates.txt`; **защитный список** не даст выключить `com.ertelecom.*`, пульт, сеть, Google Play, сток-лаунчеры |
| Анимации | window/transition/animator = 0.5 |
| Лаунчер (если передан apk) | установка → запуск → проверка «Status: ok» → выключение `com.ertelecom.domrutvstb` → назначение нового Home → проверка; при любой ошибке **автооткат** |

Логи: `scripts/logs/optimize-log.txt` (+ `movix-state.txt`, `movix-disabled.txt`).

**Что я НЕ отключаю по умолчанию** (решишь сам — раскомментируй в
`debloat-candidates.txt`): Chromecast (`mediashell`), голосовой поиск (`katniss`),
Ассистент, экранную речь. И никогда не трогаю `com.ertelecom.*` — это твоё ТВ.

### После оптимизации

* Перезагрузи приставку (вынуть питание или `adb reboot`).
* Хочешь ещё шустрее: анимации можно поставить `0.35` или `0` —
  `adb shell settings put global window_animation_scale 0.35` (и то же для
  `transition_animation_scale`, `animator_duration_scale`).
* Раз в месяц можно прогнать `cmd package bg-dexopt-job` — фоновая
  компиляция приложений под твои сценарии.

### Откат (в любой момент)

```bat
run.bat rollback 192.168.1.50
```

Включит обратно всё, что было отключено, вернёт анимации и домашний экран
(лаунчер Дом.ру). Новый лаунчер при этом останется установлен — удали его
вручную, если не нужен: `adb shell pm uninstall io.github.wingedpanther.cleanmytv.home`.

---

## Шаг 2: ускорение (вариант B — через GUI CleanMyTV, с патчем)

Если хочешь именно интерфейс CleanMyTV (списки по модели, настройки лаунчера,
Restore внутри приложения) — собери патченную версию. Нужен только Node.js.

1. **Node.js LTS** — https://nodejs.org (поставить).
2. Клонировать репозиторий:
   ```bat
   git clone https://github.com/wingedpanther/cleanmytv
   cd cleanmytv
   ```
3. Применить патч — **одним из двух способов**:
   ```bat
   git apply ..\OffikHoll\tv-optimization\patch\cleanmytv-stock-launcher.patch
   ```
   или вручную: открой `src/main/debloat.ts`, найди строку
   `export const KNOWN_STOCK_LAUNCHERS = [...]` и допиши первой
   `'com.ertelecom.domrutvstb',` внутрь массива.
4. Установить зависимости:
   ```bat
   npm ci
   ```
5. Скопировать готовые ресурсы из установленной CleanMyTV (списки деблота и
   `home.apk` — без этого Android SDK не нужен): папку `resources` из установки
   CleanMyTV → в корень клона (перезаписать/содержимое).
   **Проверь версию:** в `resources` установки должен лежать именно `home.apk`.
   Если там `launcher.apk`/`launcher.json` — у тебя старая 0.1.x: сначала
   поставь свежий релиз 0.2.0 с https://github.com/wingedpanther/cleanmytv/releases,
   иначе новый лаунчер не подхватится.
6. Запуск:
   * **напрямую:** `npm run dev` — откроется патченное приложение, работай как обычно;
   * **свой установщик:** `npm run dist:win` → готовый `dist\CleanMyTV-Setup-*.exe`.

После этого CleanMyTV примет `com.ertelecom.domrutvstb` за стоковый лаунчер:
очистка и установка CleanMyTV Home заработают, а откат пойдёт именно на лаунчер
Дом.ру (патч ставит его первым в списке, чтобы он предпочитался Google-лаунчеру,
который тоже может быть установлен рядом).

Патч проверен: `npm test` — 50/50 тестов зелёные, `typecheck` и сборка без ошибок.

---

## Предупреждения

* **Эфирные каналы живут в `com.ertelecom.domrutvstb`.** После смены лаунчера
  этот пакет **выключается** (не удаляется) — пока он выключен, его интерфейс
  (каналы, архив) не откроется. `rollback` возвращает всё за секунды. Если эфир
  тебе важнее скорости — запускай `optimize` **без** apk (только деблот+анимации).
* Обновление прошивки или сброс к заводским настройкам вернут всё как было —
  это нормально, запусти комплект снова.
* Всё, что делает скрипт, полностью обратна через `rollback`; ничего не
  удаляется из системы.
* Добавляй в `debloat-candidates.txt` только то, что точно не нужно (ivi, okko
  и т.п.) — после диагностики я подскажу, что из твоих пакетов реально мешает.

## Типичные проблемы

| Симптом | Решение |
|---------|---------|
| `adb не найден` | добавь platform-tools в PATH (см. Шаг 1) |
| `unable to connect` | приставка спит? проверь IP; отладка выключена? включи заново по Шагу 1; CleanMyTV пишет свой IP на экране подключения |
| `лаунчер не стартовал` | пришли лог `optimize-log.txt` — разберёмся |
| заклинил Wi-Fi / пульт | `run.bat rollback <IP>` — всё вернётся |
| вторая попытка ставит лаунчер и пишет «новый пакет не появился» | он уже установлен — убери `movix-home.apk` (или удали пакет) и запусти без apk |
