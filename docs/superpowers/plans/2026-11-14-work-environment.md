# Рабочая среда: план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** владелец и Claude работают в понятном проекте: правила в `CLAUDE.md`, инструменты в `tools/`, кнопки в `КНОПКИ/`, порядок в `docs/` и в git.

**Architecture:** маленький общий модуль `tools/devenv.py` (корень проекта, путь к Godot, проверка висящих процессов); поверх него три скрипта (`run_all_checks.py`, `visual_audit.py`, `build_trial.py`), к ним `.bat`-кнопки. Документы и git приводятся в порядок без удаления файлов.

**Tech Stack:** Python 3 (stdlib, Pillow уже стоит), Godot 4.7.2, Windows `.bat`.

**Spec:** `docs/superpowers/specs/2026-11-14-work-environment-design.md`

## Global Constraints

- Ничего не удалять с диска; только перенос и `.gitignore`.
- Код игры, версия, теги и выпуски не меняются.
- Наборы тестов запускаются строго по одному; перед стартом нет процессов Godot.
- Коммиты только по именам файлов (никогда `git add -A`), сообщение по-русски, последняя строка `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Тексты для владельца по-русски, коротко.
- `.bat` хранятся с CRLF (правило уже в `.gitattributes`).

## Review Focus

1. Нет `tools/local_settings.json` → понятная русская ошибка с примером содержимого, а не трассировка Python.
2. Godot уже запущен (висит прошлый прогон) → скрипт не стартует и говорит, какой процесс мешает.
3. Имя набора, которого нет в `ForestRail/tests/` → отказ до запуска (сейчас `run_checks.py` молча «проваливает» такое имя).
4. Путь проекта с кириллицей и пробелами («дрезина») → все скрипты и `.bat` работают (кодировка UTF-8 в консоли, кавычки).
5. Прогон прерван (Ctrl+C или закрыли окно) → дочерний Godot не остаётся висеть.

---

### Task 1: `tools/devenv.py` и настройки

**Files:** Create `tools/devenv.py`, `tools/local_settings.example.json`, `tools/test_devenv.py`; Modify `.gitignore` (+`tools/local_settings.json`); local only `tools/local_settings.json`.

**Interfaces (Produces):**
- `ROOT: Path` (корень репозитория)
- `godot_path() -> Path` (из `tools/local_settings.json` ключ `"godot"`; нет файла или exe → `SystemExit` с русским текстом и примером)
- `godot_running() -> list[str]` (PID и имена процессов `Godot*` через `tasklist`)
- `ensure_no_godot() -> None` (`SystemExit` с перечнем, если что-то висит)
- `list_suites() -> list[str]` (все `ForestRail/tests/check_*.gd` и `drive_campaign`, без `check_save_p8`, `check_soak_p8`, `check_perf`)

- [ ] Тесты `test_devenv.py` (unittest): `test_missing_settings_message` (временный каталог без файла → SystemExit, текст содержит «local_settings.json»), `test_list_suites_has_known` (`check_model` в списке, `check_save_p8` нет, нет `probe_*`).
- [ ] Запустить `python -m unittest tools/test_devenv.py`, убедиться, что падает.
- [ ] Реализовать, запустить снова: PASS.
- [ ] Коммит.

### Task 2: `tools/run_all_checks.py`

**Files:** Create `tools/run_all_checks.py`.
**Interfaces:** Consumes Task 1. CLI: `[--only a,b] [--skip a,b] [--report-dir DIR]` (по умолчанию `qa/last_run/`). Пишет `qa/last_run/summary.txt` (строка на набор: имя, ✅/❌, секунды) и печатает итог «84 из 84 зелёные» или список красных с путём к логу.

- [ ] Неизвестное имя в `--only` → отказ до запуска (Review Focus 3).
- [ ] Каждый набор через `run_checks.py --manual-run --suite <имя>`, по одному; при Ctrl+C убить дочерний процесс и все `Godot*`, которые он запустил (Review Focus 5).
- [ ] Проверка: `python tools/run_all_checks.py --only check_model,check_settings` → 2 из 2 зелёные; `--only check_hud` → отказ.
- [ ] Коммит.

### Task 3: `tools/visual_audit.py`

**Files:** Create `tools/visual_audit.py`.
**Interfaces:** Consumes Task 1. Запускает `--qa-suite=probe_visual_audit` в `qa/visual_audit_latest/`, потом `tools/visual_audit_sheet.py` для листов; печатает пути листов.

- [ ] Проверка: скрипт отрабатывает, в папке есть `depot_*.png` и листы.
- [ ] Коммит.

### Task 4: `tools/build_trial.py`

**Files:** Create `tools/build_trial.py`.
**Interfaces:** Consumes Task 1. Шаги «Ворот качества» без выпуска: чистая копия (`git worktree add` во временную папку), шаблон из `tools/templates/` на место, `--import` дважды, `--export-release "Windows Desktop"` в `release/trial/<версия из project.godot>/ForestRail.exe`, короткие наборы `--exported` (`check_model,check_presentation,check_art_v3`), поиск «No loader found»/«Failed loading» в логах, удаление worktree. Ни тега, ни установки, ни ярлыка.

- [ ] Нет шаблона → понятная ошибка с подсказкой `tools/fetch_windows_template.py`.
- [ ] Проверка: сборка проходит, exe есть, в логах нет «No loader found».
- [ ] Коммит.

### Task 5: кнопки `КНОПКИ/`

**Files:** Create `КНОПКИ/Проверить всё.bat`, `КНОПКИ/Собрать пробную версию.bat`, `КНОПКИ/Снимки для проверки глазами.bat`, `КНОПКИ/Открыть картинки GPT.bat`, `КНОПКИ/Открыть план.bat`.
Каждая: `chcp 65001`, `cd /d "%~dp0.."`, понятная строка «Что делаю», вызов скрипта, `pause` в конце с итогом (Review Focus 4).

- [ ] Проверка: каждая запускается двойным кликом из Проводника (проверяется запуском `cmd /c` из Bash).
- [ ] Коммит.

### Task 6: `CLAUDE.md`, `docs/RULES_RU.md`, `README_RU.md`, `README.md`

- `CLAUDE.md` (англ. заголовки, правила по-русски): структура, путь к Godot через `tools/local_settings.json`, команды из Tasks 2–4, правила (Global Constraints, выпуски только по слову, каждая 3-я версия на GitHub, старые установки не удаляются, картинки через GPT и `ART_QUEUE.md`, первое правило владельца про навыки и смену модели, один шаг = один коммит, визуальная проверка глазами).
- `docs/RULES_RU.md`: правила проекта, собранные из старых документов (по отчёту помощника), без противоречий.
- `README_RU.md`: коротко (что за игра, что сейчас, как запустить, кнопки, где план); старый текст в `docs/archive/README_RU_old.md`. `README.md`: 5 строк по-английски со ссылкой.
- [ ] Коммит.

### Task 7: порядок в `docs/` и git

- `docs/README_RU.md`: оглавление «что читать».
- Старые документы (по отчёту помощника, вердикт «архив») через `git mv` в `docs/archive/`; ссылки в актуальных документах поправить.
- Решения судьи из спеки: добавить в git входящие П13, П17, П18 (папка), П19, П20, концепты, отчёты приёмки, 28 `.uid`, `qa/perf_baseline.json`; `P18_ui_kit.zip` и старые папки `qa/` в `.gitignore`; `jet_train_*`, `rail_zeppelin_body/side*` перенести в `tools/art_sources/archive/unused_consists/`.
- [ ] Проверка: `git status --short` пуст; `check_art_v3` и `check_presentation` зелёные (картинки игры не задеты).
- [ ] Коммит(ы): документы отдельно, git-порядок отдельно.

### Task 8: потерянные идеи в план

- Раздел «Парковка» в `docs/PLAN_RAZRABOTKI_RU.md` и строка в `docs/PLAN_PROSTO_RU.md`: идеи из отчёта помощника, каждая со ссылкой на источник.
- [ ] Коммит, пуш.
