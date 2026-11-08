# Changelog

## 1.3.1

- The layout fits itself to your screen. It is drawn for 2560x1600 and now scales with the screen height on 1080p, 1440p, ultrawide and 4K, with nothing to choose
- Chat, minimap, buffs, quest tracker, boss frames, consumables and Details! stay at their screen edge; everything around the character stays together in the middle, on ultrawide too
- Thin borders stay one sharp pixel on every screen
- Frames you dragged in Edit Mode keep their place, and nothing changes on a 2560x1600 screen
- Run `/slimark apply` once after updating, so the Blizzard elements, Details!, the boss mods and the chat move too

## 1.3.0

- WoW Forever support: the same zip now loads in WoW Forever too (its own TOC files with interface 16001). Retail is unchanged
- In WoW Forever the Cooldown Manager is off by default: switch it on in the game options for the cooldown bars and the trinket icons
- The Mythic+ panel stays off where the game has no Mythic+

## 1.2.9

- Fixed: during a Mythic+ key the quest tracker could come back in combat and stand on top of the Mythic+ panel. It now turns invisible at once and is hidden when the combat ends
- Interrupted casts on nameplates keep the interrupter's name: the cast timer no longer writes over it
- Dungeons hide who interrupted behind a secret value. The castbar no longer stops on it, and the name is shown from it where the game allows (without class color). Your own interrupts are always named

## 1.2.8

- Party frames are wider and a little taller (240x72 instead of 160x64), with larger debuff and defensive icons, so nothing is crowded. The right edge stays in place, the column grows to the left

## 1.2.7

- The party frames next to your character show only the other four members. You have your own player frame; the healer grid still shows you

## 1.2.6

- Fixed: "C stack overflow" errors with a trinket that has no use or equip effect. Its item data was requested again and again

## 1.2.5

- Fixed: a used trinket did not show above the cooldown bars when its item data was not loaded yet at login
- A trinket use is now also recognized from its cooldown starting, and its buff may come up to one second after the use
- Class buffs that the Cooldown Manager tracks, like the wings, are never taken for a trinket or potion effect, even when a macro uses both at once

## 1.2.4

- Active trinket and potion effects: an icon with a gold countdown appears above the cooldown bars while the effect is up, above the player frame in the healer layout
- Fixed order: upper trinket, lower trinket, potion. A trinket you use shows from the moment you use it; a trinket that procs by itself shows from its own buff
- Its own page in `/slimark` (position for DPS and healer, icon size, trinkets and potions on or off) and draggable in Edit Mode

## 1.2.3

- Fixed: unit frames and nameplates lost their colors in 1.2.2 (white health and power bars). The shield code broke the health update before the bar was colored
- A shield error can no longer stop a frame from updating

## 1.2.2

**Shields**
- Shields (damage absorbs) show on the player, target, target of target, pet, focus, boss, party, raid and healer grid frames and on every nameplate, enemy shields too
- Light stripes right after the health: damage takes the striped part first
- A shield larger than the missing health is drawn from the right edge back over the health, with a bright line at the edge
- Shield color and an on/off switch on the Colors page of `/slimark`

**Cooldown bars**
- While a spell's effect is up, like the wings, its bar counts down the effect with a gold frame; when the effect ends the cooldown follows in the same place
- On/off switch on the Cooldown bars page of `/slimark`

**Docs**
- Layout images in the README and the CurseForge description

## 1.2.1

- The settings panel opens with `/slimark` (was `/slim`). `/slimark apply` still sets up the layout

## 1.2.0

**Settings panel**
- Type `/slim`, click the SlimARK button at the minimap, or open Options > AddOns > SlimARK-UI
- Every element has its own page: unit frames, party, raid, healer grid, nameplates, buffs, debuffs, cooldown bars, consumables, Mythic+, action bars, minimap, quest tracker, vendor, windows, Details!, boss mods, BetterBags, chat, Group Finder and cinematics
- Positions, sizes, fonts, colors and on/off switches, each with a slider and a box you can type into
- Changed values are marked; reset one value, one page or everything
- Search box in the header, version and changelog in the panel
- Save and reload UI applies the changes; values kept by Edit Mode or another addon run `/slimark apply` on their own

**Setup**
- `/slimark apply` sets up the layout (was `/slim apply`)
- After an update a window in the middle of the screen asks for `/slimark apply` once, with an Apply now button. It does not come back once the current version is applied

**Skins**
- BetterBags: flat dark SlimARK theme for the classic bags and BetterBags Next, with black edges, cropped item icons and quality colored borders
- Details!: player names no longer run into the numbers; two value columns with room for the name

**Minimap**
- SlimARK-UI has its own button in the minimap button column, and an entry in the minimap's addon menu

## 1.1.0

**Nameplates**
- The mob name now sits inside the plate, next to its health
- Health shows one decimal, for example 74.6%
- Casters are marked before they cast: mana users, mage type mobs and lieutenants, and every mob the addon has seen casting is remembered by name
- Important casts are magenta, so they stand apart from red, orange and yellow plates
- After an interrupt the bar reads "Interrupted" with the name of the player who did it, in class color

**Party and raid frames**
- Party frames (DPS and tank) are larger rectangles in a column right next to your character
- Party, raid and healer grid frames show the role icon: tank, healer or damage
- Party health shows one decimal

**Buffs and debuffs**
- Time left is shown under each icon, larger and easier to read
- Small gap between icons, so they no longer run into each other
- Stack counts are larger, with a thick outline

**Mythic+**
- Compact panel in place of the quest tracker while a key runs: key level and dungeon, deaths, timer with the +3 and +2 marks, enemy forces to two decimals, and one line per boss with its kill time

**Group Finder**
- Role checks are accepted automatically with your current spec's role
- Clicking a premade group listing signs you up at once, with your spec's role and no extra confirmation

**Quality of life**
- Cinematics and movies you have already seen are skipped automatically
- The version number is printed at login
- Every in-game text is in English
- Larger minimap addon buttons with a dark background
- Boss mod bars moved to the right of the character, opposite the party frames (type `/slim apply` once to move them)

**Performance**
- Cooldown bars redraw only the spell whose cooldown changed instead of every bar on each global cooldown
- Spell, talent and bag changes that arrive in a burst are handled once
- The character sheet overlay updates only while the sheet is open

## 1.0.0

First public release of SlimARK-UI, a slim UI for World of Warcraft Retail (Midnight), built from scratch on oUF.

**Layouts**
- DPS and tank share one layout, healers get their own
- Healer layout with grid-style group frames above the action bars
- The layout switches by itself when you change spec, and waits for the end of combat if needed
- `/slim apply` sets every position and skin in one step

**Unit frames**
- Player, target, target of target, pet, focus and boss frames
- Class power for every class
- Party and raid frames show defensive cooldowns with time left and debuffs
- The whole frame lights up in the debuff type color when you can dispel it

**Nameplates**
- Your target is marked with a thin frame and two arrows
- Casters stand apart, important casts turn orange
- Shows who interrupted a cast and who in your group targets the mob

**Cooldowns and consumables**
- Countdown bars with your spec's own cooldowns, for all 13 classes
- Icon row for your rotation spells
- Consumable bar for flasks, potions, food and weapon oils

**Quality of life**
- Vendor with two pages and automatic repair
- Character sheet with item level, gems, enchants and what is missing
- Square minimap with addon buttons along its edge
- Cleaner quest tracker
- Movable and resizable Blizzard windows
- `/rl` reloads the UI

**Skins**
- Details!, Deadly Boss Mods, BigWigs and Chattynator
