# Комплект П17 «Пульты реактивного и цеппелина: детали для сборки»

Сейчас пульты реактивного (`ref_jet_panel_now.jpg`) и цеппелина нарисованы кодом: тёмные плоские коробки, простые ползунки и циферблаты. Панель пуска реактивного уже отдельными картинками (П15). Нужны остальные детали с сильным объёмом, из которых игра соберёт ОБА пульта (у них общая сетка 840 на 190). Образец вида и духа: `ref_dashboard_concept.jpg` (зелёная клёпаная плата в рамке из дерева, латунные кольца, красные колпачки, шар на рычаге, кольцо парашюта).

Четыре картинки (плата, циферблаты, рычаги, кнопки), по одной. Файлы сохраняются в `tools/art_sources/inbox/P17_pults/` с точными именами.

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P17 pults" of a cozy narrow-gauge forest railway game: ref_jet_panel_now.jpg is the CURRENT dashboard of the rocket railcar cab drawn by code (flat dark boxes, plain sliders, plain dials), ref_dashboard_concept.jpg is a concept of the dashboard look I like (a green riveted metal board in a honey-wood frame, brass-ringed round gauges, red hinged caps over toggle switches, a big red button under a glass cover, a ball-topped throttle lever on a brass sector, a lever in a slotted steel plate, a pull ring with a parachute badge, a signal lamp under a guard), ref_style_steam.jpg is the style anchor. The same set of parts will dress TWO dashboards: the rocket railcar (throttle lever, brake lever, four toggles, start button, countdown board, speed dial, bars for thrust, kerosene and heat, parachute ring) and the rail airship (four levers that stay where they are put like in an aeroplane: throttle, propeller pitch, stick, brake; a start button, an air-brake button, a trim button, dials for airspeed, revolutions and engine temperature, bars for wheel load, altitude and fuel, a warning lamp). I need the parts painted separately so that the game can assemble the dashboards from them. Common style: hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. All parts seen from the FRONT, flat, facing the viewer, upright. Flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text, nothing touching the frame edge. Dial faces carry only tick marks and colored zones, never numerals.
```

### A1 `pult_board.png`: the empty dashboard board (landscape 3:2)

```text
Asset: pult_board. Format: landscape 3:2. Background: flat pure magenta #FF00FF. ONE empty dashboard board seen from the FRONT, wide, with NO controls on it at all: a green riveted metal plate with worn paint and a few scratches, a honey-wood frame with brass corner brackets, a recessed darker strip across the middle and a row of round empty mounting rings (just bare brass collars) along the top; leave the plate surface calm and uncluttered so that the game can place controls on it. The plate must stretch well: no details that sit only in the middle, rivets and brackets only along the frame. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text, nothing touching the frame edge.
```

### A2 `pult_dials.png`: dials and gauge parts (square 1:1)

```text
Asset: pult_dials. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Parts of dashboard instruments, all from the FRONT, no numerals anywhere, only tick marks: 1 a BIG round dial in a thick brass ring with riveted flange, cream face with fine tick marks around a 270-degree sweep and a red zone at the end, NO needle; 2 a SMALL round dial in a brass ring, cream face, tick marks, a green zone and a red zone, NO needle; 3 a long thin curved dial needle (black steel with a brass hub cap), lying horizontally, pointing right; 4 a short needle for the small dial (same style), lying horizontally, pointing right; 5 a horizontal BAR GAUGE frame: a long narrow brass-framed window with a dark empty glass slot and tick marks, no fill; 6 the same bar gauge FILL strip as a separate piece: a long narrow bar of glowing amber glass with a lit top edge; 7 a VERTICAL bar gauge frame (tall narrow brass-framed window with a dark empty slot and tick marks); 8 a COUNTDOWN BOARD frame: a wide dark recessed display window in a riveted brass bezel with a dark glass, empty, no digits; 9 a round WARNING LAMP in a brass ring with a wire guard, dark and unlit. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A3 `pult_levers.png`: levers, sliders and knobs (square 1:1)

```text
Asset: pult_levers. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Parts of dashboard levers, all from the FRONT: 1 a TALL vertical lever SLOT: a long narrow steel plate with a dark groove down the middle, rivets at the corners and fine tick marks along one side, EMPTY; 2 a ball-topped lever knob in RED enamel with a brass collar, standing upright (it will slide in the slot); 3 the same knob in GREEN; 4 the same knob in AMBER yellow; 5 the same knob in BLUE; 6 a fan-shaped brass SECTOR plate for a throttle lever: a curved brass scale plate with tick marks and a heavy steel pivot hub, no lever; 7 a long brass lever arm with a red ball on top, lying upright, to be hung on the hub of the sector; 8 a wide short horizontal slot plate (steel plate with a short groove) for a stick; 9 a broad flat paddle handle in green enamel with ribs for gripping, standing upright. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A4 `pult_buttons.png`: buttons, pull ring and lamps (square 1:1)

```text
Asset: pult_buttons. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Parts of dashboard buttons, all from the FRONT: 1 a wide rectangular PUSH BUTTON, dark and not pressed, in a steel frame with four rivets; 2 the same button LIT and pressed, glowing green; 3 a wide rectangular push button LIT amber (an alert); 4 a small round amber lamp, dark; 5 the same small lamp glowing; 6 a big round RED warning lamp, dark, with a brass ring; 7 the same lamp glowing red (painted as an opaque bright glass, with an opaque ring as the halo); 8 a brass PULL RING with a small parachute badge on a round plate, hanging down, at rest; 9 the same ring PULLED down by a hand's length, the plate with its cord stretched. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

## Чек-лист приёмки
1. Плата пустая, без органов и без букв; рамка и заклёпки только по краю (плата растягивается на 840 на 190).
2. Циферблаты без цифр, только деления и цветные зоны; стрелки отдельно, лежат горизонтально, смотрят вправо.
3. Рычаги: паз пустой, шары четырёх цветов одного размера, сектор и рычаг отдельно.
4. Кнопки: выкл., нажата, предупреждение, лампы тёмная и горящая (ореол плотный, не мягкий), кольцо в покое и вытянутое.
5. Фон пурпурный; предметы не обрезаны; листы ровно по 9 предметов.

## Что делаю я после получения
Принимаю, вырезаю фон, режу листы на ячейки, собираю плату и органы в пультах реактивного и цеппелина (шары по цветам: тяга красный, шаг жёлтый, ручка синий, тормоз красный), стрелки поворачиваю кодом, полосы приборов заливаю кодом поверх рамки. Код-рисунок остаётся запасным. Тексты на пульте пишет игра шрифтом.
