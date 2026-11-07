# SlimARK-UI

A slim, clean UI for World of Warcraft Retail (Midnight), built from scratch on oUF. It keeps the sharp ElvUI look without the pile of extras, and one command sets up your whole screen.

## Quick start

1. Install the addon. The download contains two folders: `SlimARK-UI` and `!SlimARK_Media`. Both are needed.
2. Log in and type `/slim apply`.
3. Done. Every position and skin is set, and the UI reloads.

## What you get

**Layouts for every spec**
- DPS and tank share one layout
- Healers get their own, with grid-style group frames right above the action bars
- The layout switches by itself when you change spec, and waits for the end of combat if needed

**Unit frames**
- Player, target, target of target, pet, focus and boss frames
- Readable bold font and a soft gloss look
- Class power for every class: runes, combo points, holy power, essence, soul shards, chi, arcane charges, icicles, Maelstrom Weapon and more
- Boss frames show current health in the center

**Party and raid frames**
- Party frames as large rectangles right next to your character
- Role icon on every frame: tank, healer or damage
- Defensive cooldowns on every frame with time left, both personal and external
- Debuff icons on every frame
- The whole frame lights up in the debuff type color when you can dispel it

**Nameplates**
- Your target is marked with a thin frame and two arrows, and other plates fade back
- Name and health with one decimal inside the plate
- Casters are marked before they start casting
- Light blue cast bars, magenta for important casts you should interrupt
- See who interrupted a cast and who in your group targets the mob

**Cooldowns and consumables**
- Slim countdown bars with your spec's own cooldowns, for all 13 classes
- Icon row for your rotation spells, taken from the game's own list for your spec
- Consumable bar for flasks, potions, food and weapon oils

**Mythic+**
- Compact panel in place of the quest tracker while a key runs
- Timer with the +3 and +2 marks, enemy forces to two decimals, boss kill times, deaths

**Quality of life**
- Buffs and debuffs show the time left under each icon
- Role checks are accepted with your spec's role, one click on a premade listing signs you up
- Cinematics you have already seen are skipped
- Vendor shows two pages at once, hides what you already own, and marks items you lack the currency or reputation for
- Automatic repair
- Character sheet shows item level, gems, enchants and what is missing
- Square minimap with small addon buttons along its edge
- Cleaner, smaller quest tracker
- Move Blizzard windows by their title bar, resize them with Ctrl + mouse wheel
- `/rl` reloads the UI

**Skins**
- Details! (two panels: overall damage and current fight)
- Deadly Boss Mods
- BigWigs
- Chattynator

## Your settings stay safe

SlimARK-UI never overwrites your existing profiles or Edit Mode layouts. It creates new ones named `SlimARK-UI` and `SlimARK-UI Heal` next to them, so you can switch back at any time.

## Good to know

- The layout is designed for 2560×1600 at 65% UI scale. On other screens, drag the frames in Edit Mode.
- Found a bug? Open an issue on [GitHub](https://github.com/tenarkhq/SlimARK-UI/issues) and include the BugSack text.

## Credits

Built with [oUF](https://github.com/oUF-wow/oUF), LibSharedMedia-3.0, LibStub and CallbackHandler-1.0. Font: [Barlow](https://github.com/jpt/barlow), SIL Open Font License 1.1.
