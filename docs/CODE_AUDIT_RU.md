# Аудит кода «Лесная колея»: оптимизация и чистота

Дата: 2026-11-08. Версия проекта: 1.2.0-preview.98. Godot 4.7, GL Compatibility.
Как сделан: только чтение кода, `Grep`, `wc`, `du`, чтение .import и небольшие скрипты Python (читают картинки). Godot и тесты **не запускались**.

**Правило честности.** Всё про время и память здесь — оценка по коду, замер нужен. Точных миллисекунд в отчёте нет: я считал вызовы и объёмы, а время не мерил. Точные числа (строки, МБ, пиксели, размеры файлов) взяты из файлов.

---

## 0. Главное (читать только это, если мало времени)

| # | Находка | Выгода | Риск |
|---|---------|--------|------|
| 1 | Каждый кадр ~350 вызовов `world_point` (по 2 `route.sample` + пересчёт размеров окна/HUD в каждом). В депо ещё дороже (`view_scale()` каждый раз считает состав). | высокая | низкий |
| 2 | `art_world.update_view()` каждый кадр строит заново 5 мешей (`ArrayMesh`), ~200 `world_point`, и перерисовывает 6 слоёв. Статичные слои (дымка, тень, свет) тоже. | высокая | средний |
| 3 | `object_stats()` (словарь + перебор апгрейдов) вызывается десятки раз за тик физики и за кадр без кэша; `weather()` создаёт 4 объекта `RandomNumberGenerator` на каждый вызов. | высокая / средняя | средний / ~0 |
| 4 | Кабина (`cab_art.gd`): ≈1000 вызовов `Callable` + сотни `route.sample` за кадр, статичная рама перерисовывается каждый кадр. | высокая (только в кабине) | средний |
| 5 | Экспорт 236 МБ: 109 МБ — шаблон движка, 119 МБ — текстуры без сжатия (`compress/mode=0`). ~14 МБ из них лежат в exe мёртвым грузом (никто не ссылается). На старте грузится ≈134 картинок ≈ 340 МБ в видеопамяти (оценка). | средняя (размер/старт) | низкий |

**Первые 3 шага:**
1. Шаг 0: счётчики `Time.get_ticks_usec()` + набор `check_perf_budget` (без них любые «ускорения» — на веру).
2. Мелкая чистка с нулевым риском: удалить мёртвый код (`draw_world` и цепочка, пустые циклы `if false` в `art_world.gd`), исключить мёртвые картинки из экспорта.
3. Кэш кадра для `world_point` (размер, камера, масштаб, базовая линия считаются один раз за кадр) + кэш `weather_knot`.

---

## 1. Метрики

### 1.1 Код

Всего: `scripts/` 31 файл, **14 792** строки; `tests/` 12 211 строк (87 наборов `check_*`/`drive_*`); `dev/` 203 строки.

Топ-15 самых больших файлов `scripts/*.gd` («функций» = строки с `func`):

| Файл | Строк | Функций |
|------|------:|--------:|
| main.gd | 3994 | 203 |
| model.gd | 2820 | 243 |
| art_v3.gd | 1205 | 63 |
| cab_art.gd | 836 | 18 |
| instruments.gd | 526 | 36 |
| art_world.gd | 508 | 29 |
| casino.gd | 430 | 48 |
| casino_view.gd | 390 | 24 |
| jet.gd | 342 | 35 |
| jet_pult.gd | 289 | 27 |
| zeppelin.gd | 285 | 27 |
| sound.gd | 285 | 10 |
| grapnel.gd | 274 | 18 |
| zeppelin_pult.gd | 265 | 27 |
| wear.gd | 256 | 32 |

Самые длинные функции: `model.physics_step` 200 строк (model.gd:2314), `main._process` 185 (main.gd:2305), `_unhandled_input` 165, `_input` 152, `build_depot` 128, `build_modal` 113.

### 1.2 Размер assets (`du`, 713 файлов, 175 МБ)

| Папка | МБ | Папка | МБ |
|-------|---:|-------|---:|
| art_kazik (80 PNG, из них 22 карты 900×900 ≈ 36 МБ) | 50.8 | art_road | 1.9 |
| art_v3 | 36.8 | control_parts*.png (2 шт, в экспорт не входят) | 3.2 |
| art_consists | 16.0 | art_zeppelin | 1.5 |
| audio (53 WAV → QOA) | 12.0 | forest.png, track_cargo, station_details, vehicles (старые листы) | 5.2 |
| art_p2 | 11.9 | forest_background.png | 2.0 |
| art_cab | 7.0 | art_oars, art_pole_sail, art_pole_truck, ui | 2.9 |
| art_stations | 5.2 | art_electric | 2.1 |
| art_depot | 4.3 | art_p7 | 2.6 |
| art_jet / art_gadgets | 3.0 / 3.0 | branding (иконка) | 2.7 |

Всего PNG: 238 шт, 160 МБ на диске; в виде RGBA в памяти это было бы **532 МБ**, если загрузить всё сразу.

### 1.3 Самые тяжёлые картинки

Топ-20 по МБ (исходник PNG):

| МБ | Размер | Файл |
|---:|--------|------|
| 3.00 | 1254×1254 | art_v3/terrain/soil.png (не используется, см. 3.2) |
| 3.00 | 1254×1254 | art_v3/terrain/ballast.png (не используется) |
| 2.74 | 1536×1024 | art_cab/cab_dash_wood.png |
| 2.73 | 1536×1024 | art_kazik/interior.png |
| 2.64 | 1024×1536 | art_p2/sack.png |
| 2.60 | 1774×887 | art_p7/backwater_v1.png |
| 2.51 | 1536×1024 | art_cab/cab_dash_steel.png |
| 2.50 | 1254×1254 | branding/forest_rail_launcher_v1.png (иконка) |
| 2.48 | 1672×941 | art_v3/parallax/mid_forest.png |
| 2.10 | 1774×887 | art_consists/stock_motor_bodies.png |
| 2.05 | 1494×902 | art_stations/station_e.png |
| 1.99 | 1280×853 | art_kazik/facade.png |
| 1.99 | 1672×941 | forest_background.png (мёртвый, см. 3.2) |
| 1.89 | 1086×1448 | art_consists/electric_cab_panel.png (не используется) |
| 1.86 | 1267×1241 | art_v3/mechanism/axle_end.png |
| 1.82 | 1916×821 | art_v3/stations/depot.png |
| 1.74 | 1500×948 | art_cab/cab_window_frame.png |
| 1.74 | 1299×1211 | art_v3/vehicles/wheel_small.png (колесо диаметром ~0.5 м) |
| 1.71 | 900×900 | art_kazik/cards/world.png |
| 1.70 | 1487×879 | art_stations/station_f.png |

Топ по пикселям: **максимум 1.63 Мпикс** (2034×800 `sail_body.png`), следом 20 файлов по 1.55–1.60 Мпикс (`stock_*`, `rocket_train`, `rail_zeppelin_compact`, `backwater_v1`, пять слоёв parallax 1672×941, `wheel_small`, `rail_worker_side`, `support`, `battery_locomotive_body`, `petrol_motorcar_body`). Больших «монстров» нет; проблема в **количестве** крупных файлов (все грузятся на старте) и в том, что мелкие детали нарисованы огромными (колесо 1299×1211 px рисуется ~50–100 px).

### 1.4 Из чего состоит exe (236 МБ)

| Часть | МБ | Источник цифры |
|-------|---:|----------------|
| Шаблон движка `tools/templates/windows_release_x86_64.exe` | 109.3 | размер файла |
| Текстуры `.ctex` (270 шт, lossless) | 119.4 | `.godot/imported` |
| Звук `.sample` (56 шт, QOA) | 3.4 | `.godot/imported` |
| Скрипты, json, tests, dev | ≈3–4 | остаток (оценка) |

Сумма сходится с 236 МБ. Важные факты:
- `export_filter="all_resources"` (export_presets.cfg:8) кладёт в exe **все** картинки проекта, даже те, на которые нет ссылок.
- Все 267 текстур импортированы как `compress/mode=0` (lossless), `mipmaps/generate=false` (кроме 2), `process/size_limit=0`. Флаг `texture_format/s3tc=true` (export_presets.cfg:25) сейчас ничего не даёт: сжатых VRAM-текстур нет.
- Свежего exe на 236 МБ в папках нет (в `release/` 143 МБ от 28.10, в `qa/` новейший 157 МБ от 31.10), поэтому состав выше — сумма по `.godot/imported`, а не распаковка exe.

**Что можно сократить** (все цифры — оценка по коду, замер нужен):

| Мера | Выгода | Качество | Риск |
|------|--------|----------|------|
| Не класть мёртвые файлы в exe (см. 3.2): `exclude_filter` или удалить | ≈ −14 МБ ctex | не меняется | нулевой |
| Lossy (`compress/mode=1`, качество 0.8–0.9) для больших «живописных» фонов: parallax ×5, `backwater`, kazik `interior`/`facade`/`mikhalych*`, 22 карты | возможно −30…−50 МБ (на 3 файлах проверить!) | почти не виден на фонах, на картах глянуть глазами | низкий |
| Уменьшить переразмеренные детали: колёса 1300→512 px, шестерни/ось механизма, иконка 1254→256, `sack.png` 1024×1536 (в игре ~60 px) | −8…−15 МБ и −40 МБ видеопамяти | при 2× запасе не виден | низкий-средний (тесты геометрии) |
| VRAM-сжатие (S3TC/BPTC, `compress/mode=2`) для всего, кроме мелких «чётких» деталей | **не размер exe**, а видеопамять 4× меньше и быстрее старт | риск «грязи» на тонких линиях/альфе | средний |
| Свой урезанный шаблон Godot (без 3D, Vulkan, XR, лишних модулей) | −40…−60 МБ из 109 (оценка по опыту, не проверено) | нет | высокий (сборка движка) |

---

## 2. Горячие пути (каждый кадр / каждый тик)

Масштаб: игра рисует из `main._draw` (Node2D), плюс `art_world` (6 слоёв `PaintLayer`), `Instruments` (30 Гц), `CabSide`. `_process` вызывает `art_world.update_view()` и `queue_redraw()` **безусловно** (main.gd:2481–2482).

Условные обозначения: выгода В/С/Н = высокая/средняя/низкая; риск Н/С/В.

### 2.1 Таблица находок

| ID | Где | Что происходит | Почему дорого | Как исправить | Выгода | Риск |
|----|-----|----------------|---------------|---------------|:------:|:----:|
| H1 | main.gd:2947 `world_point`, :3068 `dock_rect`, :3073 `rail_baseline`, :3081 `view_scale` | В **каждом** вызове: `get_viewport_rect()` ×2–3, `route.sample(s)` и `route.sample(camera_s)` (камера одна и та же весь кадр), `rail_baseline()` → `dock_rect()` → `instruments.hud_top()`. В депо `view_scale()` ещё считает `depot_span_m()` (цикл по вагонам) и литерал словаря `tall_cap` | Прикидка вызовов за кадр на маршруте: update_view ≈194, `draw_foreground` art_world ≈40 (пустые!), поезд из 3 тел ≈40, станции/декор ≈40, трава ≈15 → **≈350 `world_point` ≈ 700 `route.sample`** (подсчёт по коду, не замер) | Один раз за кадр собрать `FrameCtx` (size, cam_xy, head_x, k=PX·scale, baseline) в `_process`; `world_point` берёт только готовое. `view_scale` в депо кэшировать при `rebuild()`/смене состава | В | Н |
| H2 | main.gd:3384 `draw_train`, :3526 `body_transform`, :3563 `draw_body` | Для каждого тела `body_transform` считается 3 раза (в `draw_train`, и 2 раза в `draw_body`: `outer` и `rail`), плюс 2 раза на каждую сцепку; каждый раз `art.wheel_positions(id)` (создаёт массив, много словарных поисков), 2 `world_point`, `model.body_ids().find(id)`, `live.lift_m` | ~30 `body_transform` ≈ 60 `world_point` на состав из 3–4 тел | Посчитать один раз на тело за кадр (`outer`, `rail`, `bounds`), передать в `draw_body`/сцепки/`add_world_hits`. `wheel_positions`/`body_bounds` кэшировать по id (сбрасывать при загрузке скина) | С | Н-С |
| H3 | art_world.gd:222–271 `update_view`; :202 `mesh_strip` | Каждый кадр: 3 параллакс-полосы и 2 полосы дороги — **5 новых `ArrayMesh`** (аллокация RID в RenderingServer ×60/с); 2 цикла по 97 точек (`world_point`, массивы `Array` из `Vector2`); литералы словарей `{"far_hills":0.25,…}[name]` ×2 на каждую полосу (:237–238); `queue_redraw()` на 6 слоёв | Аллокации + ≈194 `world_point` + пересборка вершин | (а) параллакс — это прямоугольник, меняется только `u`: строить меш при смене размера/`rail_y`, каждый кадр менять только uniform шейдера; (б) дорога: один раз на маршрут строить статичный меш в координатах трассы и двигать узел (положение/масштаб), т.к. всё ∝ `PX·scale`; (в) словари → `const`. Минимум: переиспользовать один `ArrayMesh` | В | С |
| H4 | art_world.gd:499–507 `draw_foreground` | Два цикла с `if false:` внутри; в первом всё равно вычисляется `world_point(i*tile_m)` (≈40 раз за кадр) и ничего не рисуется | Чистый расход | Удалить мёртвые циклы | Н-С | Нет |
| H5 | art_world.gd:107 `glow` (40 `draw_polygon` + 2 новых Packed-массива каждый), :114 `draw_haze`, :125 `draw_ground_shade`, :194 `draw_light`, :174 `draw_weather` (110 `draw_line` в дождь) | Слои `haze`, `ground_shade`, `light` перерисовываются каждый кадр, хотя зависят только от размера окна, `rail_y`, ночи и погоды | Лишние сотни команд рисования | `queue_redraw()` для них только при смене (размер, rail_y, «ведро» ночи/погоды); капли дождя — отдельный слой | С | Н |
| H6 | station_interaction.gd:23 `evaluate`; вызовы: main.gd:1711, 2840, 2956, 3043, 3872, 3904; art_world.gd:378, 391 (на каждую станцию); model.gd:174 (каждый тик), 215, 568, 837, 2669 | `evaluate` перебирает станции и весь груз, форматирует строки `reason`, вызывает `station_name`, `train_bounds` (Geometry-поиски). За кадр ≈6–8 раз + 1 раз на тик физики | Результат за кадр одинаковый | Кэш по (номер тика физики, номер кадра) в модели; `station_state()` в main — только накладка `drag` поверх копии | С | Н-С |
| H7 | model.gd:261 `object_stats`, :290 `apply_wear`, :338 `train_mass`, :344 `body_mass`, :325 `body_ids`, :354 `body_offset`; physics_step :2332–2346 | Тик физики (60 Гц): `train_mass()` = n·(`object_stats` + перебор груза с `begins_with(id+":")`), потом в цикле снова `body_mass` + `route.slope` (2 sample) + `object_stats`, затем `object_stats(vehicle_id())`; внутри `object_stats` — `effects()` перебирает **весь** `upgrade_catalog`, а при `wear_rules` ещё 5 вызовов `wear().factor`. `body_ids()` и `body_offset()` (O(n), новый массив) вызываются повсюду. То же в `live.gd:97 step` (ещё раз `body_mass`, slope, 4 sample на тело) и в `cargo_layout` (main.gd:3632, дважды за кадр на тело) | Десятки словарей/массивов на тик и кадр | Кэш `object_stats(id)` с версией (`stats_version++` при апгрейде, износе, смене состава/маршрута); снимок поезда за тик (`ids`, массы, смещения) общий для physics и live | В | С (устаревшие числа ломают калибровку; тесты `check_physics`, `check_model` ловят) |
| H8 | model.gd:1262 `weather_knot` | `RandomNumberGenerator.new()` на **каждый** вызов; `weather_at` вызывает 4 раза, а `weather()` — из `rain_effect`, `fog_effect`, `cold`, `grip_factor`, `weather_name`, `shown_weather`, `lights_lit`, `sight_m`, звука (≈18 мест) | ≈50 новых объектов за кадр + тики | Словарь-кэш узлов `(channel,index)->float` (значения те же, сохранения не ломаются); кэш `weather()` на тик | С | ~0 |
| H9 | cab_art.gd:91–250 `draw_cab_forward`, :59 `draw_cab_ground` | `project` — замыкание `Callable` с словарём `elevations` по ключу `z` (float): в каждом кадре шпалы/деревья имеют новые `z`, значит новый `route.sample` на каждую. `draw_cab_ground` ≈150 полигонов × 4 `project.call`; 60 пятен щебня; ≈130 шпал ×2 линии; рельсы; столбы; деревья | ≈1000 вызовов `Callable` (≈155 полигонов земли × 4 + полотно, щебень, ≈130 шпал и др.) и ≈300 `route.sample` за кадр (подсчёт по коду) | Таблица высот шагом 1 м за один проход (≈170 sample) + линейная интерполяция; `project` заменить статической функцией/инлайн-формулой; фиксированный набор `z` для шпал | В (только в кабине) | С |
| H10 | cab_art.gd:342–428 `draw_cab_frame`, :454 `draw_dash_panel_v2`, :801 `draw_cab_gauges` | Статичная рама кабины (доски крыши, болты, шторки, 26 пылинок, 120 «царапин» панели, 70 потёртостей) рисуется заново каждый кадр | Сотни команд на кадр на статике | Один раз отрендерить статику в текстуру (по размеру окна и типу машины) или в отдельный узел, перерисовывать при ресайзе; стрелки/лампы — поверх | С-В (в кабине) | С |
| H11 | instruments.gd:126–144 `draw_profile`, :75 `ensure_profile`, :114 `stretch_range`, :147 `climb_ahead`; cab_art.gd:53 | HUD 30 Гц: 100 вызовов `draw_polygon` (по 2 новых Packed-массива), на каждой точке `ensure_profile()` строит массив-ключ, `stretch_range` 61 sample, `climb_ahead` до ≈170 sample; в кабине `climb_ahead` ещё и каждый кадр | Профиль меняется только когда поезд сдвинулся | Кэш по `round(here/2)` и ключу маршрута; `ensure_profile` сравнивать по двум числам без массива; фон-заливку одним `draw_polygon` с цветами вершин | С | Н |
| H12 | main.gd:571 `style` | Ключ кэша — строка `"%s|%s|%d" % [bg.to_html(), border.to_html(), radius]` на каждый вызов (≈25 вызовов за кадр + `Instruments.bar`) | Форматирование строк в кадре | Кэшировать в константах/полях статичные стили; для динамических ключ-кортеж без строк. (Утечки нет: цвет `glow` квантован main.gd:1986) | Н | Н |
| H13 | jet_pult.gd:135 и zeppelin_pult.gd:104 `box()`; art_v3.gd:440 | `StyleBoxFlat.new()` на каждый вызов (8–10 за кадр на пульт); для скинов электровоза ещё 2 на кадр | Мусор для GC | `draw_rect` + рамка или кэш по ключу; общий код вынести (см. 3.3) | Н | Н |
| H14 | sound.gd:134–135 | `set_cutoff()` дважды за кадр: `AudioServer.get_bus_index(name)` + `get_bus_effect` + запись `cutoff_hz` даже когда `cab_mix` не меняется | Блокировки аудио-сервера | Писать только при изменении `cab_mix` | Н | Н |
| H15 | main.gd:2305–2482 `_process` | `queue_redraw()` и `update_view()` каждый кадр, в том числе на паузе, в модальных окнах, в депо без анимации | На слабом ноутбуке постоянные 60 FPS полной перерисовки без движения | Пропускать перерисовку мира, когда `paused` и нет анимации/ввода (меню остаётся живым, там едет дрезина) | С (батарея, нагрев) | Н |
| H16 | model.gd:486 `casino()` | Новый `Casino` на каждый вызов (draw_glints каждый кадр, `update_cargo_actions` каждые 80 мс, `trip_tick` каждый тик) | Мелкая аллокация | Хранить один экземпляр (как `wear()`) | Н | Н |
| H17 | art_v3.gd:342 `wheel_positions`, :335 `body_bounds`, :323 `scale_for`, :326 `pivot` | Вызываются многократно за кадр; каждый раз новые массивы/`Vector2`, словарные поиски, `Geometry.body(id)` (строка `begins_with`) | См. H2 | Кэш по id | Н-С | Н |
| H18 | main.gd:3796–3797 `draw_controls` | Два литерала `Dictionary` на каждый рычаг на каждый кадр (`color`, `factor`), третий — `label`, но только при подсветке | 10 аллокаций за кадр | `const` | Н | Н |
| H19 | main.gd:204 `Input.use_accumulated_input=false`, ~2640–2660 | Мышь 1000 Гц ≈16 событий за кадр; на каждое в режиме перетаскивания `body_transform` (4 sample) и `control_geometry` | Лишняя работа при drag | Считать по последнему движению за кадр или кэшировать transform на кадр (после H1/H2 станет дёшево) | Н-С | Н |
| H20 | assets/art_v3/materials/periodic.gdshader:25–32 | Шейдер параллакса делает **4 выборки текстуры** на пиксель (`sample_region` ×4 + `textureSize`) на 3 полосах шириной в экран (≈ 1.0 экрана по площади) | Нагрузка на встроенную видеокарту | Один раз сделать «бесшовную» текстуру офлайн (tools/), в шейдере 1 выборка | С (iGPU, оценка) | Н |
| H21 | route.gd:11,195–200,208 `points` | Трасса — `Array` из `[x,y,dist]` (6.8 км ≈ 7000 массивов); `sample` — бинарный поиск с `float()`-приведениями; `knoll_y` перебирает кочки на каждый вызов | Основа всех 700+ sample за кадр | После H1 вызовов станет мало; позже — три `PackedFloat32Array` + `bsearch` (формат сохранения оставить прежним) | С | С (сейв/тесты трассы) |
| H22 | art_v3.gd:808–985, art_world.gd:290,468 | Физика ткани паруса и вымпелов считается **внутри `_draw`** по настенным часам `Time.get_ticks_msec()` | Не только скорость: зависит от FPS и делает скриншоты тестов недетерминированными | Шаг ткани в `_process` по `dt`; единые «игровые часы» для анимаций | Н (чистота/тесты) | С |
| H23 | jet_flame.gd | Пламя: 4 слоя × 19 точек × 2 стороны, ≈600 `sin()` за кадр при тяге | Только реактивный | Не трогать, пока не покажет замер | Н | — |

### 2.2 Что проверено и оказалось нормальным
- `find_children`, `get_node`, `$Node`: в `scripts/` **нет** ни одного (проверено Grep).
- `preload`/`load` внутри функций `model.gd:355,358` — `preload` вычисляется при разборе скрипта, на кадр не влияет (только стиль: у `Model` нет своей `const Geometry`).
- `load()` внутри игровых функций: `card_view.gd:70–75`, `card_reveal.gd:35`, `casino_view.gd:80–82` — берут из кэша ресурсов; казик грузится **лениво** (при открытии), это хорошо.
- JSON: `Geometry.data()`, `HandcarDrive.shared_config` кэшируются в `static var`; `Model._init` парсит `game_data.json` (50 КБ) при каждом `Model.new()` (в игре 2 раза, тесты — часто), это мелочь.
- `duplicate(true)`: только в загрузке/сохранении, `mission`, `settings` (не в кадре). `card()` (main.gd:638) делает `duplicate()` стиля при построении UI.
- Утечка `styles`: нет, ключи ограничены (цвет `glow` округлён в main.gd:1986).
- Звук: **в движке ничего не синтезируется** (в запросе предполагалось иначе). Звуки делает офлайн `tools/audio_sources/make_audio.py`, в игре `sound.gd` только грузит 37 клипов + 16 петель (QOA 3.4 МБ). Время «генерации» на старте — ноль.

---

## 3. Дублирование и мёртвый код

### 3.1 Функции и константы без вызовов (проверено Grep по `scripts/`, `tests/`, `dev/`, по имени)

| Что | Где | Статус |
|-----|-----|--------|
| `draw_world` (73 строки) | main.gd:3260 | нигде не вызывается. `ellipse` и `grounded_sprite` из него **живые** (их зовут `draw_body`, `draw_foreground` и др.), а `terrain_band` нужен только ему |
| `draw_background` | main.gd:3231 | вызывается только при `art_world == null` (main.gd:3094), а `art_world` всегда создаётся в `_ready`: мёртв |
| `draw_foreground` (main) | main.gd:3335 | нигде не вызывается (живая — в `art_world.gd:492`) |
| `terrain_band` | main.gd:3254 | только из `draw_world` |
| `draw_map` | main.gd:3855 | нигде (карта — `instruments.gd`) |
| `mission_description` | main.gd:1508 | нигде |
| `control_zoom_transform` | main.gd:2091 | нигде |
| `hand_grip`, `draw_worker` | art_v3.gd:396, 700 | нигде |
| `sector_weights` | casino.gd:163 | нигде |
| `g_load` | jet.gd:289 | нигде |
| константы/поля: `SECTOR_TEXT` (casino_view.gd:27), `tooltip` (main.gd:185), `KEYS` (records.gd:11), `VERSION` (route.gd:6), `BRAKE` (station_interaction.gd:6) | | нигде не читаются |
| Только тесты зовут: `art_v3.slot_position`, `live.extension`, `jet.validate_modes`, `main.wheel_rotation`, `model.mission_count`, `model.brake_safe`, `instruments.permanent_panel_height`, `handcar_mechanism.advance` | | оставить (тест-контракты) или перенести в тесты |

Итого можно удалить ≈ **130 строк** в main.gd (3231–3345 без `ellipse`/`grounded_sprite`, 3855–3870 и ещё несколько) + ≈ 30 в других файлах. Данные, которые после этого тоже мертвы: спрайты `soil_segment`, `loading_crane`, `station_hut`, а также `textures.background` (`forest_background.png`, 2 МБ), загрузка в `load_textures()` (main.gd:312). Проверить перед удалением: `visual_layout.json` держит ключи этих спрайтов; `fuel_pump`, `log_pile`, `rocks`, `final_flags` **живые** (используются в `art_world.gd`).

### 3.2 Картинки без ссылок (Grep по `scripts`, `tests`, `data`, `*.json`, `*.tres`)

| Файлы | МБ (ctex) | Заметка |
|-------|----------:|---------|
| art_consists/{electric_cab_panel, jet_train_body, jet_train_side, rail_zeppelin_body, rail_zeppelin_side}.png | 5.4 | живые рядом: `*_compact_body` |
| art_v3/terrain/{ballast, grass, rail, sleeper, soil}.png | 5.6 | грузятся на старте через `manifest.json` (art_v3.gd:168), но по имени `terrain/…` их никто не берёт (дорогу рисуют `art_road/*`). Убрать из manifest + .tres |
| art_v3/verification/{mechanism_native, terrain_native}.png | 1.2 | отчётные кадры |
| art_v3/vehicles/{handcar_body, freight_wagon_body, petrol_motorcar_body, battery_locomotive_body}.png | ≈3.9 (диск) | грузятся в `art_v3.gd:168` и сразу заменяются атласами из `art_p2` (:185–189); остаются нужны только их записи-метаданные в manifest |
| art_v3/vehicles/{steam_wheel, petrol_wheel}.png | 0.2 (диск) | грузятся, но `draw_wheels` берёт только `wheel_large`/`wheel_small` (art_v3.gd:556) |
| forest_background.png | 1.5 | после удаления `draw_background` |
| art_jet/{flame_after, flame_full, flame_idle, flame_mid, heat_ring, chute_pack, panel_cap_open}.png | 0.45 | пламя теперь рисует `jet_flame.gd` (комментарий там же) |
| art_jet/{flash, sparks, chute_cut}.png, art_gadgets/{jet_afterburner, sail_spinnaker}.png | ≈0.7 (диск) | нашлись только как слова в событиях/идентификаторах, как файлы не грузятся. Проверить ещё раз в игре |
| art_kazik/rare_1..9.png | 0.2 | `junk_%d` грузится, `rare_%d` нет |
| control_parts.png, control_parts_clean.png | 2.3 | уже исключены из экспорта (export_presets.cfg:10), но лежат в проекте |
| art_p2/*_body.png (9 шт, ≈8 МБ) | — | **не мёртвые**: из них берутся картинки машин в списках гаража (main.gd:1794, 1813) и скины. Но грузить 2000×750 ради иконки ~120 px расточительно: сделать готовые миниатюры |

Сумма «точно мёртвых» в exe: **≈14 МБ**. Способ без риска: добавить в `exclude_filter`, потом удалить из репозитория.

Старые листы `vehicles.png`, `forest.png`, `track_cargo.png`, `station_details.png` (по 1.1–1.5 МБ, 1254×1254) грузятся целиком, а используются небольшие куски (деревья, груз, `log_pile`, `fuel_pump`, `final_flags`). Вырезать нужные регионы в один маленький атлас — экономия RAM ≈ 20 МБ (оценка).

### 3.3 Дублирование кода

| Что | Где | Что делать |
|-----|-----|------------|
| `box()` и `text()` идентичны (18 строк) | jet_pult.gd:135, zeppelin_pult.gd:104 | общий `pult_base.gd` |
| Сборка `StyleBoxFlat` | casino_view.gd:38,52; art_v3.gd:440; jet/zeppelin `box` | один помощник со словарём-кэшем |
| Ручные прямоугольные градиенты `PackedVector2Array([...4 угла...])` | cab_art.gd:123,124,249,349,457 и др. (≈25 мест) | уже есть `ArtWorld.vertical_gradient`/`horizontal_gradient` |
| Круг/эллипс как многоугольник из 24 точек с `cos/sin` на каждый вызов | main.gd:3242 `ellipse` (≈30 раз за кадр), art_world.gd:107 `glow` (40) | заранее посчитанный единичный круг |
| Словарные литералы в кадре | art_world.gd:237–238; main.gd:3089 `tall_cap`, 3796–3797; cab_art.gd:434 | `const` |
| «Временные» куски | `if false:` art_world.gd:505,507; тестовые флаги в игровом коде `animate_in_tests`, `live_in_tests`, `junk_in_tests` (main.gd:93,189,190); `HIDDEN_VEHICLE_IDS = []` (model.gd:22) | вынести/убрать |

---

## 4. Архитектура

### 4.1 main.gd (3994 строк) и что ещё вынести

Уже вынесено: `cab_art.gd` (кабина), `control_art.gd` (рычаги), `cab_side.gd`, `zeppelin_pult.gd`, `jet_pult.gd`, `casino_view.gd`, `album_view.gd`, `card_*`. Остаётся в `main.gd`:

| Блок | Строки (прибл.) | Куда | Размер шага |
|------|-----------------|------|-------------|
| Настройки (`load/apply/build_settings`) | 326–548 (≈220) | `settings_view.gd` | С |
| Депо: вкладки, апгрейды, ремонт, приёмка | 811–1440 (≈630) | `depot_view.gd` (+ по вкладкам) | К |
| HUD: `build_hud`, `update_hud`, подсказки | 1570–1760 (≈190) | `hud.gd` | С |
| Паровой пульт и реквизит кабины | 1917–2016 (≈100) | `steam_pult.gd` (как цеппелин/реактивный) | М |
| Кнопки кабины, `draw_control_zoom` | 2019–2145 | в `control_art.gd`/`cab_art.gd` | М |
| Модалки | 2146–2290 (≈145) | `modal_view.gd` | М |
| Ввод `_input`/`_unhandled_input` | 2557–2915 (≈360) | `input_router.gd` | К |
| Поезд: `draw_train/body`, парковка, сцепка | 3384–3660 (≈280) | `train_view.gd` | С |
| Платформа/док/груз | 2958–3066, 3871–3930 | `station_view.gd` (Т7: «станция») | С |
| Мёртвое | см. 3.1 | удалить | М |

Размеры: М = мелкий, С = средний, К = крупный. Для Т7: пульты цеппелина и реактивного уже вынесены; в `main.gd` остался клей (`draw_zeppelin_pult`, `zpult_world_*`, `has_own_pult`, 2065–2090, и ввод). Казик: вынесен, в main только `build_casino_tab` (939–965) и открытие модалки.

### 4.2 model.gd

Хорошо: модель **чистая**, без `get_tree`/`Input`/`DisplayServer` (проверено Grep), поэтому её легко тестировать и кэшировать. Но `model.gd` 2820 строк содержит всё: экономику, заказы, паровой котёл, пневматику, реактивный, цеппелин, парус, погоду, шест. Кандидаты на вынос в отдельные `RefCounted` по образцу `jet.gd`/`zeppelin.gd`: `weather.gd` (1238–1330), `boiler.gd` (1650–1800), `pneumatic.gd` (1461–1580), `missions.gd` (620–830). Функция `physics_step` (200 строк) делится на «собрать силы» / «интегрировать» / «расход».

### 4.3 Циклы и глобальное состояние

| Что | Где | Проблема | Решение |
|-----|-----|----------|---------|
| `static var` ×5: `legacy_tanks`, `order_rules`, `live_effects`, `wear_rules`, `junk_rules` | model.gd:90–99 | Глобальные флаги; `main._process` переписывает 4 из них **каждый кадр** (main.gd:2321–2324); их делят `model` и `menu_preview`; в тестах их ≈50 упоминаний | `model.rules` (поле экземпляра), выставлять один раз |
| Цикл ссылок `Model → _wear → m → Model` | model.gd:490, wear.gd:15 | `RefCounted` с циклом не освобождается (утечка при каждом новом `Model` с износом) | `WeakRef` или явная очистка. В игре моделей две, поэтому на практике мелочь |
| `casino()` создаёт объект на каждый вызов | model.gd:486 | см. H16 | кэш |
| Обратные ссылки на `main` | `art_world.game`, `CabArt.canvas`, `ControlArt.canvas`, `Instruments.game`, `CabSide.game` | Дети знают всё о `main`: `cab_art.gd` ≈370 обращений `canvas.…`/`game.…`, `art_world.gd` ≈108, `instruments.gd` ≈33 | Передавать узкий «контекст кадра» (`FrameCtx` из H1) и модель, а не весь `main` |
| UI знает слишком много о модели | `model.state.…` напрямую: main.gd 132 раза, art_v3 24, cab_art 28 | `state` — один большой словарь без типов; любое поле меняет формат сейва и UI | Тонкий фасад для UI (`model.view()` — снимок на тик; он же место для кэша H6/H7) |
| Статичные кэши JSON | `Geometry.catalogue`, `HandcarDrive.shared_config`, `HandcarMechanism.shared_*` | Безопасно (иммутабельные), но тесты, меняющие данные, видят чужие значения | Оставить; пометить как «только чтение» |

---

## 5. Загрузка и запуск

Оценка по коду (старт не запускался).

**Что грузится на старте** (даже в режиме `--qa-suite`: константы `preload` исполняются при разборе скрипта до `_ready`):
1. `main.gd` разбирает `preload` десятка скриптов и 5 картинок (кабина дерево/сталь/рама ≈ 18 МБ в RGBA, электрика).
2. `art_v3.gd`: ≈60 `preload` (рабочий, шест, парус, гребцы, станки гаджетов, `stock_*`, зеппелин, реактивный) + в `_init` цикл `load()` для **всех 31** записей manifest (art_v3.gd:167–168), потом 10 атласов тел из `art_p2` (:171–190; четыре PNG из art_v3/vehicles загружаются зря и тут же заменяются).
3. `art_world.gd`: дорожные тайлы, 9 trackside, станции, `backwater_v1` (2.6 МБ), 3 параллакс-полосы с шейдером `periodic`.
4. `load_textures()` (main.gd:298): 4 старых листа + `forest_background` (мёртвый) + 8 SVG + `sack`/`log_bundle`.
5. `sound.gd`: 37 клипов и 16 петель, всё из QOA.
6. `Model.new()` ×2 (JSON 50 КБ), генерация трассы.

Итого ≈ **134 картинки ≈ 340 МБ в RGBA** (расчёт скриптом по размерам; видеопамять + оперативка), и **декодирование ≈ 120 МБ lossless-текстур** перед первым кадром. Время — **замер нужен**; оценка: заметные секунды на слабом ноутбуке.

**Что можно отложить:**

| Что | Сколько | Как | Риск |
|-----|--------:|-----|------|
| Мёртвые (terrain ×5, forest_background, 4 PNG тел, 2 колеса) | ≈ 40 МБ RGBA (оценка) | удалить из manifest/load | Н |
| Предметы машин, которых нет в гараже/на маршруте (парус, шест, гребцы, зеппелин, реактивный, гаджеты) | ≈ 60–100 МБ RGBA (оценка) | `load()` по требованию при выборе машины, а не `preload` в const; кэш ресурсов Godot сам удержит | С |
| Кабина (3 текстуры, 18 МБ) | 18 МБ | при первом входе в кабину | Н |
| Миниатюры гаража вместо 2000×750 `art_p2/*_body` | ≈ 25 МБ | готовые 256 px | Н |
| Крупные листы-атласы старых артов | ≈ 20 МБ | вырезать нужные регионы | С |
| Меню: показывает только дрезину и параллакс | — | первым кадром показать меню, остальное догрузить в фоне (`ResourceLoader.load_threaded_request`) | С |
| Казик, карты (22×900²), альбом | уже ленивы | альбом открывает сразу 22 карты 900×900 ≈ 70 МБ RGBA: уменьшить до 512 | Н |

**Память:** потолок если открыть всё: 532 МБ RGBA (PNG) + карты. Для целевого ноутбука с общей памятью (iGPU) это существенно: цель «до ~250 МБ текстур на старте» достижима отложенной загрузкой + мёртвыми + миниатюрами (оценка, замер: `Performance.RENDER_TEXTURE_MEM_USED`).

---

## 6. Тесты

Известно: 84 набора ≈ 40 минут; `check_layout_p7` ≈ 36 с, `check_cab` ≈ 27, `check_handcar_drive` ≈ 23, `check_soak_p8`. В старых `qa/*checks.json` есть и другие цифры (могут быть устаревшими): `drive_campaign` 61 с, `check_station_service` 36 с, `check_handcar_input` 15 с, `check_mechanism` 14 с, `check_live_view` 14 с, `check_world_geometry` 13 с.

### 6.1 Что тормозит (по `tools/run_checks.py` и `tests/*.gd`)

| Причина | Где | Комментарий |
|---------|-----|-------------|
| **Soak 1200 с по умолчанию** | run_checks.py:15; тайм-аут `soak+120` (:109) | Если `check_soak_p8` входит в 84 набора, это ≈ **половина** прогона. На обычный прогон хватит 120–300 с, 1200 только перед релизом |
| 38 наборов идут **не в headless** (список run_checks.py:28), с настоящим окном; среди них и `check_soak_p8` | | Окно, загрузка ≈340 МБ текстур в GPU на каждый процесс, vsync |
| **vsync включён в тестах**: `settings.vsync=true` по умолчанию (main.gd:73,383); `frame()` в тестах ждёт `process_frame` + `frame_post_draw` (оценка: 1–2 интервала экрана на «кадр») | tests/check_layout_p7.gd:19–23 и др. | Выключить vsync и `Engine.max_fps=0` в `test_mode` — ускорит все видовые наборы |
| Скриншоты PNG (`get_image().save_png`) почти в каждом кейсе | check_layout_p7: 3 разрешения × 3 масштаба × 3 машины + «станции» + ... ≈ 45 PNG | Флаг `--no-shots` для прогонов «только проверки» |
| Ожидания по таймеру | `create_timer(0.15)` (check_layout_p7), `create_timer(0.2)` (check_cab:93) после смены размера окна | Заменить на ожидание `size_changed` + 2 кадра: быстрее и без гонок |
| Клики через `push_input` с ожиданием 2 кадров на каждое нажатие и отпускание | check_layout_p7 `click()`, check_cab `mouse/key` | Для логических проверок вызывать обработчик напрямую; `push_input` оставить в паре «дымовых» кейсов |
| Каждый процесс разбирает `main.gd` → `ArtV3` → ≈134 PNG, даже для `check_model` | | Лечится ленивой загрузкой (раздел 5); для headless влияние малое (check_model ≈1 с по старым данным) |
| Раннер строго последовательный, лишь `exit_code`+`seconds` в json | run_checks.py:96–128 | Нет параллели, нет сортировки по времени, нет повторов |
| `drive_campaign` (тайм-аут 400 с), `drive_long`/`check_forecast_long` (1500 с) | :108 | В быстрый пакет не включать |

### 6.2 Нестабильные места
- Окна/фокус: прогон «портится» параллельными запусками (клики по экранным координатам, `get_global_mouse_position`, смена размера окна).
- Координаты клика берутся из `cab_hits`/`grip_hits`, заполненных последним `_draw`: если кадр не дорисован — клик мимо. Помогает один явный `await frame()` после смены состояния (уже делается) и отказ от таймеров.
- Анимации по настенным часам (`Time.get_ticks_msec` в ткани паруса, пламени, вымпелах) и `Engine.get_physics_interpolation_fraction()` в `render_s()` делают кадры недетерминированными (на проверки это не влияет, на сравнение скриншотов — да).
- Общая папка `user://qa_model` у `check_model`, `check_physics`, `check_art_v3`, `check_handcar_revision`: при параллельном запуске могут мешать друг другу.

### 6.3 Как ускорить и стабилизировать
1. `--soak-duration=300` по умолчанию в быстром пакете; 1200 — только в «релизном».
2. В `test_mode`: `settings.vsync=false`, `Engine.max_fps=0` (или флаги движка `--disable-vsync`/`--fixed-fps`: **проверить** `godot --help` для 4.7, я не запускал).
3. Раннер: пул из N процессов для **headless**-наборов (сначала развести 4 набора с `qa_model`), видовые — по одному; вывод «топ-10 самых медленных»; один автоматический повтор упавшего видового набора с пометкой `FLAKY` (не скрывая падения).
4. `--quick` для `check_layout_p7` (только 1600×900, без PNG) и `--no-shots`.
5. Ожидания: `await root.size_changed` вместо `create_timer`.
6. Пересобрать список «видовых» в данные (JSON), а не длинный `if suite not in (...)` строкой.
7. Ленивая загрузка текстур (раздел 5) ускоряет каждый из 84 запусков.

Оценка ускорения: **замер нужен**, но крупнейшие рычаги — soak и vsync; параллель headless даст ещё.

---

## 7. План замеров

### 7.1 Что мерить и чем

| Что | Чем |
|-----|-----|
| Время `_draw` главного узла | `Time.get_ticks_usec()` в начале и конце (переименовать `_draw` в `_draw_scene`, обёртка пишет в `perf`) |
| `art_world.update_view`, 6 `PaintLayer.painter`, `Instruments._draw`, `CabSide._draw` | то же |
| `model.physics_step` | то же вокруг вызова в `_physics_process` (main.gd:2493) |
| FPS, кадр, нагрузка скриптов | `Performance.TIME_FPS`, `TIME_PROCESS`, `TIME_PHYSICS_PROCESS` |
| Draw calls, объекты, память текстур | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TEXTURE_MEM_USED`, `RENDER_VIDEO_MEM_USED`, `MEMORY_STATIC`, `OBJECT_COUNT`, `OBJECT_ORPHAN_NODE_COUNT` |
| CPU/GPU время кадра | `RenderingServer.viewport_set_measure_render_time()` + `viewport_get_measured_render_time_cpu/gpu` (поддержка GPU-таймера в GL Compatibility **проверить**) |
| Профиль функций | встроенный Profiler редактора (Debugger → Profiler) и Monitors на слабом ноутбуке, одна и та же сцена |
| Старт | `Time.get_ticks_msec()` (время от старта движка) в первом кадре меню; плюс `Performance.RENDER_TEXTURE_MEM_USED` после старта |
| Сцены | (1) меню; (2) маршрут: дрезина + 2 вагона, 1600×900; (3) то же в депо; (4) кабина бензиновой/паровоза; (5) цеппелин с погодой и ночью; (6) пауза с модалкой |

### 7.2 Пороги «хорошо» для слабого ноутбука (встроенная видеокарта, 1600×900)

Это **цели**, а не замеры:
- 60 FPS: кадр ≤ 16.7 мс; «1% самых плохих кадров» ≤ 25 мс.
- Скрипты (`_process` + `_draw` + физика) ≤ 8 мс на целевом ноутбуке, остальное — драйвер и GPU.
- `physics_step` ≤ 0.5 мс на тик (60 тиков/с).
- Видеопамять под текстуры на старте ≤ 250 МБ (сейчас ≈340, оценка).
- Старт до меню ≤ 5 с.

### 7.3 Предложение: набор `check_perf_budget`

- Файл `tests/check_perf_budget.gd` (+ строки в `run_checks.py`: добавить в список видовых и в `marker`, `'PERF BUDGET CHECKS'`).
- Окно настоящее, `vsync=false`, `max_fps=0`, 1600×900. По образцу `check_perf.gd`, но без привязки к частоте экрана (**сегодняшний `check_perf` с vsync измеряет интервал экрана, а не стоимость кода**, порог 30 мс слабый и проходит на любом железе).
- Для сцен 2–6 из 7.1: 30 прогревочных кадров + 300 замеренных; брать **медиану и p95** по каждому счётчику.
- Бюджеты не придумывать заранее: первый запуск пишет `qa/perf_baseline.json` (машина, процессор, версии); дальше порог = baseline × 1.3 (на медиане) и × 1.6 (на p95). Для слабого ноутбука отдельный baseline-файл.
- Жёсткие абсолютные пороги (после калибровки на слабом ноутбуке): `_draw` main, `update_view`, HUD, `physics_step`, число draw calls, `RENDER_TEXTURE_MEM_USED`, `OBJECT_ORPHAN_NODE_COUNT` не растёт.
- Отчёт: таблица «сцена × счётчик» в `qa/perf_budget/*.json` + упавшие бюджеты в логе `FAIL:`.

Заготовка таблицы бюджетов (поля заполнить после baseline):

| Сцена | `_draw` main | `update_view` | HUD | `physics_step`/тик | draw calls | текстуры, МБ |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|
| меню | ? | ? | — | — | ? | ? |
| маршрут, 3 тела | ? | ? | ? | ? | ? | ? |
| депо | ? | ? | — | — | ? | ? |
| кабина | ? | — | ? | ? | ? | ? |

---

## 8. Топ-10 находок и порядок работ

### 8.1 Топ-10 по выгоде/риску

| # | Находка | Выгода | Риск | Шаг |
|---|---------|:------:|:----:|:---:|
| 1 | Замеры и `check_perf_budget` (основа для всех остальных) | основа | Н | С |
| 2 | Мёртвый код и мёртвые картинки (3.1, 3.2) | С (размер, чистота) | нулевой | М |
| 3 | Кэш кадра для `world_point` + удаление пустых циклов (H1, H4) | В | Н | С |
| 4 | Кэши: `weather_knot`, `casino()`, `station_interaction` (H8, H16, H6) | С | Н | М |
| 5 | Тесты: soak 300 с, vsync off, пул headless, топ-10 медленных (раздел 6) | В (для работы) | Н | С |
| 6 | Кэш `object_stats` + снимок поезда за тик (H7, H2, H17) | В | С | С |
| 7 | `update_view`: параллакс без пересборки меша, статичные слои по требованию (H3, H5, H15) | В | С | С |
| 8 | HUD: кэш профиля и `climb_ahead` (H11) | С | Н | М |
| 9 | Кабина: таблица высот и кэш статичной рамы (H9, H10) | В (в кабине) | С | К |
| 10 | Загрузка: лениво по машинам/кабине, миниатюры гаража, lossy для фонов (раздел 5, 1.4) | С (старт, память, размер) | Н-С | К |

Дальше (после 10): бесшовный параллакс офлайн (H20), `route.points` в Packed-массивах (H21), разбиение `main.gd` (4.1), свой шаблон Godot (1.4).

### 8.2 Маленькие шаги: 1 шаг = 1 коммит + тест

Размер: М = мелкий (до часа), С = средний (полдня), К = крупный (день и больше).

| № | Шаг | Тесты после шага | Размер |
|---|-----|------------------|:------:|
| 0 | Счётчики `Time.get_ticks_usec()` в `_draw`/`update_view`/HUD/`physics_step`, `perf` в `main`; `tests/check_perf_budget.gd` пишет baseline | новый набор + `check_perf` | С |
| 1 | Удалить мёртвые функции и `if false` (3.1, H4): `draw_world`, `draw_background`, `draw_foreground` (main), `terrain_band`, `draw_map`, `mission_description`, `control_zoom_transform`, `hand_grip`, `draw_worker`, `sector_weights`, `g_load`, 5 констант | `check_layout_p7`, `check_presentation`, `check_cab`, `check_model` | М |
| 2 | Исключить мёртвые картинки из экспорта (`exclude_filter`), убрать `terrain/*` из manifest и загрузку `forest_background`; затем удалить файлы из репозитория | `check_art_v3`, `check_world_geometry`, `check_skins`, экспорт + `--exported` короткий набор | М |
| 3 | `FrameCtx` для `world_point`/`rail_baseline`/`view_scale` (H1) | `check_world_geometry`, `check_layout_p7`, `check_depot_entry`, `check_cab` | С |
| 4 | Кэш `weather_knot`; один `Casino`; кэш `station_interaction` за тик/кадр (H8, H16, H6) | `check_model`, `check_interaction`, `check_station_service`, `check_casino`, `check_forecast` | М |
| 5 | Тесты: `--soak-duration` по умолчанию 300, vsync/FPS в `test_mode`, `size_changed` вместо таймеров, вывод топ-10 по времени (6.3) | полный прогон 84 для сравнения времени | С |
| 6 | Пул процессов для headless-наборов в `run_checks.py`; развести `user://qa_model` | headless-часть двумя прогонами (последовательно/параллельно) — одинаковый результат | С |
| 7 | Кэш `body_transform`/`wheel_positions`/`body_bounds` на кадр (H2, H17) | `check_world_geometry`, `check_art_v3`, `check_live_view`, `check_loading_selection` | С |
| 8 | Кэш `object_stats` с версией + снимок поезда за тик (H7) | `check_model`, `check_physics`, `check_wear`, `check_upgrades_new`, `check_live`, `drive_campaign` | С-К |
| 9 | `update_view`: параллакс-квад + `u` в шейдере, статичные слои `haze/ground_shade/light` по требованию, `const` для словарей (H3, H5) | `check_world_geometry`, `check_presentation`, `check_wind_view`, скриншоты `check_layout_p7` | С |
| 10 | Пропуск перерисовки при паузе/модалке без анимации (H15) | `check_interaction`, `check_depot_entry`, `check_settings` | М |
| 11 | HUD: кэш профиля/`climb_ahead`, `ensure_profile` без массива, один полигон заливки (H11) | `check_instruments`, `check_layout_p7` | М |
| 12 | Мелочи: `style()`-ключи, `box()` в пультах → общий помощник, `set_cutoff` по изменению, литералы словарей (H12, H13, H14, H18) | `check_sound`, `check_zeppelin_view`, `check_jet_view`, `check_presentation` | М |
| 13 | Кабина: таблица высот для `project`, статическая рама в текстуру (H9, H10) | `check_cab`, `check_petrol_view`, `check_steam_view`, `check_pneumatic_view` | К |
| 14 | Загрузка: `preload` → ленивый `load` по машине/кабине, миниатюры гаража, атлас из старых листов (раздел 5) | `check_art_v3`, `check_skins`, `check_presentation`, экспорт + запуск | К |
| 15 | Картинки: lossy для фонов/карт, уменьшение колёс/механизма/иконки (по 3 файла сперва, смотреть глазами) | `check_world_geometry`, `check_mechanism`, `check_card_view`, `check_album_view`, скриншоты | С |
| 16 | Бесшовный параллакс офлайн (`tools/`) + шейдер с 1 выборкой (H20) | `check_presentation`, глаза | С |
| 17 | `model.rules` вместо `static var` ×5; разрыв цикла `Model↔Wear` (4.3) | вся headless-пачка | С |
| 18 | `main.gd`: вынос по одному блоку за коммит (settings → hud → train_view → steam_pult → depot_view → input_router) | полный прогон 84 после каждого | К (суммарно), С на коммит |
| 19 | `route.points` → `Packed*Array` с неизменным форматом сейва (H21) | `check_save_p8`, `check_line_v2`, `check_line_spread`, `check_world_geometry` | С |
| 20 | Свой урезанный шаблон Godot (экспорт −40…−60 МБ, оценка) | экспорт + `--exported` пачка | К |

---

## Приложение: как проверить удаление безопасно
1. Перед удалением файла — `Grep` по имени и по папке (формат `"%s.png"` и `"…_%d.png"` встречается в `casino_view.gd` и `card_view.gd`).
2. Для картинок: сначала `exclude_filter`, собрать exe, пройти `check_presentation` и открыть казик/альбом/гараж руками; только потом удалять из репозитория.
3. Для функций: после удаления `Grep` по имени в `tests/` и `dev/` (тесты тоже используют контрактные методы).
