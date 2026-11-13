# Промты картинок КАЗИКа, часть 2: связка с рейсами (дополнение к `KAZIK_IMAGE_PROMPTS_RU.md`)

Добавляйте к каждому промту **общую приписку стиля** из раздела 1 первой части. Складывайте в `tools/art_sources/inbox/kazik/`.

## I. Бонуски (талончики), каждая 600×360, прозрачный фон
- `bonus_spin.png`: `a paper coupon ticket with a torn edge, hand-stamped with a small roulette wheel and the words "ХАЛЯВНАЯ КРУТКА", warm cream paper, red and green stamp`
- `bonus_x2.png`: `a paper coupon with a big hand-painted "×2" and the words "ИКСЫ НА СТАВКУ", worn corners`
- `bonus_junk.png`: `a paper coupon with a small drawing of a sack of rusty bolts and the words "ШЛАК В МЕШОК"`
- `bonus_tea.png`: `a paper coupon with a steaming kettle and the words "ЧАЙКУ!"`
- `bonus_locked.png`: `a paper coupon wrapped with a small brass padlock and the words "С ОТЫГРЫШЕМ", three small circles to be filled`

## J. Ставка и иксы, прозрачный фон
- `stake_chips.png`, 512×512: `a small stack of three brass tokens with serrated edges next to a small paper tag, a reddish wax seal`
- `stake_x15.png`, `stake_x3.png`, `stake_x4.png`, `stake_x5.png`, каждый 300×300: `a round brass badge with a big hand-painted multiplier "×1,5" (and "×3", "×4", "×5" respectively), worn brass rim`
- `stake_panel.png`, 1200×600: `a small wooden notice-board frame with brass corners, the heading "ДЕП НА РЕЙС", three empty slots for tokens, space for an odds table, no other text`

## K. Состояния и значки
- `icon_streak.png`, 256×256: `a small flame icon in warm orange and gold on a brass disc, "series" icon, readable at 48 pixels`
- `icon_tilt.png`, 256×256: `a small dark rain cloud icon on a brass disc with a tiny lightning, calm look, readable at 48 pixels`
- `stamp_slive.png`, 800×400: `a round rubber stamp mark in faded blue ink with the word "СЛИВ" and a tilted border, worn, calm`
- `banner_zanos.png`, 1600×500: `a festive ribbon banner in red and gold with big hand-painted letters "ЗАНОС!", small stars, confetti, aged paper edge`
- `banner_rovno.png`, 1200×400: `a modest cream ribbon banner with brass border and the word "РОВНО", simple, calm`

## L. Дорога
- `glint_junk.png`, 512×512: `a small sparkling brass glint on the rail side gravel, a tiny star shape with soft light rays, easy to notice but subtle`
- `glint_golden.png`, 512×512: `a bigger golden glint with warm rays, a rare treasure sparkle on gravel`

## M. Анимационные кадры (по желанию)
Нужны **ряды кадров** (спрайт-листы: одна строка, одинаковый размер, прозрачный фон):
- `anim_mikhalych_blink.png`: 4 кадра моргания (открыты, прищур, закрыты, прищур), 800×1000 каждый.
- `anim_mikhalych_pour.png`: 6 кадров наливания чая (наклон чайника, струя, стакан наполняется).
- `anim_kettle_steam.png`: 8 кадров пара над чайником, 256×256.
- `anim_wheel_flash.png`: 6 кадров световой вспышки на колесе при заносе, 800×800.
- `anim_card_flip.png`: 7 кадров переворота карточки (рубашка, ребро, лицо), 500×700.

Если анимационные листы генератору не даются, **не страшно**: я сделаю анимации в коде (раскрутка, мерцание, полёт жетонов, переворот карточки, дыхание, моргание) из одиночных картинок.

## Минимум для первого запуска связки
`stake_chips.png`, `stake_x3.png`, `bonus_spin.png`, `icon_streak.png`, `banner_zanos.png`, `glint_junk.png`.
