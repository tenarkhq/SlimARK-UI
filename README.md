<!-- CURSEFORGE.md is made from this file: python3 tools/curseforge.py. The github-only parts are left out there. -->
# SlimARK-UI

**A slim, clean and fast interface for World of Warcraft Retail (Midnight) and WoW Forever.**

SlimARK-UI replaces the default unit frames, nameplates, buffs, cooldown tracking, group frames, tooltip, loot pop-ups and the game's combat text font with one consistent, sharp look, and if you want, Blizzard's own windows too: flat dark bars, thin black edges, one readable font, and nothing on screen that you do not need in a fight. It is built from scratch on oUF and runs on events only, so it stays light: the crisp ElvUI style without ElvUI's pile of extras and twenty helper addons next to it.

One command sets up your whole screen: frames, Edit Mode layouts, action bars and the skins of your other addons. A settings panel lets you change every element afterwards.

**2.1.1 fixes:** saving applies your new values, incomplete setup stays available for retry. Group frames, ready check, combat fading and Mythic+ preview transitions have regression checks. The supported clients are Retail 12.1.5, 12.1.7 PTR and the current WoW Forever.

## Highlights

- **New in 2.0, Blizzard windows in the SlimARK look:** character sheet, spellbook, Group Finder, Great Vault, map, mail, merchant, Auction House and every other game window, flat and dark. Your choice at the first login: Original or SlimARK
- **Two layouts that switch with your spec:** DPS and tank around the center of the screen, healers with a grid of group frames right above the action bars
- **Fits every screen:** 1080p, 1440p, ultrawide and 4K, with sharp one pixel borders everywhere
- **Top bar:** micro menu, durability, FPS, queue time, gold, item level, your keystone with one-click dungeon teleports, the Great Vault and an auto quest switch, in one flat line
- **Readable in a fight:** health with one decimal, shields as stripes, casters marked before they cast, interrupter names, defensive cooldowns, dispel highlights, boss debuffs, incoming heals and aggro on every group frame
- **Mythic+ ready:** compact timer panel, keystone slotted for you, new key posted to the party
- **Group tools:** marker bar, ready check window that uses your missing flask or food, loot rolls in one flat column
- **Test mode:** see party, raid, Mythic+ or the other spec's layout without a group
- **Your old setup stays:** new profiles and Edit Mode layouts are created next to yours, nothing is overwritten

<!-- github-only -->
## Download

Download the zip from the [Releases](https://github.com/tenarkhq/SlimARK-UI/releases) page and extract it into `World of Warcraft/_retail_/Interface/AddOns` (for WoW Forever: the `Interface/AddOns` folder of the Forever client). Every position lives in `SlimARK-UI/Config.lua`, in pixels of the 2560×1600 layout.
<!-- /github-only -->

## Quick start

1. Install the addon. The download contains two folders, `SlimARK-UI` and `!SlimARK_Media`. Both are needed: the media folder loads first, so Details!, BigWigs and Chattynator can use the SlimARK font and texture from the start. The same download works in Retail and in WoW Forever.
2. Log in. A setup window asks how Blizzard's windows should look: **Original** leaves them as they are, **SlimARK** gives them the look of the rest of the UI. Pick one, then click **Apply now** (or type `/slimark apply` any time).
3. Done. Every position and skin is set, and the UI reloads. After each update the window asks once more; click **Apply now**.

![Setup window](assets/feature-setup.png)

| Command | What it does |
| --- | --- |
| `/slimark` | Opens the settings panel |
| `/slimark apply` | Sets every position and skin, then reloads the UI |
| `/slimark test` | Test mode on or off: `party`, `raid`, `raid40`, `mplus`, `healer`, `dps`, `off` |
| `/rl` | Reloads the UI |

## Layouts

The layout follows your spec and fits itself to your screen. The boxes show the real positions and sizes on a 2560×1600 screen: blue is SlimARK-UI, green is Blizzard, orange is Details!, Chattynator and the boss mods.

The top bar runs along the very top row; the minimap, the buffs and the quest tracker start right under it. In a group the marker bar sits under the minimap and the quest tracker moves down by its height. Loot rolls and pop-ups have their own column left of your character, and the tooltip waits above the bags and consumables row, next to the Details! windows.

**DPS and tank**

![DPS and tank layout](assets/layout-dps-tank.png)

**Healer**

The group grid sits right above the action bars. A party takes one row, a raid grows upward with five frames in each row.

![Healer layout](assets/layout-healer.png)

*The feature pictures below show the SlimARK look as drawn from the addon's design.*

# In combat

## Blizzard windows

New in 2.0. The game's own windows can take the SlimARK look: flat and dark, a thin black edge, a 2 pixel gold line on top, a darker header band with the title on the left, square close buttons, flat tabs and buttons, and item icons with their quality color as a thin edge. Nothing moves and nothing changes how a window works; only its look changes.

- **Your choice:** the setup window asks at the first login, **Original** or **SlimARK**; nothing is picked for you. Change it any time in `/slimark` → Interface → Blizzard windows
- **One switch per window** on that page, greyed out while the look is Original
- **Light:** each window is dressed the first time you open it, so windows you never open cost nothing, and with Original nothing of this runs at all
- **BetterFriendlist:** its window is dressed in place of the friends list
- **BetterBags:** the bags keep the BetterBags skin; without BetterBags Blizzard's bags get the SlimARK look

![Blizzard windows settings page](assets/feature-blizzwindows-page.png)

**Character sheet.** The SlimARK item level, gem and enchant marks stay on the slots.

![Character sheet](assets/window-character.png)

**Spellbook and talents**

![Talents](assets/window-talents.png)

**Group Finder and PvP**

![Group Finder](assets/window-groupfinder.png)

**Great Vault**

![Great Vault](assets/window-vault.png)

**Adventure Guide**

![Adventure Guide](assets/window-journal.png)

**World map and quest log**

![World map](assets/window-map.png)

**Quests and NPC talk.** The parchment goes, the text turns light.

![Quest window](assets/window-quest.png)

**The talking head**

![Talking head](assets/window-talkinghead.png)

**Merchant** (the two-page vendor keeps working) **and bank**

![Merchant](assets/window-merchant.png)

![Bank](assets/window-bank.png)

**Collections and achievements**

![Collections](assets/window-collections.png)

![Achievements](assets/window-achievements.png)

**Friends, guild, calendar and mail**

![Friends list](assets/window-friends.png)

![Guild](assets/window-guild.png)

![Calendar](assets/window-calendar.png)

![Mail](assets/window-mail.png)

**Auction House, trade and professions**

![Auction House](assets/window-auction.png)

![Trade](assets/window-trade.png)

![Professions](assets/window-professions.png)

**Game menu, pop-ups and bags.** With BetterBags its SlimARK theme takes the same gold line and title on the left.

![Game menu and pop-ups](assets/window-menu.png)

![Blizzard bags and BetterBags](assets/window-bags.png)

## Unit frames

- Player, target, target of target, pet, focus and boss frames
- Bold, readable font with a soft gloss on the health bars
- Health with one decimal, for example 74.6%
- Class power for every class: runes, combo points, holy power, essence, soul shards, chi, arcane charges, icicles, Maelstrom Weapon and more, each in the color of its resource (runes by spec, holy power gold)
- Boss frames show current health in the center, so you can call phase changes at a glance
- Shields (damage absorbs) in light stripes right after the health, on every frame including party, raid and boss frames. Damage takes the striped part first; a shield larger than the missing health is drawn back over the health with a bright line at the edge

**Shields:** a damaged target, a full health target with a large shield, a party frame and an enemy plate

![Shields](assets/feature-shields.png)

## Party, raid and healer frames

![Party frame](assets/feature-partyframe.png)

![Party and raid frames in every state](assets/feature-groupframes.png)

- Party frames as large rectangles in a column right next to your character, so you never look far away from the fight
- The party column shows the other four members only, since you have your own player frame. The healer grid includes you
- Wide frames with room for the name, the health, the defensive and the debuff icons side by side
- Role icon on every frame: tank, healer or damage
- Defensive cooldowns on every frame with the time left, both personal and external ones
- Debuff icons on every frame
- The whole frame lights up in the debuff type color (magic, curse, disease, poison) when you can dispel it
- Private auras, the boss debuffs the game keeps from addons, in the middle of the frame above everything. The game draws them itself, with its own icon and countdown
- Incoming heals as a pale green bar after the health, and heal absorbs (debuffs that eat healing) in dark red stripes at the end of the health
- Your own HoTs as small icons with the remaining time as a dark swipe
- Leader crown and raid marker, and the resurrection, summon, ready check and phase icons
- A red frame inside the edge of the member a mob is hitting
- Each of these can be switched off on the frame's page in `/slimark`

![Boss debuffs, incoming heals, HoTs, status icons and aggro on party, raid and healer frames](assets/feature-groupframes-2-1.png)

## Nameplates

![Nameplates](assets/feature-nameplates.png)

- Your target is marked with a thin frame and two arrows, other plates step back
- The mob's name and its health with one decimal sit inside the plate, not above it
- Casters are marked before they start casting: mana users, mage type mobs and lieutenants. Every mob the addon has seen casting is remembered by name for later runs
- Light blue cast bars for normal casts, magenta for the important ones you should interrupt, so they stand apart from red, orange and yellow plates
- After an interrupt the bar reads "Interrupted" with the name of the player who did it, in class color. In dungeons the game hides the interrupter from addons; your own interrupts are always named, others wherever the game lets the name through
- See which group members target the mob
- Debuffs you applied are shown above the plate
- Enemy shields in light stripes, so you see what has to break first

**Your target:** a thin frame and two arrows, in a bright and a dark place

![Target nameplate](assets/feature-target.png)

## Buffs and debuffs

![Buffs and debuffs](assets/feature-buffs.png)

- Large icons next to the minimap, buffs and debuffs in separate rows
- The time left is shown under each icon in a large gold number
- A small gap between icons, so they never run into each other
- Large stack counts with a thick outline

## Cooldowns and consumables

![Cooldown bars: active, cooldown, ready](assets/feature-cooldowns.png)

- Slim countdown bars with your spec's own important cooldowns, for all 13 classes
- While a spell's effect is up, like the wings, its bar counts the effect down first with a gold frame, then shows the cooldown
- Active trinket and potion effects: an icon with a gold countdown appears above the cooldown bars while the effect is up, above the player frame for healers. Both trinkets have their own place, the one you use and the one that procs by itself.
- A bar updates only when its own spell changes, so busy fights cost almost nothing
- Icon row for your rotation spells, taken from the game's own list for your spec
- Consumable bar for flasks, potions, food and weapon oils, showing what is missing

**Active trinket and potion effects** above the cooldown bars

![Active trinket and potion effects](assets/feature-effects.png)

## Combat text font

The game's own floating combat text uses the SlimARK font, so the numbers match the rest of the UI. One switch under Modules turns it off; a change shows after a reload.

## Action bars

![Action bars](assets/feature-actionbars.png)

- Square buttons with a thin black border and flat states: a light layer on mouse-over, a dark one while pressed, a thin gold edge on an active aura, stance or auto attack
- **Procs** get a gold edge in place of the spinning glow; Blizzard's assisted highlight becomes a turquoise edge
- **Icon colors:** red out of range, blue without enough mana, energy or focus, grey when the spell cannot be used
- **Short hotkeys:** the modifier is a small gold letter in front of the key, `sT` for Shift-T; macro names are hidden
- **Cooldowns** count down in large SlimARK numbers under a dark cover; the global cooldown gets a lighter cover
- **Fade:** out of combat the bars above the bottom three rows fade away and come back in combat, with a target, under the mouse or while you drag a spell
- Every part has its own switch on the Action bars page

## Less noise

- The red error text and its voice for range, facing, line of sight, no or wrong target, moving, mana and items not ready are hidden
- Blizzard already hides the out of energy and cooldown ones; full bags and every other message stay
- One switch on the Error messages page

# Groups and Mythic+

## Mythic+

![Mythic+ panel](assets/feature-mplus.png)

- Compact panel in place of the quest tracker while a key runs
- Key level and dungeon name, deaths and the time they cost
- Timer with the +3 and +2 marks and the time left for each
- Enemy forces to two decimals, with the raw count
- One line per boss with its observed kill time. After a reload, a boss already killed has a checkmark when its time is unknown
- The quest tracker steps aside for the whole key, even if the game tries to bring it back in combat, and returns when the key ends
- **Keystone:** your keystone goes into the Font of Power the moment you open it
- After a run your new keystone is posted to the party as a link, as soon as the game allows addon chat again

## Marker bar

![Marker bar](assets/feature-markers.png)

- Shown in a group only, hidden when you are alone
- **Eight target markers:** a click puts the marker on your target, another click takes it off. The marker on your current target gets a gold edge
- **Eight ground markers** in their own colors: left click places one, right click picks it up
- **Clear** picks up every ground marker
- **Ready** starts a ready check, **Pull** starts a 10 second pull countdown (right click stops it). These two are shown to the group leader and raid assistants only
- The marker buttons are Blizzard's own secure marker actions, so they work in combat too
- Two places, your choice: **under the minimap**, where the quest tracker and the Mythic+ panel move down by its height and never overlap it, or **next to the party frames**

## Ready check

![Ready check window](assets/feature-readycheck.png)

- A flat window in place of Blizzard's, with the question, who started it and the time left
- Shows what is on you and what is missing: **flask, food, augment rune, weapon oil**, the **class buffs** of the classes in your group, and your lowest **durability** (red under 50%)
- A missing flask, food, rune or oil gets a button that uses it from your bags, so one click fixes it before you answer
- **Ready** and **Not ready** buttons answer the check
- In combat Blizzard's own window stays, so nothing protected is touched

## Group Finder

- Role checks are accepted automatically with your current spec's role
- One click on a premade group listing signs you up with your spec's role, with no extra confirmation window

# Interface

## Top bar

A flat, 26 pixel bar on the top row of the screen, over the whole width. Everything that used to sit at the top edge moves down by its height, so nothing hides under it.

![Top bar](assets/feature-topbar.png)

**Left side**
- **Micro menu:** the twelve game menu buttons as small flat icons in Blizzard's own pictures, your portrait for the character sheet. A gold dot shows where the game would glow (unspent talents, new collections, ...). A click opens the same window as the original button
- **Durability:** your most worn item in percent, green, yellow or red. The tooltip lists every item, a click opens the character sheet
- **FPS** and **latency** (world ms, home and world in the tooltip)
- **Queue time:** shown only while you are queued, for the Dungeon Finder, Raid Finder, battlegrounds and premade applications: how long you have waited and the average wait. The tooltip shows the roles still missing, a click opens the queue menu
- **Tracked currencies:** every currency you marked "Show on Backpack", with its icon and amount

**Middle**
- **Clock:** a click opens the calendar, a right click the stopwatch and alarm. It turns gold when a calendar invite is waiting. The tooltip shows local and realm time

**Right side**
- **Gold:** your gold and what you earned or spent this session. The tooltip lists the gold of your characters on the realm and the total; a click opens your bags
- **Item level** of your equipped gear
- **Keystone:** your Mythic+ key, for example "Voidscar Arena +12". **A click opens the teleport list:** the dungeons of the current season that you have learned the teleport for (by timing a +10 there), your key's dungeon first, each with its cooldown. One click teleports you, no digging in the spellbook, the action bars or the dungeon journal. Dungeons you have no teleport for are not listed
- **Great Vault:** how many rewards you unlocked in raids, dungeons and the world, or "ready" when a reward waits. A click opens the vault
- **Auto quest switch:** ON or OFF with one click, remembered between sessions
- **Addon icons:** the minimap buttons of your other addons, in a row at the right end, right above the minimap

**Keystone teleports:** one click on your key opens the list

![Keystone teleport list](assets/feature-teleports.png)

## Tooltip

![Tooltip](assets/feature-tooltip.png)

- Flat dark plate with a thin black edge and the SlimARK font
- The class, reaction or item quality color is a thin stripe on top; the health bar is a thin line under the tooltip in the same color
- **Players:** name in class color, guild in green, then their **Mythic+ rating** in its color, their **item level with spec** and their **target** (">> you <<" when it is you)
- The item level is asked from the game out of combat only, once per player, and kept for 10 minutes
- **With Raider.IO:** the rating shows once, in Raider.IO's own lines, and the item level also uses the inspects Raider.IO makes in the background, so fewer requests go out
- **Place, your choice:** fixed right above the bags and consumables row next to the Details! windows, or next to the mouse

## Loot rolls and pop-ups

![Loot rolls and pop-ups](assets/feature-loot.png)

- One flat column left of your character for everything loot related; drag it in Edit Mode
- **Rolls** are flat rows: the item in its quality color, its slot, item level and BoP, the **Need**, **Greed** or **Transmog** and **Pass** buttons in one row, and a thin gold bar for the time left
- **Pop-ups** stack above the rolls in the same style: loot won, loot upgrades, money, achievements with their points, and new mounts, pets, toys and cosmetics
- Each row has a thin side stripe in the item's quality color

## Chat and addon skins

![Chattynator skin](assets/feature-chat.png)

- **Chattynator:** dark chat in the SlimARK font, with flat tabs: a thin stripe in the tab's color on top, the selected tab in gold, a slow gold line at the bottom when a new message comes in
- **Details!:** two windows, overall damage and current fight, in the SlimARK font with clean value columns
- **Deadly Boss Mods** and **BigWigs:** bars in the SlimARK look, placed to the right of your character, opposite the party frames
- **BetterBags:** flat dark SlimARK theme for both the classic bags and BetterBags Next: black edges, a gold line on top and the title on the left like the Blizzard windows, cropped item icons, quality colored borders, no glow or bounce
- **BetterFriendlist:** with the SlimARK look for Blizzard windows its window is dressed like the friends list

## Quality of life

- **Deleting a good item** asks for a click on **Confirm**, with the item shown, instead of typing DELETE

![Delete confirmation](assets/feature-delete.png)

- Cinematics and movies you have already seen are skipped automatically
- Vendor shows two pages at once, can hide what you already own, and marks items you lack the currency or reputation for
- Automatic repair at every repair vendor, and your junk (grey items) sold at every vendor, with the gold it brought in the chat. Turning off the Vendor module stops both automations
- NPC conversations stay readable: light text on the dark window
- The character sheet shows item level, gems, enchants and what is missing on each item
- Square minimap with your coordinates at its bottom, large, on a dark strip so they read on any map; they hide where the game gives no position. The clock moved to the top bar
- Cleaner, smaller quest tracker with a thin header line
- Move Blizzard windows by their title bar and resize them with Ctrl + mouse wheel; the position is remembered
- The version number is printed at login

## Auto quest

- Accepts the quests an NPC offers and turns in the finished ones, finished ones first
- When you have to choose a reward, it stops and you choose
- A quest that wants gold for the turn-in is left to you
- With a single talk option it picks it for you, so event and dungeon NPCs talk on without clicking
- It never picks an option that costs something or asks for a confirmation, and leaves vendors, flight masters, innkeepers, trainers, banks and the transmogrifier alone
- Grey (low level) quests are not taken
- Hold **Shift** while talking to an NPC to pause it there
- Works in Mythic+ too; switch it off and on from the top bar

# Setup and settings

## Layouts for every spec

- DPS and tank specs share one layout, built around the center of the screen
- Healers get their own layout, with grid-style group frames right above the action bars where your eyes already are
- The layout switches by itself when you change spec, and waits for the end of combat if needed
- New Edit Mode layouts named `SlimARK-UI` and `SlimARK-UI Heal` are created next to yours

## Fits every screen

- Reads your real screen size at login, there is nothing to choose
- Frames and text scale with the screen height, so they take the same share of the screen on 1080p, 1440p, ultrawide and 4K
- Chat, minimap, buffs, quest tracker, boss frames, consumables and Details! stay at their screen edge
- Everything around your character stays together in the middle, on ultrawide too
- Thin borders stay one sharp pixel on every screen
- Frames you dragged in Edit Mode keep their place

## Settings panel

Type `/slimark`, click the SlimARK icon in the addon icons (top bar, right end), or open Options → AddOns → SlimARK-UI.

![Settings panel](assets/feature-settings.png)

- Every element has its own page in a list on the left: test mode, Blizzard windows, unit frames, party, raid, healer grid, nameplates, buffs, debuffs, cooldown bars, consumables, Mythic+, top bar, minimap, action bars, boss mods, Details!, chat, tooltip, loot, marker bar, ready check, auto quest, Group Finder, keystone, deleting items, error messages and quality of life features
- Sizes, positions, fonts, colors and on/off switches, each with a slider or a box you can type into
- Where a feature has two ways to work, like the tooltip place or the marker bar place, you pick one on its page
- Every page can be reset to the SlimARK defaults on its own
- A search box finds any setting by name
- Changed values are marked in gold
- The version number and the changelog are shown in the panel

## Test mode

See your whole layout without a group: no need to gather a raid to check where everything sits. Open `/slimark` → General → Test mode, or type `/slimark test`.

![Test mode page](assets/feature-testmode-page.png)

![Test mode with a 20 player raid](assets/feature-testmode.png)

- **Party, Raid 20, Raid 40 or Mythic+:** made-up players fill the group frames, with mixed classes and roles
- **Mythic+** also shows the Mythic+ panel with a running key, in place of the quest tracker
- Target, target of target, focus, pet and boss 1-5 are filled too, with cast bars
- Everything a frame can show is on screen: class colors, role icons, health with one decimal, shield stripes, debuffs, defensives, the dispel highlight and a dead member
- **Healer or DPS and tank layout:** preview either one, whichever spec you play
- Stays on in Edit Mode, so you can drag the filled frames into place
- A gold banner under the top bar shows the mode; click it to end. Combat or a reload ends it too

## Your settings stay safe

SlimARK-UI never overwrites your existing profiles or Edit Mode layouts. It creates new ones named `SlimARK-UI` (and `SlimARK-UI Heal` for healers) next to them, so you can switch back at any time from the addon's own profile menu. Login and reload keep that choice; only an explicit `/slimark apply` selects the SlimARK profiles again. For BetterBags it only selects the SlimARK theme, which you can change back in BetterBags' theme menu.

Saving applies the new settings before the reload. If a required apply step fails, the UI stays open with an error in chat and no successful-version stamp. Changes from the settings panel remain there so you can correct the problem and save again. External addons may already have applied part of the setup; retry after resolving the reported error.

## Performance

SlimARK-UI is written to stay out of your frame time:

- Event driven: frames update only when their data changes. The only timers: the top bar's FPS, latency, clock and queue time once a second, the coordinates while the minimap is shown, the Mythic+ clock while a key runs, and the ready check countdown while the window is open. The action bar fade has no timer: the mouse over a button wakes it
- Bursts of spell, talent and bag events are handled once instead of many times
- Item-data failures and a delayed keystone use bounded retries; no permanent background polling is added
- Parts you switch off do nothing at all, and panels that are not shown, such as the character sheet overlay, do no work
- Blizzard windows are dressed once, the first time each one opens; with the Original look that code never runs.

## Good to know

- The layout fits itself to your screen: it is drawn for 2560×1600 and scales automatically on 1080p, 1440p, ultrawide and 4K. Screen edges stay at the edges, everything around your character stays in the middle. Sizes can still be changed in `/slimark` and frames dragged in Edit Mode.
- Made for Midnight's addon rules: it works with the protected values the game uses in combat.
- **WoW Forever:** the same download loads there too. Switch on the Cooldown Manager in the game options for the cooldown bars and the trinket icons. Forever has no Mythic+, so the Mythic+ panel, keystone helpers and top-bar keystone and Great Vault stay off. Details!, the boss mods and the other skinned addons need their own Forever versions.
- Found a bug? Open an issue on [GitHub](https://github.com/tenarkhq/SlimARK-UI/issues) and include the BugSack text.

## Credits

Built with [oUF](https://github.com/oUF-wow/oUF), LibSharedMedia-3.0, LibStub and CallbackHandler-1.0. Font: [Barlow](https://github.com/jpt/barlow), SIL Open Font License 1.1.

## Testers wanted! 🛠️

SlimARK-UI is brand new, and every bug report helps make it better. If you try it in Retail or in WoW Forever, I'd love to hear how it works for you.

**Found a bug?** Please post it in the comments or open an issue on [GitHub](https://github.com/tenarkhq/SlimARK-UI/issues), and include:
- The **BugSack** error text, if there is one (BugGrabber + BugSack catch errors that the game hides)
- A **screenshot** of what looks wrong
- Your **class and spec**, your **screen resolution and UI scale**, and whether it happened in Retail or WoW Forever
- Where it happened: open world, dungeon, Mythic+, raid

**Feature requests** are welcome too. Tell me what you miss, what's in the way, or what another addon does better.

Things I'd especially like feedback on:
- **New in 2.1:** boss debuffs, incoming heals, heal absorbs, your HoTs, the status icons and the aggro frame on party, raid and healer frames
- **New in 2.0:** the Blizzard windows in the SlimARK look (which window looks off, or which one you miss) and the delete confirmation
- Shields on party and raid frames
- Proc trinkets in the active effects row
- Interrupter names on nameplates in dungeons
- The new tooltip, loot column, marker bar and ready check window
- How it runs in **WoW Forever**
- The top bar and the auto quest: anything it should do differently

Thanks for trying it out!

<!-- github-only -->
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
<!-- /github-only -->
