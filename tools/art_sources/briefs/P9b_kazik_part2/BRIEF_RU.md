# Комплект П9б «Казик, часть 2»: промпты для GPT

Первая часть казика (фасад, интерьер, колесо, указатель, Михалыч, жетон, шлак, свечение) уже в игре: экран казика работает. Теперь нужны картинки, которые заменят временное: надписи на секторах колеса, остальные эмоции Михалыча, мешок, редкий шлак, рамка и оборот карточки.

## Что сейчас (кадры в этой папке)

- `ref_casino_now.jpg`: экран казика: на секторах колеса пока **текстовые подписи** («пусто», «+5», «шлак», «монеты»…), которые заменят иконки.
- `ref_mikhalych.jpg`: Михалыч (персонаж-якорь): кепка с молоточками, седые усы, зелёный жилет, бежевая рубашка, медный чайник.
- `ref_token.jpg`: жетон-шестерня с буквой «Л».
- `ref_junk_sheet.jpg`: образец листа шлака (стиль и масштаб).

Стиль тот же, с **сильным объёмом**: крупный рельеф, глубокие тени, тяжёлые материалы, тёплый свет сверху-слева.

## Что сделать

1. Новый чат. Если GPT читает репозиторий через подключение, фраза:

```
Открой в репозитории CPUadmin/ForestRail (ветка main) файл tools/art_sources/briefs/P9b_kazik_part2/TASK_FOR_GPT.md, посмотри кадры ref_* рядом с ним и выполни задание: восемь картинок по очереди.
```

2. Если картинки из репозитория он не открывает, приложите четыре файла `ref_*` из этой папки и вставьте блоки из `PROMPTS_FOR_GPT.txt`.
3. Файлы с именами из заголовков ниже сохраните в `tools/art_sources/inbox/P9b_kazik_part2/`. Я увижу их сам. Можно присылать по мере готовности.

## Картинки

### A1 `sector_icons.png`: иконки секторов колеса (лист 3×3, прозрачный фон)

```text
Attached are references for the pack "P9b kazik part 2". ref_casino_now.jpg shows the casino screen: the wheel sectors still have plain text labels that must become painted icons. ref_mikhalych.jpg is the CHARACTER (keep his face, cap with crossed hammers, grey moustache, green waistcoat, beige shirt, copper kettle exactly). ref_token.jpg is the brass token with the letter Л. ref_junk_sheet.jpg is the style and scale reference. Match the painterly look, warm worn feel, brass and green palette, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), light from the upper left. I will ask for eight images one by one.
```

```text
Asset: sector_icons. Format: square 1:1. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine icons, one per cell, centered, same scale, wide margins, no overlaps, no cell lines, no labels, no text, no numbers, no ground shadows.
Nine bold readable icons for the sectors of a casino wheel, each a single object seen straight on, hand-painted with strong volume, same style as the attached references:
1 empty: a dusty cobweb with a faded cross mark, muted grey;
2 five tokens: ONE brass serrated token with the letter Л (copy ref_token.jpg);
3 ten tokens: TWO overlapping brass serrated tokens with the letter Л;
4 junk: a small pile of rusty bolts and a worn ball bearing;
5 coins: a leather pouch spilling a few gold coins;
6 repair kit: a leather pouch with a wrench, an oil can and a roll of cloth;
7 golden bolt: one shiny golden hexagonal bolt with sparkles;
8 bonus coupon: a paper ticket with torn edges and a red stamp, no text;
9 card: a glowing playing-card-like gadget card with a golden frame and a star in the center, no text.
```
Назначение: иконки на сектора вместо слов.

### A2 `kazik_junk_sheet2.png`: редкий шлак (лист 3×3, прозрачный фон)

```text
Asset: kazik_junk_sheet2. Format: square 1:1. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family as ref_junk_sheet.jpg, wide margins, no overlaps, no cell lines, no labels, no ground shadows.
Nine pieces of rare railway junk, hand-painted with strong volume, same style as the attached references: a copper steam fitting with a pressure gauge, a shiny golden bolt with a hex nut, an old brass whistle, a cracked oil lamp, a torn leather glove, a bent crowbar, a rusty chain link, a tin cup, a fallen brass nameplate completely blank. No letters, no numbers.
```
Назначение: редкие находки для окон приёмки и итога рейса.

### A3 `kazik_junk_bag.png`: мешок шлака (квадрат, прозрачный фон)

```text
Asset: kazik_junk_bag. Format: square 1:1. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
A coarse burlap sack tied at the neck with rope, half full of rusty bolts, bearings and a horseshoe, a few pieces sticking out of the top, standing upright, strong volume, hand-painted, same style as the attached references, centered with wide margins, no ground shadow, no letters.
```

### A4 `kazik_mikhalych_happy.png`, A5 `…_sad.png`, A6 `…_surprised.png`, A7 `…_pouring.png`: эмоции Михалыча

Четыре отдельных запроса. Каждый раз тот же человек, как на `ref_mikhalych.jpg`; поменять только выражение и позу. Формат вертикаль 2:3, прозрачный фон (иначе пурпурный). Приложите `ref_mikhalych.jpg` к каждому запросу.

```text
Asset: kazik_mikhalych_happy. Format: portrait 2:3. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
The SAME man as in ref_mikhalych.jpg (identical face, cap with crossed hammers, grey moustache, green waistcoat, beige shirt, copper kettle in the left hand, same proportions, painting style, lighting and scale), waist up. Expression and pose: a broad laugh, eyes squinting with joy, the free right hand raised high in a delighted gesture. Nothing else changes. No letters, no shadows on the ground.
```

```text
Asset: kazik_mikhalych_sad. Format: portrait 2:3. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
The SAME man as in ref_mikhalych.jpg (identical face and clothes, copper kettle in the left hand, same style, lighting and scale), waist up. Expression and pose: a sympathetic frown, eyebrows raised in the middle, a small sigh, shoulders in a shrug, the free hand open palm up. Kind, not tragic. Nothing else changes. No letters.
```

```text
Asset: kazik_mikhalych_surprised. Format: portrait 2:3. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
The SAME man as in ref_mikhalych.jpg (identical face and clothes, same style, lighting and scale), waist up. Expression and pose: eyebrows high, mouth wide open in surprise, both hands flat on a counter edge in front of him, the kettle set down beside his hand (a jackpot moment). Nothing else changes. No letters.
```

```text
Asset: kazik_mikhalych_pouring. Format: portrait 2:3. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
The SAME man as in ref_mikhalych.jpg (identical face and clothes, same style, lighting and scale), waist up. Expression and pose: calm and content, eyes on the glass, pouring tea from the copper kettle into a glass in a brass holder held in his other hand, a thin curl of steam. Nothing else changes. No letters.
```

### A8 `kazik_card_frame.png`: рамка карточки (вертикаль 2:3, прозрачный фон)

```text
Asset: kazik_card_frame. Format: portrait 2:3. Background: transparent PNG if you can, otherwise flat pure magenta #FF00FF.
An empty collectible gadget card frame, aged brass and dark green enamel, heavy rounded relief and rivets, rounded corners, a big empty illustration window in the upper two thirds (transparent or magenta inside, completely empty), a title banner on top, a description area at the bottom, a row of small stars near the top corner, strong volume, centered with margins, the same style as the attached references. No text, no numbers, nothing inside the window.
```
Назначение: рамка карточек гаджетов (иллюстрации Таро вставляются в окно).

## Чек-лист приёмки пакета

1. Нет букв и цифр (на иконках, жетонах, монетах, табличке).
2. Листы: ровно девять предметов по одному в ячейке, на прозрачном (или пурпурном) фоне.
3. **Эмоции:** тот же человек: кепка с молоточками, усы, жилет, чайник; меняется только лицо и поза.
4. У рамки пустое окно без рисунка.
5. Объём, стиль и свет как у образцов. Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10.

## Что делаю я после получения

Принимаю, подключаю иконки на сектора колеса, эмоции Михалыча по ходу (выигрыш, пусто, занос, наливает чай), мешок и редкий шлак в окна приёмки, итога рейса и казика, рамку для альбома карточек.
