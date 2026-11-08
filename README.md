# SlimARK-UI

A slim World of Warcraft UI for Retail (Midnight, 12.x) and WoW Forever, built from scratch on oUF. It follows the look of ElvUI and LuckyoneUI without the pile of extras.

It is drawn for 2560×1600 and fits itself to any screen: on 1080p, 1440p, ultrawide and 4K it scales with the screen height, screen-edge elements stay at their edge and everything around the character stays in the middle. Every position lives in `SlimARK-UI/Config.lua`, in pixels of the 2560×1600 layout.

## Layouts

The layout follows your spec. Boxes show real positions and sizes on a 2560×1600 screen.

**DPS and tank**

![DPS and tank layout](assets/layout-dps-tank.png)

**Healer**

The group grid sits right above the action bars. A party takes one row, a raid grows upward with five frames in each row.

![Healer layout](assets/layout-healer.png)

## What's included

- Settings panel (`/slimark`, the SlimARK icon on the top bar, or Options > AddOns): every element's position, size, font, colors and on/off switch, with a reset per value, per page or for everything
- Unit frames, party and raid frames, boss frames
- Two layouts that switch with your spec: DPS and tank share one, healers get a grid of group frames above the action bars
- Party frames next to your character; party, raid and healer frames show role icons, defensive cooldowns with time left, debuffs, and a colored border when you can dispel
- Nameplates: name and health inside the plate, highlighted target, casters marked before they cast, important casts in magenta, shows who interrupted a cast and who targets the mob
- Cooldown bars with each spec's own cooldowns for all 13 classes, and a rotation icon row; while a spell's effect is up, like the wings, its bar counts the effect down first
- Active trinket and potion effects as icons with a gold countdown above the cooldown bars (above the player frame for healers), both trinkets and your potion
- Class power for every class: runes, combo points, holy power, essence, soul shards, chi, arcane charges, icicles, Maelstrom Weapon and more
- Buffs and debuffs with the time left under each icon
- Shields (damage absorbs) in light stripes on every unit frame and nameplate, enemy shields too
- Compact Mythic+ panel: timer with +3 and +2 marks, enemy forces to two decimals, boss kill times
- Keystone: goes into the Font of Power by itself, your new keystone is posted to the party after a run
- Hides the red combat error spam (range, facing, line of sight, target, moving, mana) and its voice
- Flat tooltip: class or quality color stripe, thin health bar, Mythic+ rating, item level and target of players
- Loot rolls and pop-ups in one flat column left of your character
- Marker bar in groups: target and ground markers, ready check and pull countdown
- Ready check window that shows your missing flask, food, rune, oil and class buffs, with a button to use them
- Group Finder: role checks accepted with your spec's role, one click on a premade listing signs you up
- Skips cinematics you have already seen
- Consumable bar: flasks, potions, food and weapon oils
- Vendor with two pages, automatic repair
- Character sheet: item level, gems, enchants and what is missing
- Top bar on the top row: micro menu, durability, FPS, latency, queue time, tracked currencies, clock, gold, item level, keystone with one-click dungeon teleports, Great Vault, auto quest switch and the addon icons
- Auto quest: accepts and turns in quests, stops at a reward choice, Shift pauses it
- Test mode (`/slimark test`): made-up party, raid 20, raid 40 or Mythic+ players fill the frames, so you see the layout without a group
- Flat action buttons: gold edge for procs, red, blue or grey icons when a spell is out of range, short of its resource or not usable, short hotkeys, large cooldown numbers, and the upper bars fade out of combat
- Square minimap with large coordinates at its bottom
- Quest tracker skin
- Skins for Details!, DBM, BigWigs, Chattynator (flat tabs) and BetterBags (classic bags and BetterBags Next)
- An Edit Mode layout that puts every Blizzard element in place

It never overwrites your existing profiles or layouts. It creates new ones named `SlimARK-UI` and `SlimARK-UI Heal` next to them. For BetterBags it only selects the SlimARK theme, which you can change back in BetterBags' theme menu.

## Installation

1. Download the zip from the [Releases](https://github.com/tenarkhq/SlimARK-UI/releases) page.
2. Extract it into `World of Warcraft/_retail_/Interface/AddOns` (for WoW Forever: the `Interface/AddOns` folder of the Forever client). Both folders are needed: `SlimARK-UI` and `!SlimARK_Media`. The same zip works in both games.
3. In game, type `/slimark apply`. After each update a window asks for it once; click Apply now.

## Commands

| Command | What it does |
| --- | --- |
| `/slimark` | Opens the settings panel |
| `/slimark apply` | Sets every position and skin, then reloads the UI |
| `/slimark test` | Test mode on or off: `party`, `raid`, `raid40`, `mplus`, `healer`, `dps`, `off` |
| `/rl` | Reloads the UI |

SlimARK-UI's own frames can be dragged in Edit Mode, and the DPS and healer layouts remember their positions separately. Blizzard windows move by their title bar and resize with Ctrl + mouse wheel.

The layout follows your spec automatically. If you change spec in combat, it switches when combat ends.

## License

The code is under the [MIT License](LICENSE). The SlimARK-UI logo and icon (`assets/` and `SlimARK-UI/Media/Icon.tga`) are not covered by it.

## Libraries and font

| Name | License |
| --- | --- |
| [oUF](https://github.com/oUF-wow/oUF) | `SlimARK-UI/Libs/oUF/LICENSE.txt` |
| LibSharedMedia-3.0 | LGPL v2.1 |
| LibStub | Public Domain |
| CallbackHandler-1.0 | under the library's own terms |
| [Barlow](https://github.com/jpt/barlow) font | SIL Open Font License 1.1, `SlimARK-UI/Media/SlimARK-font-OFL.txt` |
