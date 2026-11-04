# Комплект П4 «Депо как комната»: промпты для GPT

Сейчас интерьер депо рисуется кодом: плоский градиент, «доски» полосками, тёмные стропила и лампы концентрическими кругами. Помещение читается как лесной путь со стеной, а не как мастерская.

## Что сейчас не так (кадры в этой папке)

- `ref_depot_now.jpg`: **красная рамка** это стена с лампами (то, что надо заменить), **синяя линия** это линия пола: ниже неё уже стоят новые рельс и земля из пакета «Дорога». Состав стоит на рельсе в левой половине экрана, справа панель с вкладками закрывает правую половину.
- `ref_depot_exterior.jpg`: как депо выглядит снаружи (образец дерева, зелени и латуни).
- `ref_style_steam.jpg`, `ref_style_handcar.jpg`: образцы стиля.

**Важное требование (просьба владельца 04.11.2026): больше объёма.** Крупные, выпуклые формы, глубокие тени, чёткий рельеф дерева и металла, сильное различие света и тени, как в последнем тайле пути (`track_tile_depth`): он понравился больше плоского варианта. В каждый промпт это уже вписано.

Как это работает в игре: интерьер собирается **слоями**, поэтому прошу не одну картинку, а пять частей: стена (бесшовная плитка), стропила (бесшовная полоса), предметы на стене и полу (лист 3×3), пол в разрезе (бесшовная полоса), свечение лампы (на чёрном).

## Что сделать

1. Новый чат. Если GPT читает репозиторий через подключение, фраза:

```
Открой в репозитории CPUadmin/ForestRail (ветка main) файл tools/art_sources/briefs/P4_depot_room/TASK_FOR_GPT.md, посмотри кадры ref_* рядом с ним и выполни задание: пять картинок по очереди.
```

2. Если картинки из репозитория он не открывает, приложите четыре файла `ref_*` из этой папки и вставьте блоки из `PROMPTS_FOR_GPT.txt`.
3. Файлы `depot_wall_tile.png`, `depot_rafters_tile.png`, `depot_props_sheet.png`, `depot_floor_tile.png`, `depot_lamp_glow.png` сохраните в `tools/art_sources/inbox/P4_depot_room/`. Я увижу их сам.

## Картинки

### A1 `depot_wall_tile.png`: дощатая стена (3:2, на весь кадр, бесшовная)

```text
Attached are references for the pack "P4 depot room". ref_depot_now.jpg shows the game now: the RED box is the code-drawn interior wall with fake lamp glows (to be replaced by painted art), the BLUE line is the floor line. ref_depot_exterior.jpg is how the depot looks from outside. ref_style_steam.jpg and ref_style_handcar.jpg are the STYLE ANCHORS: match their painterly brush texture, warm worn look, palette and soft light exactly. The interior is built from LAYERS, so I will ask for five separate images one by one. ALL the art must have STRONG VOLUME: bold rounded relief, deep shadows between planks and beams, clearly lit and shaded sides, like the heavy relief of the latest track tile.
```

```text
Asset: depot_wall_tile. Format: landscape 3:2. Full-bleed, no magenta, no background: the picture fills the whole frame.
A SEAMLESSLY TILEABLE horizontal wall section of the inside of an old timber railway depot workshop, strict flat frontal elevation (no perspective): the left and right edges must continue into each other perfectly because the image repeats side by side.
Content: heavy vertical pine planks, weathered honey-brown, with deep dark gaps between them, knots, cracks, nail heads, soot streaks and age marks, strong rounded relief, a clear light side and shade side on every plank; ONE massive vertical timber post centered exactly in the middle of the image (about 12 percent of the width wide) with an iron strap bracket and bolts, so that the repeat gives a post every tile; along the bottom edge a thick dark plinth board (skirting), about 8 percent of the frame height, with its lower edge exactly at the bottom of the image; the top edge of the image continues the planks upward without any ceiling.
Warm lamplight from the upper left, a slightly darker lower third. Hand-painted, painterly brush texture, early 20th century Russian northern railway workshop, same style as the attached steam locomotive. No windows, no tools, no letters, no numbers, no people, nothing else on the wall.
```
Назначение: стена за составом вместо плоского градиента с полосками.

### A2 `depot_rafters_tile.png`: стропила и балки потолка (3:2, пурпурный фон ниже балок, бесшовная)

```text
Asset: depot_rafters_tile. Format: landscape 3:2. Background: flat pure magenta #FF00FF below the beams, no shadow, no gradient.
A SEAMLESSLY TILEABLE horizontal strip (left and right edges continue into each other perfectly) of the roof structure inside an old timber depot, strict flat frontal view, filling the full width edge to edge. The strip occupies only the TOP 38 percent of the frame; everything below is flat magenta.
Content: at the very top a dark roof boards ceiling, below it one heavy horizontal crossbeam (tie beam) running across the whole width, about 12 percent of the frame height, with chamfered edges, iron straps and bolts; at the center of the tile a heavy king-post truss: two thick diagonal braces going from the beam down and outwards to the sides, ending in iron brackets at 25 and 75 percent of the width, and a vertical hanging iron ring in the middle where a lamp is hung. STRONG VOLUME: deep shadows under the beam, rounded relief of the wood, clearly lit upper left sides. Warm weathered dark brown and honey wood, soot. Hand-painted, painterly brush texture, same style as the attached references. No letters, nothing else.
```
Назначение: стропила вместо тёмных треугольников и полосы.

### A3 `depot_props_sheet.png`: предметы мастерской (лист 3×3, пурпурный фон)

```text
Asset: depot_props_sheet. Format: square 1:1. Sheet 3 by 3, one flat pure magenta #FF00FF background for the whole sheet, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows.
Nine objects of an old railway workshop, each in strict flat frontal or side view, hand-painted, painterly, warm and slightly worn, with STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), same style as the attached references:
1 a tall wooden window in a heavy frame with small panes, warm daylight glowing through, with a stone sill;
2 a hanging industrial lamp: a conical dark green enamel shade with a brass cap on a short chain, a warm bulb glowing inside;
3 a wooden wall shelf with oil cans, a brass funnel, jars of bolts and a coil of rope;
4 a wall tool rack with a big wrench, a hammer, a long saw and a crowbar hung on pegs;
5 a heavy workbench with a cast-iron vise, a wooden top and a drawer, seen from the front;
6 a wooden barrel with iron hoops and a tin funnel on top;
7 a wooden ladder leaning, seen from the side;
8 a stack of three spare railway wheels with spokes leaning on a wooden crate;
9 a hanging coil of heavy chain on a hook with a hook block.
No letters, no numbers, no people.
```
Назначение: окно, лампа, полка, инструменты, верстак, бочка, лестница, колёса, цепь: я расставляю их по стене и полу в свободных от панелей местах.

### A4 `depot_floor_tile.png`: пол в разрезе (3:2, пурпурный фон над полом, бесшовный)

```text
Asset: depot_floor_tile. Format: landscape 3:2. Background: flat pure magenta #FF00FF above the floor surface only, no shadow.
A SEAMLESSLY TILEABLE horizontal strip (left and right edges continue into each other perfectly): the cut of the floor of an old railway depot workshop, strict flat side elevation, filling the full width edge to edge. The top edge is the flat floor surface, a perfectly straight horizontal line, against pure magenta above it.
From the top down: a heavy worn plank floor, the thick plank ends seen as a row of rectangles with deep dark gaps, oil stains, scratches, iron nails and a few cracked boards, about 20 percent of the frame height; below it big stone foundation blocks with mortar joints and moss in the joints, then darker packed earth and gravel, getting gradually darker towards the bottom edge so that it can fade into shadow. STRONG VOLUME: deep shadows in the gaps, rounded relief of the wood and the stones, light from the upper left. Hand-painted, painterly brush texture, same style as the attached references. No rails, no letters, nothing else.
```
Назначение: пол внутри депо вместо земли с травой (рельс остаётся из пакета «Дорога»).

### A5 `depot_lamp_glow.png`: свет лампы (квадрат, чёрный фон)

```text
Asset: depot_lamp_glow. Format: square 1:1. Background: flat pure black #000000.
A soft warm round light pool as cast by a hanging workshop lamp on a wooden wall: a bright warm white-yellow core in the center, fading smoothly through amber to nothing at the edges, with faint soft dust motes and a gentle slightly uneven edge, no hard shapes, perfectly centered and symmetrical, fully faded to pure black before it reaches the frame edges. Painterly, no lamp, no objects, no letters.
```
Назначение: настоящий мягкий свет под лампой вместо концентрических кругов (чёрное станет прозрачностью).

## Чек-лист приёмки пакета

1. Нет букв и цифр.
2. **A1:** на всю картинку, пурпурного нет; один столб строго по центру; низ с цоколем; шов по краям стыкуется.
3. **A2:** балки только в верхней трети, ниже пурпурный; шов стыкуется.
4. **A3:** ровно девять предметов по одному в ячейке.
5. **A4:** сверху ровная линия пола на пурпурном; ниже доски, камень, земля; внизу темнее.
6. **A5:** светлое пятно на чёрном, до краёв гаснет.
7. Выраженный объём и рельеф у всех, стиль как у образцов. Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10.

## Что делаю я после получения

Принимаю (вырезаю фон, сглаживаю шов, режу лист), делаю в депо слои: стена с потолком и стропилами, пол в разрезе по линии пола, предметы по свободным местам (не под карточкой и панелью), лампа с настоящим светом; проверяю в трёх размерах окна, показываю кадры «до и после».
