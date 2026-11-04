# Комплект П1 «Дорога и земля»: промпты для GPT

Самый частый объект кадра: то, на чём стоит поезд. Сейчас в игре рельсов не видно.

## Что сейчас не так (кадры в этой папке, красные рамки)

- `ref_ground_now.jpg`: **верхняя рамка** это путь: колёса стоят на тонкой тёмной линии (рельс), под ней серая полоса «балласта» с жёлтыми штрихами вместо шпал, потом плоская рыжая глина. **Нижняя рамка** это земля: плоская коричневая заливка без камней, корней и склона, которая занимает заметную часть кадра и выглядит как срез.
- `ref_wheels_on_rail.jpg`: крупно, как колёса сейчас стоят на тонкой линии вместо настоящего рельса.
- `ref_style_steam.jpg` и `ref_style_handcar.jpg`: образцы стиля (живописные машины), на которые равняться.

В игре путь и земля рисуются **полосами, которые повторяются вдоль линии**, поэтому нужны картинки, которые **бесшовно повторяются по горизонтали** (левый край продолжает правый). Размеры в игре: тайл пути 1,8 м (три шпалы по 0,6 м), тайл земли 3 м.

## Что сделать

1. Новый чат. Если GPT читает репозиторий через подключение, фраза:

```
Открой в репозитории CPUadmin/ForestRail (ветка main) файл tools/art_sources/briefs/P1_road_ground/TASK_FOR_GPT.md, посмотри кадры ref_* рядом с ним и выполни задание: три картинки по очереди.
```

2. Если картинки из репозитория он не открывает, приложите четыре файла `ref_*` из этой папки и вставьте блоки из `PROMPTS_FOR_GPT.txt`.
3. Файлы с именами `track_tile.png`, `ground_tile.png`, `trackside_sheet.png` сохраните в `tools/art_sources/inbox/P1_road_ground/`. Я увижу их сам.

Если шов на тайле заметен (левый и правый края не стыкуются), это не страшно: мой скрипт сглаживает шов. А вот прямой рельс и ровный ритм шпал важны.

## Картинки

### A1 `track_tile.png`: рельс, шпалы и щебень (3:2, пурпурный фон над рельсом)

```text
Attached are references for the pack "P1 road and ground". ref_ground_now.jpg shows the game now: the TOP red box is the railway (wheels roll on a thin dark line, flat grey band with yellow dashes instead of sleepers) and the BOTTOM red box is the flat ground. Both are code-drawn and must be replaced by painted art. ref_wheels_on_rail.jpg shows the wheels on that thin line. ref_style_steam.jpg and ref_style_handcar.jpg are the STYLE ANCHORS: match their painterly brush texture, warm worn look, palette and soft light from the upper left exactly. All new strips are SEAMLESSLY TILEABLE horizontally. I will ask for three images one by one.
```

```text
Asset: track_tile. Format: landscape 3:2. Background: flat pure magenta #FF00FF above the rail, no shadow, no gradient.
A SEAMLESSLY TILEABLE horizontal strip: the left and right edges of the image must continue into each other perfectly, because the image repeats side by side along a railway. Strict flat side elevation, perfectly horizontal, no perspective. The strip fills the full width edge to edge. The content occupies the lower 60 percent of the frame; the upper 40 percent is empty magenta.
Content from the top down:
(1) ONE continuous narrow-gauge steel rail seen from the side: a rail head with a polished lighter top edge, a thin web and a wide foot, a little rust and wear, running perfectly straight across the whole width, rail height about 11 percent of the frame height, with two small steel tie plates under it, one above each of the outer sleepers;
(2) directly under the rail foot, the ends of THREE identical dark creosote-brown wooden sleepers seen end-on as rectangles with visible wood grain and small cracks, evenly spaced, centered exactly at 1/6, 3/6 and 5/6 of the image width, each about 10 percent of the width wide and 12 percent of the frame height tall, so that the pattern repeats cleanly at the edges;
(3) around and under the sleepers a bed of crushed grey-brown stone ballast with varied angular stones, a few small weeds and moss, filling the gaps between the sleepers up to the rail foot and the whole lower part of the strip down to the bottom edge, which is solid ballast stones.
Soft light from the upper left. Hand-painted, painterly brush texture, warm and slightly worn, early 20th century Russian northern narrow-gauge railway, same style as the attached steam locomotive. No letters, no numbers, nothing else in the frame.
```
Назначение: настоящий рельс, по которому катятся колёса, шпалы и щебень вместо серой полосы со штрихами.

### A2 `ground_tile.png`: земляной срез под путём (3:2, пурпурный фон над травяной кромкой)

```text
Asset: ground_tile. Format: landscape 3:2. Background: flat pure magenta #FF00FF above the grass lip only, no shadow.
A SEAMLESSLY TILEABLE horizontal strip: the left and right edges of the image must continue into each other perfectly. The cut face of the earth under a forest railway embankment, in strict flat side elevation, filling the full width edge to edge, with no horizon and no sky.
The top edge is an irregular lip of wild grass, clover, small ferns and moss hanging slightly over the edge, about 12 percent of the frame height, against pure magenta above it. Below the lip, from the top down: a dark humus layer with thin pale roots, then warm brown soil with rounded fieldstones and gravel, some half sunk into the earth, then a band of paler clay with fine layers, then darker compacted earth at the bottom, getting gradually darker towards the bottom edge so that it can fade into shadow. The lower 85 percent of the frame is solid ground.
Soft light from the upper left. Hand-painted, painterly brush texture, warm and slightly worn, same style as the attached references. No letters, no numbers, no rails, nothing else.
```
Назначение: заменяет плоскую коричневую заливку под путём: корни, камни, слои глины, трава на кромке.

### A3 `trackside_sheet.png`: придорожные мелочи (лист 3×3, пурпурный фон)

```text
Asset: trackside_sheet. Format: square 1:1. Sheet 3 by 3, one flat pure magenta #FF00FF background for the whole sheet, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows.
Nine small objects for the verge of a forest narrow-gauge railway, each in strict flat side view standing on a tiny patch of earth, hand-painted, painterly, warm and slightly worn, same style as the attached references:
1 a cluster of three grey fieldstones;
2 a mossy boulder;
3 a tuft of tall wild grass with seed heads;
4 a bracken fern clump;
5 a few white and yellow wildflowers (cow parsley and buttercups);
6 a weathered tree stump with roots;
7 a mossy fallen log;
8 a wooden kilometre post, a plain weathered painted board on a post, completely blank, no digits and no letters;
9 a small heap of broken old sleepers next to a rusty bolt keg.
No letters, no numbers, no people.
```
Назначение: разнообразие обочины (камни, трава, пни, километровый столбик) вместо повторяющихся папоротников.

## Чек-лист приёмки пакета

1. Нет букв и цифр (километровый столбик пустой).
2. **A1:** рельс прямой по всей ширине, три шпалы ровно по трети ширины, фон над рельсом пурпурный, низ сплошной щебень.
3. **A2:** сверху неровная травяная кромка на пурпурном, ниже слои земли, внизу темнее, пурпурного снизу нет.
4. **A3:** ровно девять предметов по одному в ячейке.
5. Левый и правый края A1 и A2 примерно стыкуются (небольшой шов я сглажу).
6. Стиль и свет как у образцов. Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10.

## Что делаю я после получения

Принимаю (вырезаю фон, сглаживаю шов, обрезаю), измеряю, где у рельса верх головки, и ставлю так, чтобы колёса катились по нему; перенастраиваю полосы пути и земли на новые бесшовные тайлы, расставляю придорожные предметы, показываю кадры «до и после» в трёх размерах окна и на подъёмах и спусках.
