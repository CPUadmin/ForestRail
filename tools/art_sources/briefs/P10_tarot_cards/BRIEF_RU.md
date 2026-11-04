# Комплект П10 «Карточки Таро Михалыча»: промпты для GPT

22 иллюстрации: 18 карточек гаджетов (старшие арканы 0-XVII, привязка к гаджетам в `docs/KAZIK_CARDS_RU.md`) и 4 тайных арканов-трофея (XVIII-XXI). Рамка у всех одна (`kazik_card_frame.png`, уже в игре): вы рисуете только **картинку в окошко**, без рамки, цифр и названий. Рамку, римскую цифру, название и реплику Михалыча добавляю я кодом.

## Решение владельца 04.11.2026 (стиль карточек)

**Картины в стиле оригами** (сцены, сложенные из бумаги, по образцам оригами и бумажных диорам из интернета), **но каждая картина намекает на бафф** гаджета: пружина у пого-шеста, парашюты у «двойного парашюта», синее пламя у закиси азота. Намёк только картинкой, без слов и цифр. Тёплое латунно-зелёное оформление остаётся за рамкой, а внутри бумага (крафт, кремовый, зелёный, золотая фольга), контраст рамки и бумаги нам подходит.

## Как они будут выглядеть в игре

Карточка похожа на **билет Михалыча**: латунно-зелёная рамка (`ref_card_frame.jpg`), бумажная иллюстрация в большом окне, сверху лента с римской цифрой, снизу табличка с названием гаджета и репликой Михалыча. Окно почти квадратное, поэтому картины **квадратные 1:1**, важное держать в центре (края закроет рамка и скруглённые углы окна).

## Что приложить к первому сообщению

- `ref_card_frame.jpg`: рамка карточки (только понять композицию, её не рисовать).
- `ref_mikhalych.jpg`: Михалыч (его фигура на картинках не нужна, только настроение и цвета).
- `ref_style_handcar.jpg` и `ref_style_steam.jpg`: **только форма и пропорции** наших машин (дрезина, паровоз). Рисовать их нужно как бумажные модели, а не живописью.

## Как работать

1. Сначала GPT может просмотреть в интернете оригами и бумажные диорамы (paper craft dioramas, origami sculptures, kirigami) для вдохновения, в блоке 0 это сказано.
2. **Один новый чат на 6 карточек** (A19-A22 последним), в каждом сначала блок 0. Или одно задание агенту из `tools/art_sources/ART_QUEUE.md`.
3. Файлы с именами из заголовков сохраните в `tools/art_sources/inbox/P10_tarot_cards/`. Минимум для пробы вида: A1 (Шут), A11 (Колесо Фортуны), A17 (Башня).

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P10 tarot cards". ref_card_frame.jpg is the empty brass and green card frame that will go over the picture: do NOT draw it and do NOT draw any border. ref_mikhalych.jpg is a character reference for mood and colours only. ref_style_handcar.jpg and ref_style_steam.jpg show only the SHAPE and proportions of our rail vehicles; rebuild them as folded paper models, not as paintings. First, if you can browse the web, look at a few origami sculptures and layered paper-craft dioramas for inspiration (crisp creases, folded facets, paper fibre, shadows between paper layers). Then I will ask for tarot card illustrations one by one. Each is a classic Rider-Waite major arcana scene re-dressed as a narrow-gauge forest railway story and built entirely from folded and cut paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), painted-looking edge to edge as a full square picture (no transparent background), STRONG VOLUME, soft warm light from the upper left, one strong readable central figure, important things inside the central 70 percent. Every card also carries a small visual HINT of the BUFF of its gadget (for example a coiled spring, parachutes, a blue flame), shown only as objects, never as words. No letters, no numbers, no text anywhere.
```

### A1 `card_00_fool.png`: 0 Шут (Пого-шест)

```text
Asset: card_00_fool. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A carefree paper traveller with a small bundle on a stick, stepping off the end of a broken rail track while holding a pogo pole, a small paper dog at his heels, forest cliff, bright morning.
BUFF HINT, higher jumps: the pogo pole ends in a big coiled paper spring, small upward chevrons and a puff of paper dust under it.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A2 `card_01_magician.png`: I Маг (Механический кочегар)

```text
Asset: card_01_magician. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper magician in a green vest at a coal-fired locomotive firebox, one hand up toward sparks, one hand pointing down at the coal, an infinity symbol made of folded steam above his head.
BUFF HINT, coal feeds itself: a paper screw conveyor carries black coal into the firebox on its own, a steady bright flame, a trail of little sparkles.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A3 `card_02_priestess.png`: II Верховная жрица (Флюгер-автопилот)

```text
Asset: card_02_priestess. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A calm paper woman in a long coat sitting between two pillars made of a signal post and a mast, a small sail rail trolley behind her.
BUFF HINT, it holds the course by itself: a big paper weather vane above her points the way, ribbons of wind curve along one steady direction.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A4 `card_03_empress.png`: III Императрица (Запасной баллон)

```text
Asset: card_03_empress. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A crowned paper woman sitting on a mossy bench among forest greenery, a pneumatic rail train behind her, wheat ears and ferns.
BUFF HINT, more air in reserve: a throne of large brass air cylinders, a spare cylinder glowing, a full pressure gauge.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A5 `card_04_emperor.png`: IV Император (Автоматическая КПП)

```text
Asset: card_04_emperor. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A stern bearded paper man on a stone throne with a gearshift lever as his sceptre, an old petrol rail car behind him, mountains, a red cloak.
BUFF HINT, the box shifts gears by itself: neat meshing gears around the throne, the lever moves on its own, tidy order.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A6 `card_05_hierophant.png`: V Иерофант (Автоматический редуктор)

```text
Asset: card_05_hierophant. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A robed paper official seated between two columns raising two fingers, two junior engineers kneeling before a brass pressure reducer wheel.
BUFF HINT, steady pressure: a pressure dial like a halo behind his head with its needle calm in the green zone.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A7 `card_06_lovers.png`: VI Влюблённые (Храповик)

```text
Asset: card_06_lovers. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: Two paper figures at a fork of railway tracks beneath a bright sun, an angel-like signalman raising his hands above, forest paths.
BUFF HINT, pull both ways without losing ground: a handcar lever between them with a big ratchet gear and a pawl, arrows folded in both directions.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A8 `card_07_chariot.png`: VII Колесница (Суперконденсатор)

```text
Asset: card_07_chariot. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A determined paper driver on a small electric rail cart like a chariot pulled by two sphinx-like locomotives, one black one white, a starry canopy.
BUFF HINT, a burst of speed from stored charge: paper capacitors storing lightning, a bolt of lightning leaping forward, speed lines.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A9 `card_08_strength.png`: VIII Сила (Закись азота)

```text
Asset: card_08_strength. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper woman gently holding open the hood of a lion-like petrol engine, an infinity symbol above her.
BUFF HINT, a short powerful boost: a blue and orange nitro flame bursting from the exhaust, speed streaks, a small nitro bottle.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A10 `card_09_hermit.png`: IX Отшельник (Триммер)

```text
Asset: card_09_hermit. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: An old hooded paper man on a high rail embankment holding a lantern, a small propeller-driven rail zeppelin floating behind him, snow and a starry sky.
BUFF HINT, fine tuning: a small trim wheel in his other hand, a level balance bubble, a calm steady lantern glow.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A11 `card_10_wheel_of_fortune.png`: X Колесо Фортуны (Маховик-накопитель)

```text
Asset: card_10_wheel_of_fortune. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A great paper wheel with spokes carrying small icons of gears, bolts and coins, four winged creatures in the corners (a lion, an eagle, an ox and a man, all in brass-gold paper), a sphinx on top, clouds.
BUFF HINT, stored motion: the wheel is a heavy flywheel, circular motion arrows, a glowing energy ring running around its rim.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A12 `card_11_justice.png`: XI Справедливость (Жидкостное охлаждение)

```text
Asset: card_11_justice. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A crowned paper judge sitting between two pillars holding scales, a purple curtain, a motor behind.
BUFF HINT, a cool motor: one scale pan holds a small flame, the other a blue ice crystal, a copper radiator with blue coolant pipes and frost droplets.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A13 `card_12_hanged_man.png`: XII Повешенный (Кошка с лебёдкой)

```text
Asset: card_12_hanged_man. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A calm paper man hanging upside down by one foot from a rope, hands behind his back, a halo of warm light, a forest wall.
BUFF HINT, pulls himself up: a grappling hook caught on a wooden post, a taut rope, a winch drum below.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A14 `card_13_death.png`: XIII Смерть (Двойной парашют)

```text
Asset: card_13_death. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper skeleton in black armour riding a white horse beside a railway, a rising sun between two towers, small figures bowing; dramatic but friendly, not scary.
BUFF HINT, a soft stop: two big paper parachutes opening behind a small jet train.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A15 `card_14_temperance.png`: XIV Умеренность (Пароперегреватель)

```text
Asset: card_14_temperance. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper angel pouring steam from one cup into another, one foot on the shore and one in the water, a locomotive boiler behind, a path to a bright sun.
BUFF HINT, more steam from less coal: a copper superheater coil of pipes wrapped around the boiler, a few coals and a lot of folded steam.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A16 `card_15_devil.png`: XV Дьявол (Форсаж)

```text
Asset: card_15_devil. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A horned paper figure on a pedestal above two chained figures, red glow, chains made of rails; tempting and theatrical, not scary.
BUFF HINT, extra thrust: a jet engine afterburner flame between his hands, a very long fiery tail, speed lines.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A17 `card_16_tower.png`: XVI Башня (Спинакер)

```text
Asset: card_16_tower. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A tall old railway water tower struck by lightning at night, two paper figures falling, flames in the windows, a dark stormy sky.
BUFF HINT, a giant sail catches wind: a huge balloon-shaped spinnaker sail billowing full of wind and flying away from the top.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A18 `card_17_star.png`: XVII Звезда (Закрылки)

```text
Asset: card_17_star. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper woman kneeling by a pond pouring water from two jugs, one large eight-pointed star above and seven smaller ones, a bird in a tree, modest clothing.
BUFF HINT, lift in the air: a rail zeppelin on the horizon with wing flaps tilted up, curved air currents lifting it.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A19 `card_18_moon.png`: XVIII Луна (тайная)

```text
Asset: card_18_moon. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A full paper moon between two railway towers, a dog and a wolf howling on the track, a crayfish crawling out of a pond, a path of rails vanishing into the night.
HINT, a night reward: a little lantern glow on the cab of a tiny rail trolley.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A20 `card_19_sun.png`: XIX Солнце (тайная)

```text
Asset: card_19_sun. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A smiling paper sun above a brick wall, a child on a toy handcar waving a banner, sunflowers, a white horse.
HINT, an even calm run: a perfectly straight bright rail beneath the sun.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A21 `card_20_judgement.png`: XX Суд (тайная)

```text
Asset: card_20_judgement. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A paper angel with a locomotive whistle in place of a trumpet, people rising from railway carriages on a snowy plain, a flag with a wheel emblem, modest clothing.
HINT, the verdict is in: nine small gold stars floating above the carriages.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

### A22 `card_21_world.png`: XXI Мир (тайная)

```text
Asset: card_21_world. Format: square 1:1. Background: none, a complete paper diorama scene edge to edge.
Scene: A dancing paper figure in robes inside a large laurel wreath shaped like a wheel, four corner figures in a lion, eagle, ox and man made of brass-gold paper.
HINT, the deck is complete: a small copper kettle at her feet (the croupier's kettle) and a closed paper ticket booth behind.
ORIGAMI PAPER-CRAFT look: every figure, vehicle and object is folded and cut from textured paper (kraft brown, cream, forest green, brass-gold foil paper, a little red), crisp sharp creases, visible fold facets and paper fibre, small cast shadows between paper layers like a layered paper diorama, STRONG VOLUME, soft warm light from the upper left, a classic Rider-Waite tarot scene re-dressed as a narrow-gauge forest railway story, one strong readable central figure in the middle, the whole scene made edge to edge (no transparency, no border, no frame), square 1:1, keep everything important inside the central 70 percent because a card frame will cover the edges, no letters, no numbers, no text.
```

## Чек-лист приёмки пакета

1. Нет букв, цифр и надписей.
2. Нет рамки и бордюра по краям: только сцена.
3. Видно оригами: складки, грани, бумажная фактура, тени между слоями (а не живопись).
4. Главная фигура в центре, сцена узнаётся как классический аркан.
5. **Намёк на бафф читается** (пружина, парашюты, пламя, молния и т. п.) и не заслоняет фигуру.
6. Все 22 в одном стиле и одной палитре.
7. Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10.

## Что делаю я после получения

Принимаю, привожу к размеру окна рамки, ставлю в рамку с цифрой, названием гаджета и репликой Михалыча; собираю альбом карточек (22 места, невыбитые рубашкой вверх) и выдачу карточки из колеса с анимацией.
