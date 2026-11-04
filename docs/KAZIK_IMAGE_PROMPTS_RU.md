# Промты для картинок КАЗИКа (для генерации владельцем)

Идея и правила игры: `KAZIK_RU.md`. Здесь только то, что нужно нарисовать. Генерируете вы, я привожу картинки к стандарту игры (нарезаю, вырезаю фон, подгоняю размер и свет) и подключаю.

**Сначала прочтите `GPT_ART_BRIEF_RU.md`**: там инструкция для GPT (вставляется один раз), реальные форматы генератора (квадрат, 3:2, 2:3), чистый фон (прозрачный, пурпурный #FF00FF или чёрный для света), «якоря» стиля, и правка: **надписи на картинках не просите**, текст ставлю я в игре (вывеска, афиши, таблички оставлять пустыми). Размеры в пикселях ниже ориентировочные; просите по формату, увеличиваю я.

## 0. Как пользоваться

1. Берёте промт ниже, подставляете в **общую приписку стиля** (раздел 1) и генерируете.
2. Складываете файлы в `tools/art_sources/inbox/kazik/` с **тем именем, что указано** (например `kazik_wheel.png`). Если генератор выдал несколько вариантов, добавляйте номер: `kazik_wheel_v2.png`; я выберу.
3. Если картинка получилась с фоном, это не страшно: я вырежу. Если получилась не та пропорция, тоже не беда, но лучше держать указанную.
4. Минимум для первого запуска (без этого казик не покажется): пункты **A1, A2, B1, B2, C1, D1, E1**. Остальное добавляется по мере удобства.
5. Один промт можно прогонять несколько раз. Лучше **8–10 разных шлаков одним листом** (раздел E), я сам разрежу.

## 1. Общая приписка стиля (добавлять к каждому промту)

> hand-painted 2D game art, warm and slightly worn, painterly brush texture, narrow-gauge forest railway in the Russian north, early 20th century, dark pine green, aged brass and copper, warm amber lamplight, soft rim light, muted earthy palette, no text unless stated, clean readable silhouette, consistent with a cozy indie game, no photorealism, no 3D render

**Для предметов и интерфейса** добавляйте: `isolated on a plain flat background, centered, even margins, no cast shadow outside the object`.

**Для интерьеров и вывесок** добавляйте: `side view, flat orthographic composition, no perspective distortion, game background`.

**Чего избегать (добавлять как negative):** `photo, watermark, signature, blurry, extra fingers, random letters, logo, modern objects, neon, glossy plastic, realistic casino chips with real brand names`.

## 2. Список картинок

Таблица: **файл → размер → промт**. Размеры указаны ориентировочные (в пикселях, в 2× от игровых), чтобы потом не терять качество.

### A. Вход и сцена

**A1. `kazik_facade.png`, 1800×900, фон прозрачный не нужен.** Фасад казино на заброшенном разъезде.
> A tiny shabby casino built into an old wooden railway shed at a forest siding, a hand-painted sign above the door reading "КАЗИК у стрелки", warm yellow bulbs strung along the roof edge, a wooden door with a brass handle, a small steaming kettle on the porch, rusty rail switch lever in front, pine trees behind, dusk light

**A2. `kazik_interior.png`, 2400×1200.** Интерьер (фон сцены).
> Cozy interior of a tiny railway-shed casino: wooden plank walls, a long counter on the left with a brass kettle and a stack of tokens, a big round roulette wheel stand on the right with empty space in front of it, hanging lamps with warm light, shelves with rusty bolts, bearings and lanterns, a faded poster, a tin sign "ХВАТИТ" near the exit door, worn floor planks, warm amber atmosphere, no characters, no wheel drawn on the stand (empty wooden stand with a mount)

**A3. `kazik_sign.png`, 1200×360, прозрачный фон.** Вывеска.
> A hand-painted wooden sign with brass border, big carved letters "КАЗИК", smaller line "у стрелки", a small roulette wheel icon in the corner, chipped paint, bulbs around the edge, isolated on a plain flat background

**A4. `kazik_door_icon.png`, 256×256, прозрачный фон.** Иконка вкладки в депо (стиль как у «Гараж», «Состав», «Мастерская»).
> A simple flat icon, a roulette wheel with a small flag pointer on top, brass and dark green, thick clean outline, readable at 64 pixels, isolated on a plain flat background

### B. Колесо «лудка»

**B1. `kazik_wheel.png`, 1600×1600, прозрачный фон.** Колесо без секторных картинок (сектора рисуются в игре поверх, я их вставлю) или с пустыми секторами.
> A front-view antique wooden roulette wheel with a thick aged brass rim and brass studs, 24 equal empty wedge sectors painted in alternating dark green and deep burgundy, a brass hub in the center with a small crank handle, worn wood grain, a bit of rust on the rim, centered, completely symmetrical, no numbers, no text, isolated on a plain flat background

**B2. `kazik_wheel_pointer.png`, 300×300, прозрачный фон.** Стрелка-флажок сверху.
> A small brass flag-shaped pointer for a roulette wheel pointing down, a tiny red pennant on a short brass pole, worn metal, isolated on a plain flat background

**B3. `kazik_wheel_glow.png`, 1800×1800, прозрачный фон.** Свечение занос.
> A soft golden radial glow with tiny sparkles and faint light rays, transparent-looking, additive light effect, centered, isolated on a plain flat background

**B4. Иконки секторов** (каждая 256×256, прозрачный фон, рисуются в игре на сектор):
- `sector_empty.png`: `a small dusty cobweb and a faded cross mark, muted grey`
- `sector_token1.png`: `a single brass token coin with a serrated edge and the letter Л`
- `sector_token2.png`: `two overlapping brass tokens with serrated edges and the letter Л`
- `sector_junk.png`: `a small pile of rusty bolts and a worn bearing`
- `sector_coins.png`: `a small pouch of gold coins spilling a few coins`
- `sector_repair.png`: `a small repair kit: wrench, oil can, a roll of cloth in a leather pouch`
- `sector_golden_bolt.png`: `a single shiny golden bolt with a hex nut, sparkles around it`
- `sector_card.png`: `a glowing playing-card-like gadget card with a golden frame and a star in the center`

### C. Михалыч (крупье)

**C1. `kazik_mikhalych.png`, 1200×1600, прозрачный фон.** Полный рост за стойкой (по пояс). Нужны эмоции отдельными вариантами (C2).
> A friendly middle-aged railway-casino croupier named Mikhalych, round face, thick grey moustache, wrinkled vest over a rolled-sleeve shirt, a brass pocket watch chain, an old railwayman cap pushed back, holding a small tin kettle, warm smile with a squint, behind a wooden counter, waist up, portrait pose, neutral smile

**C2. Эмоции (каждая 800×1000, прозрачный фон):** тот же персонаж, поменять выражение и позу:
- `kazik_mikhalych_happy.png`: `broad laugh, raised hands, delighted`
- `kazik_mikhalych_sad.png`: `sympathetic frown, shrugging, small sigh`
- `kazik_mikhalych_surprised.png`: `eyebrows up, mouth open, hands on the counter (a jackpot)`
- `kazik_mikhalych_thinking.png`: `holding his chin, looking aside, a thought bubble not needed`
- `kazik_mikhalych_pouring.png`: `pouring tea from the kettle into a glass in a brass holder, calm`

### D. Жетон и интерфейс

**D1. `kazik_token.png`, 512×512, прозрачный фон.** Жетон.
> A single brass casino token for a railway game, serrated edge, a stamped letter "Л" in the center, small wheel icon around, slightly worn, front view, isolated on a plain flat background

**D2. `kazik_token_stack.png`, 512×512, прозрачный фон.** Стопка жетонов (для счётчика).
> A neat stack of six brass tokens with serrated edges, slightly tilted, isolated on a plain flat background

**D3. `kazik_panel.png`, 1600×300.** Нижняя панель (рамка).
> A horizontal wooden panel with brass corners and rivets, dark green felt-like inner area, space for text and buttons, a thin gold border, worn edges, flat front view, no text

**D4. Кнопки** (каждая 512×160, прозрачный фон, 3 состояния: обычная, нажатая, выключенная; можно одним листом):
- `kazik_button_spin.png`: `a big wooden button with a brass frame and a small curved arrow icon (spin)`
- `kazik_button_stop.png`: `a smaller dark button with a brass frame and an exit-door icon (stop)`
- `kazik_button_dep.png`: `a button with a brass frame and an icon of a sack being emptied (deposit junk)`
- `kazik_button_album.png`: `a button with a brass frame and an icon of an open album of cards`

**D5. `kazik_pity_bar.png`, 800×80.** Полоска «до заноса».
> A horizontal progress bar frame in aged brass with an empty dark inner channel and a small golden star at the right end, flat front view, no fill, isolated on a plain flat background

### E. Шлак (листы)

**E1. `kazik_junk_sheet1.png`, 2048×2048.** Лист предметов (я разрежу на 3×3 ячейки по 640 px):
> A sprite sheet of nine separate pieces of rusty railway junk on a plain flat background in a 3 by 3 grid, evenly spaced, each isolated: a rusty bolt, a worn ball bearing, an empty wooden barrel, a short cut-off railway sleeper stub, a broken ceramic plate, a worn horseshoe, a bent switch fork, a dented lantern, an old rusty pocket watch

**E2. `kazik_junk_sheet2.png`, 2048×2048.** Редкий шлак:
> A sprite sheet of nine separate pieces of rare junk on a plain flat background in a 3 by 3 grid, evenly spaced, each isolated: a copper steam fitting, a shiny golden bolt, an old brass whistle, a cracked oil lamp, a torn leather glove, a bent crowbar, a rusty chain link, a tin cup, a fallen brass nameplate with no text

**E3. `kazik_junk_bag.png`, 512×512, прозрачный фон.** Мешок шлака.
> A coarse burlap sack tied with rope, half full of rusty bolts and bearings, a few pieces sticking out, isolated on a plain flat background

### F. Карточки гаджетов

**F1. `kazik_card_frame.png`, 1000×1400, прозрачный фон.** Рамка карточки (пустая):
> An ornate collectible gadget card frame, aged brass and dark green, rounded corners, an empty central illustration window, a title banner on top, a description area at the bottom, a small star row near the top corner for rarity, flat front view, no text, no illustration inside the window

**F2. `kazik_card_back.png`, 1000×1400, прозрачный фон.** Оборот карточки:
> The back of a collectible card, dark green with a brass border and a central wheel emblem, a faint pattern of rails and bolts, flat front view

**F3. Иллюстрации гаджетов** (каждая 900×900, прозрачный фон, для окна карточки; по одной на гаджет):

Парусная: 
- `gadget_spinnaker.png`: `a huge balloon-shaped sail on a small rail trolley, billowing tail wind, bright cream and red stripes`
- `gadget_autopilot.png`: `a weather vane on a mast connected by thin brass rods and a pulley to a sail boom, a tiny gear box`

Паровоз:
- `gadget_superheater.png`: `a copper superheater boiler tube bundle with steam pipes and a pressure gauge`
- `gadget_stoker.png`: `a mechanical stoker: a screw conveyor feeding coal into a firebox door, belts and gears`

Электровоз:
- `gadget_supercap.png`: `a bank of large cylindrical supercapacitors with blue lightning arcs and brass terminals`
- `gadget_cooling.png`: `a liquid cooling radiator with copper pipes and a small fan on an electric motor`

Бензиновая:
- `gadget_nitro.png`: `a nitrous oxide tank with a brass valve and flame bursting from an exhaust pipe`
- `gadget_automatic.png`: `an automatic gearbox selector lever with the letters P R N D on a brass plate`

Пневматический:
- `gadget_airtank.png`: `a spare big air cylinder bolted under a pneumatic train frame with a pressure gauge`
- `gadget_reducer.png`: `an automatic pressure reducer valve with a dial and a brass wheel, pipes`

Ручная:
- `gadget_flywheel.png`: `a heavy flywheel on the axle of a handcar with a small lever`
- `gadget_ratchet.png`: `a ratchet pump lever with a toothed brass wheel on a handcar`

Шестовая:
- `gadget_pogo.png`: `a spring-loaded pole with a coil spring and a rubber foot, like a pogo stick`
- `gadget_grapnel.png`: `a grappling hook on a long rope, coiled on a winch drum, a lasso loop in the air`

Цеппелин (когда дойдём): `gadget_flaps.png` (`wing flaps on a propeller-driven rail zeppelin`), `gadget_trim.png` (`a trim wheel with an altimeter`).
Реактивный: `gadget_afterburner.png` (`a jet engine afterburner with a long flame`), `gadget_double_chute.png` (`two parachutes deployed behind a jet train`).

### G. Эффекты и мелочи

**G1. `kazik_confetti.png`, 1024×1024, прозрачный фон.** Конфетти для заноса:
> Small colorful paper confetti bits and tiny golden stars scattered in a burst, transparent-looking, isolated on a plain flat background

**G2. `kazik_coin_burst.png`, 1024×1024, прозрачный фон.** Звон монет:
> A burst of gold coins and brass tokens flying out in an arc, motion lines, isolated on a plain flat background

**G3. `kazik_lamp_string.png`, 1600×200, прозрачный фон.** Гирлянда ламп (мигает в игре):
> A string of round warm yellow bulbs on a dark wire between two hooks, a few bulbs lit and a few unlit, isolated on a plain flat background

**G4. `kazik_poster_*.png`, 600×900, 3 штуки.** Афиши на стене (шутливые):
> A faded wall poster in Russian forest-railway style, big hand-lettered headline "КРУТИ — НЕ ТОРМОЗИ" (poster 1), "ШЛАК — ЭТО ТОЖЕ ДЕНЬГИ" (poster 2), "ПОКА ЧАЙНИК ГОРЯЧ" (poster 3), a small simple illustration of a wheel, a bolt and a kettle respectively

**G5. `kazik_kettle.png`, 400×400, прозрачный фон.** Чайник (персонаж фона):
> An old dented tin kettle with a tiny puff of steam, brass handle, isolated on a plain flat background

### H. Звук (если захотите генерировать)

Это не картинки, но если вы делаете звуки:
- `kazik_wheel_ratchet`: щелчки трещотки по кругу, замедляющиеся (3 секунды).
- `kazik_win`: короткая фанфара аккордеона (1,5 секунды).
- `kazik_lose`: тихий «пшик» (0,8 секунды).
- `kazik_deposit`: звон хлама в мешке (1 секунда).

## 3. Что я сделаю с картинками

1. Положу в `tools/art_sources/inbox/kazik/`, вырежу фон, приведу к размерам игры (стандарт 128 пикселей на метр; кнопки и интерфейс по масштабам окна).
2. Подберу яркость и контраст под игру (ночной режим, дождь не применяются в казике; казик всегда «тёплый вечер»).
3. Подключу в сцену казика, нарежу листы шлака и вставлю иконки секторов в колесо.
4. Проверю в трёх размерах окна, подписи и кнопки, «меньше движения» (лампочки не мигают).
5. Покажу вам кадры для приёмки.

## 4. Приёмка картинок (вам)

- **Точно обязательные:** A1, A2, B1, B2, C1, D1, E1.
- **Красиво, но потом:** остальное.
- Если стиль не подошёл (слишком мультяшно, слишком гладко), скажите, перепишу приписку стиля.
- Если хотите единый художественный стиль со старыми картинками игры, пришлите мне 2–3 картинки, которые вам нравятся больше всего из уже сгенерированных, и я подгоню приписку под них.
