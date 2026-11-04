# Комплект П12 «Гаджеты на машинах»: GPT придумывает вид и описание сам

Задача для GPT большая и творческая: **придумать, как каждый из 18 гаджетов выглядит установленным на своей машине, нарисовать и описать.** Принимает и подключает Claude.

## Где GPT берёт информацию (читай по порядку)

Все пути от папки проекта `C:\Users\Lenovo\Documents\ChatGPT\дрезина`.

1. `docs/KAZIK_CARDS_RU.md`: какая карточка Таро какому гаджету и машине соответствует (таблица раздела 2), лор (раздел 9: Михалыч нарисовал колоду, задепал её в машину, меняет карту на гаджет), реплики.
2. `docs/KAZIK_CARD_RECIPES_RU.md`: у каждой карты строка «Бафф» это предмет-намёк на то, что гаджет делает. Это основа внешнего вида гаджета.
3. `docs/MACHINE_GAGS_RU.md`: гэги машин (искра электровоза, колечки дыма и свисток паровоза, скрип рычага ручной дрезины, взлёт цеппелина).
4. `ForestRail/data/game_data.json`: раздел `upgrade_catalog` (ветки улучшений) и `casino.cards` (карта → `upgrade`, `machine`). Настоящие эффекты уже есть у `steam_stoker`, `steam_superheater`, `sail_autopilot`, `sail_spinnaker`, у остальных 14 гаджетов в игре пока только карточка.
5. `docs/GPT_ART_BRIEF_RU.md`: общие правила картинок (сильный объём, свет сверху-слева, без букв).
6. Картинки-образцы лежат рядом в `tools/art_sources/briefs/P12_gadgets_on_machines/` (`ref_*`): машины и готовые значки гаджетов.

## Что сделать (результат кладётся в `tools/art_sources/inbox/P12_gadgets_on_machines/`)

1. **9 картинок «машина с двумя гаджетами»** (A1-A9): вид сбоку, машина из образца с двумя установленными на неё гаджетами, нарисованными крупно и читаемо. Сам придумай, где на машине что стоит и как крепится, исходя из того, что гаджет делает (см. «Бафф» в рецептах).
2. **2 листа деталей** (A10, A11): те же 18 гаджетов отдельными деталями (как вынутыми из машины), по 9 на лист 3 на 3, для наложения в игре.
3. **Текстовый файл `GADGET_TEXTS_RU.md`** (в ту же папку inbox): для каждого из 18 гаджетов блок из шести пунктов: **название**, **на какой машине**, **что делает в игре простыми словами** (по `game_data.json` и рецептам, для четырёх реальных гаджетов точно по данным), **как выглядит и где стоит на машине** (твоё решение), **почему именно так** (одной фразой: связь картинки карты и действия), **фраза Михалыча при установке** (шуткой, в его тоне: ирония, ворчливая забота; не повторяй реплики из `KAZIK_CARDS_RU.md`).

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P12 gadgets on machines" for a cozy narrow-gauge forest railway game: the approved painted side views of our nine machines (atlases, the new electric locomotive, the rail zeppelin, the jet train) and the polished icons of the 18 gadgets. For each machine I need you to design and paint its TWO gadgets installed on the machine, as bold readable parts that clearly show what the gadget does. Common style: hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Strict flat side view, flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text. Keep the machine exactly as in the reference (shape, colours, wheels) and add the gadgets to it. I will ask for the images one by one.
```

### A1 `gadgets_handcar.png`: Ручная дрезина с двумя гаджетами

```text
Asset: gadgets_handcar. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the ручная дрезина taken from ref_flatbeds_atlas.jpg (the handcar, top left), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Храповик (карта VI Влюблённые): a ratchet wheel with a pawl on the lever axle: the lever pulls both ways without losing ground. 2) Маховик-накопитель (карта X Колесо Фортуны): a heavy flywheel with a green face on the drive axle that stores motion. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A2 `gadgets_pole.png`: Шестовая дрезина с двумя гаджетами

```text
Asset: gadgets_pole. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the шестовая дрезина taken from ref_flatbeds_atlas.jpg (the pole truck, top right), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Пого-шест (карта 0 Шут): a spring-loaded pogo pole with a big coiled spring stored on the deck: higher jumps. 2) Кошка с лебёдкой (карта XII Повешенный): a grappling hook on a rope with a winch drum on the deck: pulls the truck up. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A3 `gadgets_sail.png`: Парусная дрезина с двумя гаджетами

```text
Asset: gadgets_sail. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the парусная дрезина taken from ref_flatbeds_atlas.jpg (the sail car, bottom left), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Флюгер-автопилот (карта II Верховная жрица): a red weather vane on top of the mast that trims the sail by itself. 2) Спинакер (карта XVI Башня): a big red and cream balloon-shaped spinnaker sail set beside the main sail. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A4 `gadgets_steam.png`: Паровоз с двумя гаджетами

```text
Asset: gadgets_steam. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the паровоз taken from ref_motors_atlas.jpg (the steam locomotive, top left) and ref_style_steam.jpg, facing right, with TWO gadgets painted onto it as bold readable parts: 1) Механический кочегар (карта I Маг): a screw conveyor and a coal hopper that feed the firebox door by themselves. 2) Пароперегреватель (карта XIV Умеренность): a copper coil of pipes along the boiler: less coal, more steam. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A5 `gadgets_motorcar.png`: Бензиновая дрезина с двумя гаджетами

```text
Asset: gadgets_motorcar. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the бензиновая дрезина taken from ref_motors_atlas.jpg (the petrol motorcar, top right), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Автоматическая КПП (карта IV Император): a neat gearbox housing with gears and an automatic shift lever beside the cab. 2) Закись азота (карта VIII Сила): a blue nitrous oxide bottle on the hood with a feed pipe to the engine and a short blue-orange flame outlet. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A6 `gadgets_pneumatic.png`: Пневматическая дрезина с двумя гаджетами

```text
Asset: gadgets_pneumatic. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the пневматическая дрезина taken from ref_motors_atlas.jpg (the pneumatic locomotive, bottom right), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Запасной баллон (карта III Императрица): a second big green air cylinder with a brass valve and gauge on the roof or frame. 2) Автоматический редуктор (карта V Иерофант): a brass pressure reducer wheel with a gauge on the front of the boiler tank. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A7 `gadgets_locomotive.png`: Электровоз с двумя гаджетами

```text
Asset: gadgets_locomotive. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the электровоз taken from ref_electric_new.jpg (the new body from pack P5), facing right, with TWO gadgets painted onto it as bold readable parts: 1) Суперконденсатор (карта VII Колесница): a blue capacitor bank with golden terminals and a lightning bolt sign on the hood. 2) Жидкостное охлаждение (карта XI Справедливость): a brass radiator with blue coolant pipes on the side of the hood. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A8 `gadgets_zeppelin.png`: Цеппелин с двумя гаджетами

```text
Asset: gadgets_zeppelin. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the цеппелин taken from ref_zeppelin.jpg, facing right, with TWO gadgets painted onto it as bold readable parts: 1) Триммер (карта IX Отшельник): a small trim wheel and a spirit level at the gondola, a lantern glow. 2) Закрылки (карта XVII Звезда): wing flaps tilted up on the small wings. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A9 `gadgets_jet.png`: Реактивный с двумя гаджетами

```text
Asset: gadgets_jet. Format: landscape 3:2. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the реактивный taken from ref_jet.jpg, facing right, with TWO gadgets painted onto it as bold readable parts: 1) Двойной парашют (карта XIII Смерть): two folded parachutes (red and cream) in a rear container, ready to open. 2) Форсаж (карта XV Дьявол): an afterburner nozzle with a long red-orange-yellow flame. You decide where each gadget sits on the machine and how it is attached, so it makes sense mechanically and is visible. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Keep the machine itself unchanged. Wheels may be drawn as in the reference. No letters, no numbers, no text.
```

### A10 `gadget_parts_1.png`: детали гаджетов, лист 1

```text
Asset: gadget_parts_1. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Nine gadget parts, each shown alone as a finished brass-and-steel mechanical part (the same objects as installed in the machine images, in a three-quarter view), in this order: 1 Храповик: a ratchet wheel with a pawl on the lever axle: the lever pulls both ways without losing ground; 2 Маховик-накопитель: a heavy flywheel with a green face on the drive axle that stores motion; 3 Пого-шест: a spring-loaded pogo pole with a big coiled spring stored on the deck: higher jumps; 4 Кошка с лебёдкой: a grappling hook on a rope with a winch drum on the deck: pulls the truck up; 5 Флюгер-автопилот: a red weather vane on top of the mast that trims the sail by itself; 6 Спинакер: a big red and cream balloon-shaped spinnaker sail set beside the main sail; 7 Механический кочегар: a screw conveyor and a coal hopper that feed the firebox door by themselves; 8 Пароперегреватель: a copper coil of pipes along the boiler: less coal, more steam; 9 Автоматическая КПП: a neat gearbox housing with gears and an automatic shift lever beside the cab. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A11 `gadget_parts_2.png`: детали гаджетов, лист 2

```text
Asset: gadget_parts_2. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Nine gadget parts, each shown alone as a finished brass-and-steel mechanical part (the same objects as installed in the machine images, in a three-quarter view), in this order: 1 Закись азота: a blue nitrous oxide bottle on the hood with a feed pipe to the engine and a short blue-orange flame outlet; 2 Запасной баллон: a second big green air cylinder with a brass valve and gauge on the roof or frame; 3 Автоматический редуктор: a brass pressure reducer wheel with a gauge on the front of the boiler tank; 4 Суперконденсатор: a blue capacitor bank with golden terminals and a lightning bolt sign on the hood; 5 Жидкостное охлаждение: a brass radiator with blue coolant pipes on the side of the hood; 6 Триммер: a small trim wheel and a spirit level at the gondola, a lantern glow; 7 Закрылки: wing flaps tilted up on the small wings; 8 Двойной парашют: two folded parachutes (red and cream) in a rear container, ready to open; 9 Форсаж: an afterburner nozzle with a long red-orange-yellow flame. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### Текст `GADGET_TEXTS_RU.md` (не картинка)

После всех картинок напиши файл `GADGET_TEXTS_RU.md` в папку inbox этого пакета по шести пунктам из раздела «Что сделать», для всех 18 гаджетов, на русском.

## Чек-лист приёмки
1. Машина как в образце, гаджеты добавлены, а не заменили её.
2. Каждый гаджет читается и объясняет свой бафф видом.
3. Нет букв, цифр, надписей; фон пурпурный.
4. Тексты: 18 блоков по шесть пунктов, эффекты у четырёх реальных гаджетов сходятся с `game_data.json`.

## Что делаю я после получения
Принимаю, режу листы, подключаю детали к машинам в игре (по одной машине), использую тексты в мастерской и репликах Михалыча, показываю кадры «до и после».
