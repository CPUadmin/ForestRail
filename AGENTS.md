# AGENTS.md — карта проекта «Лесная колея» для нейросетей

Этот файл читают сами Codex, Cursor и другие помощники; Claude подключает его из `CLAUDE.md`. Цель одна: **не тратить время и токены на поиск.** Сначала смотри сюда, потом открывай только нужный файл и только нужную функцию (`grep "^func имя"`), а не весь файл целиком.

Правила работы с владельцем и с кодом — в `CLAUDE.md` (подробно `docs/RULES_RU.md`). Ниже короткая выжимка, карта и «где что искать».

## Проект в двух строках

2D-игра для Windows про лесную узкоколейку на **Godot 4.7.2, GDScript**. Девять машин (ручная дрезина, шестовая, парусная, паровоз, бензиновая, электровоз, пневмовоз, цеппелин, реактивный), заказы между станциями, износ и ремонт, казик с картами-гаджетами, кабины с настоящими органами. Владелец пишет по-русски и решает геймплей и вид; ты делаешь.

## Самое важное (нарушать нельзя)

- Рабочая ветка **`uzlovaya`**, в `main` не сливать без слова владельца. Коммит — только файлы по именам (**никогда `git add -A`**), один шаг = один маленький коммит, сообщение по-русски.
- **Тесты никогда не запускать параллельно** (у Godot общий замок): `python tools/run_all_checks.py --quick` (38 наборов, ~13 мин) или `--only a,b`.
- Выпуск, тег, GitHub, установка на ярлык — **только по слову владельца**. Старые версии в `%LOCALAPPDATA%\Programs\ForestRail` не удалять.
- Картинки **без сжатия с потерями**; рисованное не заменять плоскими прямоугольниками; эффекты (огонь, дым, искры, свет) рисует код; сложные картинки заказываются у GPT (`tools/art_sources/ART_QUEUE.md`).
- **Интерфейс придумывает владелец**: новых кнопок и окон не изобретать, делать по его рисунку.
- После зелёных тестов **смотреть снимки глазами** (`qa/last_run/…`): владелец находит то, чего тесты не видят.
- Отчёт владельцу: по-русски, коротко, сначала что видно в игре, потом что не проверено.

## Карта папок

```
дрезина/                      корень репозитория
├─ AGENTS.md, CLAUDE.md       этот файл и правила
├─ ForestRail/                проект Godot (открывать в Godot эту папку)
│  ├─ main.tscn               единственная сцена; её скрипт scripts/main.gd
│  ├─ project.godot           версия игры: config/version
│  ├─ scripts/                весь код игры (карта ниже)
│  ├─ data/game_data.json     ВСЕ числа игры: машины, вагоны, станции, заказы, цены ремонта, улучшения, гаджеты, износ
│  ├─ assets/                 картинки и звуки (папки art_* по темам, audio/, ui/)
│  ├─ tests/                  проверки (карта ниже)
│  └─ dev/                    стенды для ручной отладки дрезины
├─ docs/                      планы и решения (самое нужное ниже)
├─ tools/                     сборка, тесты, приёмка картинок (Python)
│  └─ art_sources/            задания GPT (briefs/), входящие картинки (inbox/), очередь ART_QUEUE.md
├─ qa/                        отчёты и снимки проверок (qa/last_run/ — последний прогон; почти всё не в git)
├─ release/                   собранные exe (не в git)
└─ КНОПКИ/                    .cmd-кнопки владельца (двойной клик)
```

## Код: `ForestRail/scripts/`

Устройство: `main.gd` — узел сцены (экраны, ввод, кадр). Крупные куски вынесены в **помощники** (`RefCounted`), которые получают `canvas` (это `main.gd`) и рисуют/читают через него; в `main.gd` от них остаются однострочные обёртки. `core/model.gd` — вся логика **без картинок** (её проверяют тесты без окна).

| Папка | Файл | Что внутри |
|---|---|---|
| — | `main.gd` | сцена: `_ready`, `_process`, `_input`, `_unhandled_input`, `rebuild()` (интерфейс заново), `_draw_scene`, доступ к помощникам (`steam_cab()`, `electric_cab()`, `depot_ui()`…) |
| `core/` | `model.gd` | состояние игры (`state`), физика (`physics_step`, `driving_force`), паровоз (`steam_step`), прогноз рейса (`trip_forecast`), заказы, депо (`back_to_depot`, `rescue`), сохранение (`serialize`, `restore`, `validate_save`), флаги правил для тестов (`wear_rules`, `contactor_rules`, `match_rules`) |
| | `route.gd` | линия: точки пути, уклоны, станции (`sample`, `slope`) |
| | `save_game.gd` | запись и чтение сохранений через временный файл, резервная копия, слоты |
| | `wear.gd` | износ узлов, цены ремонта по классу (`coins_per_pct`) |
| | `live.gd` | «живой» состав: сцепки, качание, груз |
| | `records.gd` | рекорды A→F→A |
| | `station_interaction.gd`, `world_geometry.gd` | действия на станции; размеры мира в метрах |
| `vehicles/handcar/` | `handcar_drive.gd`, `handcar_mechanism.gd` | ручная дрезина: сила качания и геометрия рычага |
| `vehicles/pole/` | `pole.gd`, `grapnel.gd` | шестовая и кошка с лебёдкой |
| `vehicles/sail/` | `wind.gd`, `oars.gd` | ветер над линией и вёсла |
| `vehicles/steam/` | `steam_cab.gd`, `matches.gd`, `match_view.gd` | кабина паровоза (топка, ведро, кнопки кабины, `cab_button`), спичка: модель и вид |
| `vehicles/motorcar/` | `ignition.gd` | ключ зажигания бензиновой |
| `vehicles/locomotive/` | `electric_cab.gd`, `contactor.gd`, `contactor_view.gd` | кабина «Подстанция» (рубильник, лампы, приборы), «Скрутка» и предохранители (модель), шкафчик (вид, провода-верёвки) |
| `vehicles/zeppelin/` | `zeppelin.gd`, `zeppelin_pult.gd` | цеппелин: физика и пульт |
| `vehicles/jet/` | `jet.gd`, `jet_pult.gd`, `jet_flame.gd` | реактивный: модель, пульт, пламя |
| | *(пневмовоз)* | своих файлов нет: всё в `core/model.gd` (`pneumatic_factor`, песочница `sand_left`) |
| `cabs/` | `cab_art.gd` | общая кабина: вид вперёд, нос машины, рама, доска, приборы (`draw_cab_scene`, `draw_cab_gauges`) |
| | `cab_side.gd` | боковые окна |
| | `controls_view.gd`, `control_art.gd` | рычаги на машине и в пульте: геометрия (`control_geometry`), рисование |
| | `instruments.gd` | приборы и мини-карта внизу экрана в пути |
| `ui/` | `depot_ui.gd` | депо: мастерская, гараж, магазин, рекорды |
| | `yard_ui.gd`, `place_walk.gd` | двор «Узловая Лесная»; переходы и затемнения между местами |
| | `hud_ui.gd`, `station_ui.gd`, `modal_ui.gd`, `menu_ui.gd`, `result_sheet.gd` | надписи в пути, станция, окна (карта, пауза), меню, лист результата |
| | `settings_io.gd` | настройки: чтение, проверка, запись, размер окна |
| | `ui_kit.gd` | цвета и вид кнопок «латунь по тёмному дереву» |
| `casino/` | `casino.gd`, `casino_view.gd`, `card_view.gd`, `card_reveal.gd`, `album_view.gd` | казик: правила, экран, карты Таро, альбом |
| `art/` | `art_v3.gd`, `art_world.gd`, `train_art.gd`, `fx.gd`, `screen_fx.gd` | машины и вагоны, мир и погода, поезд, дым и пар, мелкие экранные эффекты |
| `audio/` | `sound.gd` | все звуки |

## Где искать — частые задачи

| Нужно | Смотри |
|---|---|
| поменять число (скорость, цена, вместимость, износ) | `data/game_data.json`, а не код |
| как едет машина | `core/model.gd`: `physics_step`, `driving_force`, `grip_cap` |
| кабина конкретной машины | паровоз `vehicles/steam/steam_cab.gd`, электровоз `vehicles/locomotive/electric_cab.gd`, цеппелин и реактивный — их `*_pult.gd`, остальные — `cabs/cab_art.gd` |
| щелчок по кнопке кабины | `main.gd` → `cab_button(id)` → `vehicles/steam/steam_cab.gd: cab_button` |
| перетаскивание рычага | `main.gd`: `_input` (переменная `drag`), `finish_drag`; геометрия `cabs/controls_view.gd` |
| экран депо, двора, станции | `ui/depot_ui.gd`, `ui/yard_ui.gd`, `ui/station_ui.gd` |
| сохранения | `core/save_game.gd`, проверка формата `core/model.gd: validate_save` |
| картинка не грузится | путь в `preload(...)`, файл в `assets/`, после новой PNG — импорт (`godot --headless --path ForestRail --import`) |
| история решений по фиче | `docs/PLAN_RAZRABOTKI_RU.md` (по номеру шага, напр. «1.12»), `docs/CHANGELOG_RU.md` |

## Тесты: `ForestRail/tests/`

- **Набор** = `tests/check_X.gd` или группа `tests/check_X_all.gd` (наследует `group_runner.gd`, функция `parts()` перечисляет части из `tests/parts/`). Группа идёт в одном запуске Godot.
- **Пробник** = `tests/probe_X.gd`: снимки и замеры без галочек, запуск: `python tools/godot_lock.py -- <godot> --log-file <log> --path ForestRail -- --qa-suite=probe_X <папка>`.
- Запуск: `python tools/run_all_checks.py --quick` (все без медленных), `--only check_cab,check_steam_all`. Логи: `qa/last_run/source_<набор>.log`, снимки окон: `qa/last_run/<набор без check_>/`.
- Новый набор с окном (мышь, снимки) нужно вписать в `WINDOW_SUITES` и маркер в `tools/run_checks.py`.
- Медленные (`check_forecast_long`, `drive_campaign`, `check_perf_budget`, `check_presentation`) — только перед сборкой.
- `SCRIPT ERROR` в логе = скрипт не собрался, набор висит до таймаута: ищи его первым делом.
- Тесты, которые двигают настоящую мышь, иногда сбиваются, если в это время трогают курсор: перезапусти набор отдельно, прежде чем искать ошибку.

## Сборка и установка (только по слову владельца)

- `python tools/build_trial.py` — exe из последнего коммита в `release/trial/<версия>/` с проверкой.
- `tools/install_release.ps1 -Version <в> -SourceExecutable <exe> -ProfileDirectory $env:LOCALAPPDATA\Programs\ForestRail\Profiles\P8` — на ярлык.
- Путь к Godot: `tools/local_settings.json` (не в git).

## Документы, которые стоит знать

`docs/PLAN_RAZRABOTKI_RU.md` (главный план по шагам), `docs/PLAN_PO_VERSIYAM_RU.md` (коротко, у владельца на столе), `docs/CHANGELOG_RU.md`, `docs/RULES_RU.md`, `docs/README_RU.md` (что где в документах). Механики: `docs/ELECTRIC_CABINET_MECHANIC_RU.md` (шкафчик электровоза), `docs/KAZIK_*.md` (казик), `docs/JET_*.md`, `docs/ZEPPELIN_PROPOSAL_RU.md`.

## Как экономить

- Не читай `main.gd` (2,5 тыс. строк) и `core/model.gd` (3,2 тыс.) целиком: `grep -n "^func имя"` и читай 50–100 строк вокруг.
- Сначала эта карта, потом `grep` по имени функции или по русской строке из игры (надписи — в коде, числа — в `game_data.json`).
- Итог последнего прогона — в `qa/last_run/`, не перезапускай всё ради одного набора.
