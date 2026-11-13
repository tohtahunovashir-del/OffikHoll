# Bloknot — официантский блокнот

Нативное iOS-приложение для официанта: зал, счёт, меню и сканирование бумажного меню.
Полностью офлайн, без сети и без сервера.

- **iOS 16.0+**, iPhone, портретная ориентация
- **SwiftUI** для всего интерфейса, UIKit только для камеры (`CameraView: UIViewRepresentable`)
- **GRDB 6** (SQLite) как единственный источник истины, реактивные экраны на `ValueObservation`
- **MVVM**: `Views → ViewModels → Repositories → DB`, сервисы `OCRService` и `HapticsService`
- Модели — только `struct` (`Codable + FetchableRecord + PersistableRecord`), состояние — `@Published` + `ObservableObject`
- Интерфейс полностью на русском, без `TabView`: навигация только `NavigationStack`

## Сборка

Нужны Xcode 15+ и [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd Bloknot
xcodegen generate
open Bloknot.xcodeproj
```

CI собирает приложение без подписи и прогоняет тесты на симуляторе:
`.github/workflows/bloknot-build.yml`.

## Данные

При первом запуске миграция `v2_seed` создаёт демонстрационный набор:
10 категорий ровно по одному блюду и 12 столов (Основной зал, Терраса, Бар).
Это проверочные данные, а не меню реального заведения: название заведения,
адрес и телефон нигде не выдумываются. Всё, что официант добавляет через
«Меню» или сканер, хранится в локальной базе рядом с сидом.

## Сканирование меню

`OCRService` — детерминированный конвейер:

1. приведение снимка к 2048 px по длинной стороне;
2. поиск четырёхугольника документа (`VNDetectRectanglesRequest`) и перспективная коррекция;
3. grayscale, контраст 1.5, усиление резкости 0.5;
4. Vision `.accurate`, revision 3, языки ru/en/uk, словарь текущего меню в `customWords`;
5. склейка наблюдений в визуальные строки по геометрии;
6. разбор строк в блюда (`MenuParser`): цена только в конце строки, тысячи `1 290`/`1.290`,
   валюты `₽`/`руб.`/`р`, отсев заголовков и шума, склейка перенесённых названий.

`MenuParser` не требует камеры и покрыт юнит-тестами: обязательные кейсы
`Стейк Рибай 1290`, `Pasta Carbonara 450`, `Цезарь с курицей 590 руб.`,
`Chianti Classico 2019 1890`, `Борщ домашний 420` проходят, а `1290`, `450`,
`Горячие`, `Меню`, `Стр. 2` — отбрасываются. Распознанные строки можно
проверить и отредактировать на экране `ScanResultView` перед импортом.

## Структура

```
Bloknot/
  App/            BloknotApp, AppDependencies
  Models/         Category, MenuItem, DiningTable, Order, OrderItem, Enums
  Database/       DatabaseManager (миграции), SeedData
  Repositories/   Menu, Table, Order
  Services/       OCRService, MenuParser, HapticsService
  ViewModels/     Tables, Order, MenuEditor, Scanner
  Views/          Tables, Order, MenuEditor, Scanner, Components
  Utilities/      Theme, Constants, Formatters, PriceParser, View+Extensions
  BloknotTests/   парсер, цены, сид, счёт, репозитории, сквозной OCR
```

## Тесты

```bash
xcodebuild test \
  -project Bloknot.xcodeproj \
  -scheme Bloknot \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Покрыты: все 10 обязательных OCR-кейсов, форматы цен, точный состав сида,
переиспользование счёта, итоги и оплата, импорт блюд, сквозной путь
«изображение → Vision → парсер» на синтетическом меню.
