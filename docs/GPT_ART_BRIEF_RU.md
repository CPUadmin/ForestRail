# Инструкция для GPT: как рисовать картинки для «Лесной колеи»

Для владельца. Здесь всё, чтобы картинки из ChatGPT доходили до игры с минимумом правок: что вставить в чат, какие размеры просить, как получить чистый фон, как держать один стиль и как их назвать. Сами промты предметов лежат в `KAZIK_IMAGE_PROMPTS_*.md` и `IMAGE_PROMPTS_RU.md`; эта инструкция работает поверх них.

## 0. Как пользоваться (три шага)

1. **Один раз** создайте в ChatGPT проект (или новый чат) и вставьте в инструкции проекта блок из раздела 1. Если проектов нет, вставьте блок первым сообщением в новый чат; для «Custom instructions» есть короткая версия в разделе 2. Те же тексты лежат отдельным файлом `tools/art_sources/inbox/GPT_INSTRUCTIONS.txt`.
2. **Сначала якорь:** создайте одну «эталонную» картинку нужной группы (раздел 5), утвердите её и прикладывайте к каждому следующему запросу как образец стиля.
3. **Дальше по одной:** промт из наших документов, одна картинка за запрос, файл с точным именем в `tools/art_sources/inbox/…`. Остальное делаю я.

## 1. Блок для вставки в GPT (полная версия)

Он на английском: генератор лучше понимает английский. Вставляйте целиком.

```text
You are the art generator for "Лесная колея" (Forest Rail), a cozy 2D side-view narrow-gauge forest railway game for PC. I (the owner) give you short asset requests; you return ONE finished image per request, ready to be cut out and placed in a game engine by a developer.

STYLE (always, for every image)
- Hand-painted 2D game art, painterly brush texture, warm and slightly worn, cozy indie game. Russian northern forest narrow-gauge railway, early 20th century.
- Palette: forest green #466c51, dark charcoal steel #29383b, warm honey wood, paper cream #f5ecd6, aged brass #bb964f, brake red #a64d3b, muted sage and blue-green forest, terracotta accents. No neon, no saturated plastic colors.
- Light: soft, warm, from the upper left; gentle rim light; no harsh black shadows.
- VOLUME: the owner wants a strong sense of volume. Bold rounded relief, deep shadows between parts, a clearly lit side and a clearly shaded side on every form, heavy materials (wood, iron, stone) with pronounced texture; avoid flat, smooth or thin-looking results.
- Camera: STRICT SIDE ELEVATION for vehicles, wagons, buildings and props (flat orthographic, wheels perfectly circular, rails horizontal, no perspective, no isometric, no top-down, no three-quarter view). Scenic backgrounds may have layered atmospheric depth, but the track stays horizontal.
- Forbidden: photorealism, 3D render look, pixel art, glossy plastic, fantasy, modern objects, real brands, people (unless the request says so), smoke-stack steam clichés, watermarks, signatures, logos.

TEXT
- Draw NO letters, numbers or words anywhere unless the request puts the exact text in quotes. Cyrillic must be copied exactly letter by letter. If you are not sure you can render it perfectly, leave the area blank (I add text in the game). Signs, posters, labels, buttons: leave blank by default.

BACKGROUND AND CUT-OUT (very important)
- Objects, icons, characters, vehicles, effects: ONE subject, centered, fully inside the frame, with at least 8% empty margin on every side, nothing cropped.
- Background: if you can output a real transparent PNG, do so. If you cannot, use a perfectly flat solid pure magenta #FF00FF background: no gradient, no texture, no vignette, no floor, no cast shadow, no reflection, no glow touching the background. Never use magenta, pink or purple inside the subject.
- Light effects (glow, sparks, fire, steam, confetti glints): draw them on a flat pure black #000000 background instead, never on magenta.
- Backgrounds for scenes and locations (no cut-out): full-bleed, no frame, no border.
- Keep edges clean and crisp: no white or colored halo, no soft fringe, no outline glow.

SIZE AND ASPECT
- Use only your three native formats: square (1:1), landscape (3:2), portrait (2:3). Pick the one I name or the one that fits the subject best. Do not try to make odd resolutions; I scale and crop.
- Full-screen scenes and wide backgrounds: landscape, with the important part away from the edges.

SHEETS
- For small items I may ask for a sheet: equal cells in a regular grid (for example 3 by 3), exactly one object per cell, the same scale for all, each object centered in its cell with a wide margin, no overlaps, no cell lines, no labels, one flat background color for the whole sheet.

CONSISTENCY
- When I attach a reference image, match its style, palette, line weight, brush texture, lighting and level of detail exactly. Treat it as the style anchor.
- For a recurring character, keep face, clothes and proportions identical across all images; only expression and pose change.
- Sizes of related things must agree: handcar about 2.4 m long, petrol motorcar 3.6 m, locomotive about 4 m, freight wagon 2.8 m, wheel 0.42 to 0.55 m, grown person 1.75 m.

REPLY FORMAT
- Return only the image, then one short line: what you drew and which background you used (transparent / magenta / black). If a request is ambiguous, make your best choice and say which one in that line; do not ask more than one question.
- If I say "again", change only what I name and keep everything else identical.
```

## 2. Короткая версия (до ~1500 знаков, для Custom instructions)

```text
Role: art generator for "Лесная колея", a cozy 2D side-view narrow-gauge forest railway game. One finished image per request, ready for cut-out.
Style: hand-painted painterly 2D, warm, slightly worn, early 20th century Russian northern railway. Palette: forest green #466c51, charcoal steel #29383b, honey wood, cream #f5ecd6, aged brass #bb964f, brake red #a64d3b. Soft warm light from upper left. Strong sense of volume: bold rounded relief, deep shadows, clearly lit and shaded sides, heavy pronounced material texture, nothing flat. Vehicles, buildings, props in STRICT flat SIDE ELEVATION (no perspective, no isometric, round wheels, horizontal rails). No photorealism, 3D, pixel art, neon, plastic, people (unless asked), logos, watermarks.
Text: draw no letters or numbers unless I give exact quoted text; leave signs and labels blank.
Cut-out: one centered subject, 8% margin, nothing cropped. Real transparent PNG if possible, otherwise flat pure magenta #FF00FF background with no shadow, gradient or glow; light effects on flat pure black. No halo or fringe.
Format: only square, landscape 3:2 or portrait 2:3. Sheets: equal grid cells, one object per cell, same scale, one flat background.
With a reference image, match its style exactly. Keep recurring characters identical.
Reply: the image plus one short line (what and which background).
```

## 3. Размеры: что реально выдаёт генератор

Старые документы называют «идеальные» размеры (например 2400×1200). Генератор их не даёт: у него три формата. Просите по формату, а я увеличиваю и обрезаю. Раньше он возвращал 1254×1254, 1672×941 и подобные.

| Что рисуем | Формат | Заметки |
|---|---|---|
| Предмет, иконка, жетон, колесо, мешок, шлак | квадрат 1:1 | один предмет по центру |
| Лист мелких предметов | квадрат 1:1 | сетка 3×3, не больше 9 штук |
| Михалыч, карточка Таро, рамка карточки, афиша | вертикаль 2:3 | карточка 900×1200 это ровно 3:4, я обрежу поле |
| Фасад, интерьер, станция, фон, вывеска, гирлянда, панель, полоска | горизонталь 3:2 | важное подальше от краёв |
| Техника сбоку | горизонталь 3:2 | машина занимает ~70% ширины, рельс внизу |

Мелкую вещь не просите «в 64 px»: пусть рисует крупно, я уменьшу.

## 4. Фон и прозрачность

Именно здесь раньше появлялись красные и жёлто-зелёные ореолы по краям. Правила:

1. Сначала просите **прозрачный PNG**. ChatGPT иногда рисует «шахматку» прямо в картинке: это не прозрачность, значит фон не вырезан. Если так, просите вторым способом.
2. Второй способ: **плоский пурпурный фон #FF00FF**. В нашей палитре пурпурного нет, поэтому фон вырезается чисто, а остатки цвета на краю я вычищаю. Без тени на полу, без градиента, без свечения у границы.
3. **Свет и огонь** (свечение «занос», искры, пар, конфетти): на **чёрном** фоне, не на пурпурном. Чёрное я превращаю в прозрачность режимом «экран», свет складывается красиво.
4. **Фоны локаций** без вырезания: без рамки, на весь кадр.
5. Тень под предметом, если нужна, я рисую в игре сам. Просите без неё.

## 5. Единый стиль и «якоря»

Основа стиля: палитра, мягкий тёплый свет сверху-слева (это стандарт для новых картинок, прошлые были без жёсткого направления), вид сбоку, живопись кистью, чуть потёртая вещь. Для казика ещё: «всегда тёплый вечер, лампочки, латунь».

Чтобы картинки одной группы выглядели одной рукой, делайте **якорь**: одну картинку группы, которая вам нравится. Дальше каждый запрос группы идёт с этим файлом приложенным и фразой «in exactly the same style as the attached image».

| Группа | Якорь | Кому служит |
|---|---|---|
| Казик: предметы и интерфейс | `kazik_token.png` | колесо, кнопки, шлак, мешок, панели |
| Казик: места | `kazik_interior.png` | фасад, афиши, вывеска |
| Михалыч | `kazik_mikhalych.png` (портрет) | все эмоции |
| Карточки | `card_00_fool.png` | остальные 21 арканов |
| Техника | любая готовая из `ForestRail/assets/art_p2/…_body.png` | новая техника, вагоны, скины |
| Мир | `ForestRail/assets/art_v3/parallax/mid_forest.png` | станции, фоны, насыпь |

Михалыча и карточки нельзя делать «по одной с нуля»: лицо уплывёт. Всегда прикладывайте портрет или первую карточку и пишите «same character, same face».

## 6. Шаблоны запросов

Подставьте своё в скобках. Блок из раздела 1 уже в проекте, поэтому в запросе только суть.

**Предмет или иконка**
```text
Asset: (kazik_token). Subject: (a single brass casino token, serrated edge, stamped letter "Л" in the center, slightly worn). Format: square. Background: transparent, or magenta if you cannot. Style anchor: attached.
```

**Лист мелких предметов**
```text
Asset: (kazik_junk_sheet1). Sheet 3 by 3, square, one flat magenta background, one object per cell, same scale, wide margins, no labels. Objects: (1 rusty bolt, 2 worn ball bearing, 3 empty wooden barrel, 4 cut-off railway sleeper stub, 5 broken ceramic plate, 6 worn horseshoe, 7 bent switch fork, 8 dented lantern, 9 old rusty pocket watch).
```

**Техника сбоку**
```text
Asset: (pole_body). Subject: (a pole-pushing handcar: low wooden deck, two flanged steel wheels, a long wooden pole held in a rack). Strict flat side elevation, landscape, vehicle fills about 70% of the width, wheels touch a thin horizontal rail at the bottom. Length 2.4 m, wheel 0.42 m. Background transparent or magenta. Match the attached vehicle's style and scale.
```

**Фон или локация**
```text
Asset: (kazik_interior). Subject: (cozy interior of a tiny railway-shed casino, plank walls, long counter on the left, empty wooden stand on the right). Landscape, full-bleed scene, no characters, no text, a sign left blank. Strict flat frontal view, no perspective. Style anchor: attached.
```

**Персонаж и эмоции**
```text
Asset: (kazik_mikhalych_happy). The attached portrait is the character; keep face, moustache, vest, cap and proportions identical. Change only: (broad laugh, raised hands). Portrait, waist up, transparent or magenta background.
```

**Эффект (на чёрном)**
```text
Asset: (kazik_wheel_glow). Soft golden radial glow with tiny sparkles and faint light rays, centered, symmetrical. Square, flat pure black background.
```

**Карточка Таро**
```text
Asset: (card_10_wheel_of_fortune). Tarot illustration, portrait, painterly, no frame, no text, no numerals. Subject: (…из KAZIK_IMAGE_PROMPTS_5_RU.md…). Style anchor: attached first card.
```

## 7. Слова и буквы на картинках

Генератор плохо пишет кириллицу: буквы плывут, появляются выдуманные. Правило: **на картинках без слов**. Вывески («КАЗИК у стрелки», «ХВАТИТ»), афиши, подписи кнопок и номера карточек я ставлю в игре шрифтом. Поэтому в промтах из прошлых документов, где просили надпись, дописывайте «sign left blank, no letters»:

- `kazik_facade.png` (A1), `kazik_sign.png` (A3), афиши `kazik_poster_*.png` (G4), табличка «ХВАТИТ» в интерьере (A2), нарисованные станции и экраны из `IMAGE_PROMPTS_RU.md`.

Исключение: если очень хочется живой надписи на афише, просите точный текст в кавычках и один раз проверьте буквы; ошибка в одной букве, и картинку лучше перегенерировать.

## 8. Имена и куда класть

- Папки: `tools/art_sources/inbox/kazik/` (казик), `…/kazik/cards/` (карточки), новые группы в подпапках `inbox/vehicles/`, `inbox/world/`, `inbox/ui/` (создам по мере надобности).
- Имя файла **ровно как в промте**, строчными латиницей, с подчёркиваниями. Варианты: `_v2`, `_v3`; я выберу.
- Одна картинка, один файл. Не склеивайте разные предметы в одну картинку, кроме листов из промта.
- Формат PNG. WebP и JPG принимаю, но для прозрачности только PNG.
- Если назвали иначе, ничего страшного: напишите мне, что где лежит.

## 9. Чек-лист приёмки (проверьте до отправки мне)

1. Нет букв и цифр (кроме разрешённых). Нет подписи и водяного знака.
2. Предмет целый, не обрезан, поля ≥ 8%.
3. Фон один и плоский, без тени и пола (или прозрачный).
4. На краю предмета нет цветной каймы.
5. Ракурс: техника и здания строго сбоку, колёса круглые.
6. Предметов ровно столько, сколько просили (на листе по одному в ячейке).
7. Стиль и цвета как у якоря.
8. Лицо Михалыча то же, что на портрете.

Если один пункт не прошёл, не мучайтесь: пришлите как есть с пометкой, что не так. Я часть исправлю сам (фон, кайма, поля, размер), а стиль и ракурс исправляются только перегенерацией.

## 10. Быстрые правки одной фразой

| Что не так | Что написать |
|---|---|
| Фон не вырезан, «шахматка» | `Redo on a flat pure magenta #FF00FF background, nothing else changed.` |
| Тень или пол под предметом | `Remove the floor and the cast shadow, keep the object identical.` |
| Предмет обрезан | `Same image, but smaller: the whole object with 10% margin on every side.` |
| Буквы | `Remove all letters and numbers, leave the area blank.` |
| Перспектива, три четверти | `Redraw in strict flat side elevation, wheels perfectly round, nothing else changed.` |
| Слишком мультяшно или гладко | `Less cartoon, more hand-painted brush texture and worn edges, same composition.` |
| Лишние предметы на листе | `Exactly nine objects, one per cell, remove everything else.` |
| Не тот стиль | `Match the attached image's palette, brush texture and lighting exactly.` |
| Лицо поменялось | `Same character as the attached portrait, identical face and clothes; only the expression changes.` |
| Свечение на цветном фоне | `Redo the glow on a flat pure black background.` |

## 11. Очередь: что просить первым

**Минимум для запуска казика** (без этого экран не покажется): A1 фасад, A2 интерьер, B1 колесо, B2 флажок, C1 Михалыч, D1 жетон, E1 лист шлака. Для всего этого достаточно трёх якорей: `kazik_token`, `kazik_interior`, `kazik_mikhalych`.

**Затем** (по порядку удобства): иконки секторов (B4), эмоции Михалыча (C2), кнопки и панель (D3, D4), рамка и оборот карточки (F1, F2), три карточки для пробы вида (`card_00_fool`, `card_10_wheel_of_fortune`, `card_16_tower`), эффекты (G1, G2), остальное.

**Что понадобится позже** (запросы подготовлю, когда дойдём до этапа):

| Когда | Что рисовать |
|---|---|
| В6.1 шестовая | боковой вид платформы с шестом, человек с шестом в 4–5 позах (толчок, упор, выдёргивание) |
| В6.5 цеппелин | боковой вид с гребным колесом, закрылки, триммер |
| В6.6 реактивный | боковой вид, форсаж, раскрытые парашюты |
| В6.7 скины | перекраска ручной дрезины и вагонов (по запросу «тот же рисунок, другая краска») |
| Кабины | панели приборов каждой машины, фронтальный вид, без стрелок и подписей |
| Веха 8 | материалы: дерево, ржавое железо, ткань, камень, гравий как плоские бесшовные квадраты |

Для кабин и материалов: «seamless tileable» и без перспективы, плоским квадратом; но качество бесшовности проверю я, генератор её не гарантирует.

## 12. Что делаю я, когда получаю файлы

Вырезаю фон (пурпур, чёрный через «экран»), чищу кайму, обрезаю лишние поля, привожу к масштабу игры (128 пикселей на метр у техники и мира), нарезаю листы, при надобности исправляю цвет и контраст под ночь и дождь, подключаю, проверяю в трёх размерах окна и показываю кадры на приёмку. Если картинка не пройдёт по стилю или ракурсу, скажу прямо и дам одну фразу для перегенерации из раздела 10.
