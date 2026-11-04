# Комплект П2 «Шестовая и парусная»: промпты для GPT (пробный пакет)

Это первый пакет по новому потоку (Веха 9). Он маленький, но проходит весь путь от промпта до игры, чтобы поправить процесс до больших пакетов. Четыре картинки.

## Что сейчас не так (на кадрах-образцах в этой папке)

- **Шестовая** (`ref_pole_now.jpg`, красная рамка): шест это плоская коричневая линия с серым квадратиком вместо наконечника; рука водителя плоский зелёный прямоугольник, наклеенный на тело, без локтя и кисти, не держится за шест. Водитель при этом нарисован живописно, кузов тоже: разные манеры на одном кадре.
- **Парусная** (`ref_sail_now.jpg`, красная рамка): парус гладкий серо-кремовый треугольник без ткани, швов и складок, такелаж тонкими прямыми линиями; рука водителя та же плоская полоса.
- **Образцы стиля**, на что равняться: `ref_style_steam.jpg` (лучшая по живописи машина) и `ref_style_handcar.jpg` (платформа, на которой стоят шестовая и парусная).

## Что сделать

1. **Один раз** убедитесь, что в вашем GPT-проекте стоит инструкция из `tools/art_sources/inbox/GPT_INSTRUCTIONS.txt` (если нет, вставьте полную версию первым сообщением). Подробности: `docs/GPT_ART_BRIEF_RU.md`.
2. Откройте **один новый чат на пакет**. Первым сообщением приложите все пять файлов `ref_*` из этой папки и напишите:

```text
Attached are references for the pack "P2 pole and sail". ref_style_steam.jpg and ref_style_handcar.jpg are the STYLE ANCHORS: match their painterly brush texture, warm worn look, palette and soft light from the upper left exactly. ref_worker.png is the worker whose clothes, skin tone and proportions every new part must match. ref_pole_now.jpg and ref_sail_now.jpg show what is wrong now (flat code-drawn parts inside the red boxes) and must be replaced. I will ask for four images one by one. Return one image per request, with the background I name.
```

3. Дальше по одной картинке (A1…A4 ниже): скопируйте промпт, получите картинку, проверьте по чек-листу в конце, при надобности поправьте фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10.
4. Сохраните файлы **с точными именами** в `tools/art_sources/inbox/P2_pole_sail/` и напишите мне «П2 в inbox» (или пришлите файлы в чат).

## Картинки

### A1 `pole_parts.png`: шест по частям (квадрат или 3:2, на пурпурном фоне)

Шест длиной 3 метра и толщиной 4 сантиметра не поместится в кадр целиком, поэтому прошу три отрезка в одном листе; средний кусок гладкого дерева я растяну сам.

```text
Asset: pole_parts. Format: landscape 3:2. Background: flat pure magenta #FF00FF, no shadow, no floor.
A sheet with THREE separate straight horizontal segments of one wooden punting pole for a hand-pushed forest rail trolley, stacked vertically with wide empty margins between them, each segment as wide as 90% of the frame and about 11% of the frame tall, all drawn perfectly straight and horizontal in flat side view, the same pole.
Top segment: the HEAD of the pole: weathered pale pine, visible grain, a small rounded wooden end with a thin iron cap and one rivet, a leather-wrapped hand grip near the end, darkened and polished where hands slide.
Middle segment: PLAIN SHAFT: weathered pine with grain, a few small knots, two old repair bindings of tarred cord, slightly worn and darker in the middle.
Bottom segment: the FOOT of the pole: weathered pine ending in a forged iron-shod pointed tip, a riveted iron socket collar with two rivets, a long tapered spike with small nicks, a trace of rust.
Hand-painted, painterly brush texture, warm and slightly worn, early 20th century Russian northern railway, same style as the attached steam locomotive. No letters, no numbers, no people.
```
Назначение: заменяет плоскую линию шеста и серый квадратик наконечника.

### A2 `worker_arm_parts.png`: части руки водителя (квадрат, на пурпурном фоне)

Сейчас рука плоский прямоугольник. Мне нужны части руки в той же одежде, чтобы собрать её из двух звеньев и кисти, которая держит шест.

```text
Asset: worker_arm_parts. Format: square 1:1. Background: flat pure magenta #FF00FF, no shadow.
The attached ref_worker.png is the character: dark olive-green wool work jacket, brown trousers, flat cap, weathered skin. Draw the ARM PARTS of this exact same worker as four separate pieces on one sheet, each piece centered in its own quarter of the frame with wide margins, all in strict flat side view, painted in exactly the same style, fabric, colors and light as the worker:
(1) the UPPER ARM in a jacket sleeve, drawn straight and horizontal, slightly bent fabric folds, rounded shoulder end on the left and rounded elbow end on the right, about 3 times longer than thick;
(2) the FOREARM in the same sleeve with a button cuff, straight and horizontal, elbow end on the left, wrist on the right;
(3) a bare weathered HAND with a rolled-up cuff, fingers closed in a fist wrapped around a thin round rod, the rod itself shown crossing the fist horizontally;
(4) the same HAND with fingers open and relaxed, palm facing down, hanging.
Hand-painted, painterly, warm and slightly worn, no outline glow, no letters, no other body parts.
```
Назначение: рука собирается из звеньев от плеча к кисти, кисть держит шест, а не парит рядом.

### A3 `sail_cloth.png`: ткань паруса (3:2, на всю картинку, без фона)

```text
Asset: sail_cloth. Format: landscape 3:2. Full-bleed texture: the cloth fills the whole frame edge to edge, no background, no cut-out shape.
A flat piece of old heavy cotton sailcloth, cream-white to pale ivory, taut and seen straight from the front, slightly irregular canvas weave, horizontal panel seams every 12% of the height with double stitching, two small hand-sewn patches in slightly different tones, faint soft folds and light wear near the edges, a hemmed border with fine stitching along the top and bottom edges, a couple of small brass grommets near the left edge. Light comes softly from the upper left. Hand-painted, painterly, warm and slightly worn, same style as the attached references. No mast, no ropes, no text, no marks, no shadows cast on anything.
```
Назначение: натягиваю на сетку паруса вместо гладкой серой заливки; складки в игре остаются программными.

### A4 `sail_hardware.png`: детали такелажа (квадрат, лист 3×3, пурпурный фон)

```text
Asset: sail_hardware. Format: square 1:1. Sheet 3 by 3, one flat pure magenta #FF00FF background for the whole sheet, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels.
Nine small pieces of rigging for a hand-built wooden rail sailing trolley, each in strict flat side view, hand-painted, painterly, warm and slightly worn, aged brass, dark iron and weathered wood, same style as the attached references:
1 a wooden mast top cap with a brass fitting and a small pulley;
2 a single wooden block (pulley) with a rope through it;
3 a horn-shaped wooden cleat for belaying a rope;
4 a brass-ringed grommet with a short lashing rope;
5 a coil of thick hemp rope, lying flat in side view;
6 a forged iron shackle;
7 a small triangular wind pennant on a short brass pole, red and cream stripes, gently waving to the right;
8 a wooden boom end with an iron cap and a rope eye;
9 an iron deck fitting (a ring bolt on a small plate) for fastening a rope.
No letters, no numbers, no people.
```
Назначение: крепления и вымпел вместо тонких прямых линий.

## Чек-лист приёмки пакета (проверьте до отправки мне)

1. Нет букв, цифр, подписи, водяного знака.
2. Фон ровный пурпурный (или чёрный там, где сказано), без тени, пола, градиента; предметы целые, поля не меньше 8%.
3. Стиль и свет как у `ref_style_steam.jpg`: живописная кисть, тёплая потёртость, свет сверху-слева.
4. **A1:** три отрезка прямые и горизонтальные, один и тот же шест; **A2:** одежда и цвет кожи как у `ref_worker.png`, четыре детали, кулак держит стержень; **A3:** ткань во весь кадр без теней и обрезанных форм; **A4:** ровно девять предметов по одному в ячейке.
5. Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10; если не получается с трёх попыток, пришлите как есть и напишите, что не так.

## Что делаю я после получения

Принимаю по пунктам (вырезаю фон, чищу кайму, привожу масштаб к 128 px/м), собираю шест из трёх частей, руку из звеньев, парус с новой тканью и такелажем, показываю кадры «до и после» в трёх размерах окна. Скажу по каждой картинке «принято» или «вернуть» с одной фразой для GPT.
