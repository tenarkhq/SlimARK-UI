# Changelog

## 3.0.0

Mythic+:

- Run summary at the end of a key: time against the limit, time in combat and its share of the run, deaths, score change, and damage, healing, interrupts and deaths for each member. The loot of the run is in the same window, marked when it is an upgrade for you. The last 20 runs open from the Mythic+ page
- Mythic+ panel: time in combat with its share of the run so far; battle res charges and the time to the next one; Bloodlust ready or how long Sated lasts; your best time per boss for that dungeon and key level, green when you are ahead and red when behind
- The enemies you are fighting show as a lighter part of the forces bar. The percent of the pull shows outside keys only, because in a key the game hides the value of each enemy from addons
- In raid boss fights the battle res and Bloodlust row shows above the boss frames
- Keystone tooltip: your best level and score in every dungeon of the season, this week's affixes and the keys of your party. A member's key shows when their addon shares it (SlimARK, BigWigs, Details! and others do); in a running key it is not refreshed
- When you join a premade group, a teleport button sits under the dungeon name if you know its teleport

Nameplates and combat:

- Enemy casts in one column above the focus frame: up to 5 casts of mobs with a nameplate, who each one is aimed at and the time left, in the colors of the nameplate cast bars. A red YOU on the player frame while a cast is aimed at you
- Enemy forces in percent under the nameplate during a key
- Focus mark: a turquoise strip on your focus's nameplate, and a short sound when your focus starts casting
- Buffs you can purge or soothe on the nameplates and above the target frame: blue for magic, orange for enrage
- A mark before the name of quest mobs (!), rares (R) and elites (E)
- Interrupt strip on party, raid and healer frames: green while the member's interrupt is ready, filling with the seconds left after a kick that landed. Addons cannot see kicks that miss
- A GCD line under your cast bar, and marks on your power bar at each spender cost for Death Knight, Demon Hunter, Feral and Guardian Druid, Rogue, Elemental Shaman and Warrior
- Buff reminder above the cooldown bars, in instances and out of combat: a missing class buff, weapon enchant or poison, shaman shield or pet
- Raid frames sorted: you, tanks, healers, damage
- Arena enemy frames in place of the boss frames

Top bar (every element keeps its own switch; of the new ones only Alts is on by default):

- Alts: item level, keystone, Great Vault, score and gold of each of your characters, with crests on hover
- Spec and loadout in one element: spec, loadout, loot spec and gear set (off by default)
- Friends and guild online; addon CPU in the FPS tooltip; this week in the Great Vault tooltip (reset, runs, reward levels, lockouts); a thin XP or reputation line on the bottom edge of the bar that takes no room, with no XP at max level and no reputation line without a watched faction (all off by default)
- A quiet mode switch (off by default)

Groups and items:

- Ready check: the flask and class buffs of your group. The game does not give addons the food or rune of other players
- Premade groups: the leader's score in color, member classes and applicant specs; a minimum score filter and sorting by score; your applications in a small window with their status, and a short sound when a group invites you
- Auto accept: group invites from friends and guild members, summons and resurrections, each with its own switch
- Item level and BoE or warbound marks on gear in Blizzard's bags, bank, merchant and loot window. With BetterBags the bags and the bank are left to it
- Faster auto loot; repair from the guild bank when the guild allows it; shift-click buys a full stack; one chat line when you enter a dungeon with fewer than 5 potions or food
- Off by default: a loadout reminder when you enter a dungeon; the upgrade track in item tooltips and on the character sheet; the character sheet marks on the inspect window; tooltip extras (IDs, count in bags, already known, mount name, hide in combat)

Interface and system:

- /slimark apply places Blizzard's boss timeline and warnings; Blizzard's damage meter gets the SlimARK look and the Details! place
- New pages: Profiles (export and import your settings as text, a profile per character), Macros (focus kick, mouseover dispel, healthstone and potion), Game settings (camera distance, spell queue window, nameplate overlap, screen shake and the game's audio alerts), Quiet mode (muted sounds, no boss banner, zone text or Battle.net toasts) and Other
- AFK screen with your character, item level, spec, keystone and the time away
- Battleground timers for Arathi Basin, Battle for Gilneas and Deepwind Gorge
- Off by default: screenshots of a timed key, a boss kill or an achievement; world map coordinates; a rare alert with one quiet sound per rare

Fixes:

- No more "attempt to compare a secret string value" error from the tooltip in dungeons and raids, when an inspect answer (often asked by another addon, such as Raider.IO) came in while a player was under the mouse
- The tooltip and the ready check window no longer test the game's hidden answer to "is this unit you?" on dungeon and raid maps; a hidden answer counts as no

Good to know:

- Every new part has its own switch in /slimark, and a part that is switched off does nothing
- Spender costs come from the game's own data; Elemental Blast's cost is used when you have it

## 2.3.0

Nameplates and cast bars:

- Cast bars by your interrupt: while your interrupt is on cooldown the enemy cast bars are dark, so a bright bar always means you can interrupt it now. The magenta frame of an important cast and the grey of a cast that cannot be interrupted stay. On nameplates and on the target, focus and boss cast bars
- Who the cast is aimed at: the target's name in class color under the nameplate cast bar, a red YOU when it is you. On the target, focus and boss cast bars the name sits inside the bar, in front of the time
- Aggro on the plate, in a group: only the wrong case gets the orange warning color. In a tank spec that is a fighting mob that is not on you, in every other spec a mob that is on you
- Execute line: a thin line on the plate where your finisher starts to work. Paladin 20%, Death Knight 35%, Warrior, Hunter, Priest and Warlock 20%, Fire Mage 30%, Monk 15%; other classes have no line. The Nameplates page has a percent of your own

Frames:

- Shaman totems: your totems as icons with the time left in a row above the player frame. Drag it in Edit Mode
- Quick focus: Shift + left click on a mob in the world, on a nameplate or on a SlimARK frame makes it your focus. Ctrl or Alt can be picked on the Quick focus page. With the modifier held the left click no longer targets or turns the camera in the world
- The player frame can fade out of combat without a target. Off by default, on the Player page

Groups and Mythic+:

- "!keys" in party or guild chat is answered with your keystone. In a running key and in boss fights the game blocks addon chat, so there nothing is sent
- Combat logging switches on when a key starts or you enter a raid, with Advanced Combat Logging, and off when you leave. A log you started yourself is left alone
- When you join a premade group, the dungeon shows in large text for a few seconds, with the group's title under it

Good to know:

- Every new part has its own switch in /slimark
- In dungeons and raids the game hides mob names from addons. The caster mark's memory of names therefore works in the open world only; in an instance a mob is marked as a caster from its first cast, and by its mana or rank as before
- Test mode shows the cast target on the made-up cast bars

## 2.2.0

- Frames colored by the debuff type: when a typed debuff is on you or on a group member, the health area of the frame takes the type's color with an edge in the same color. The colors are the game's own: poison green, disease brown, curse purple, magic blue, and bleed has its own color too. On the player frame, the party, the raid and the healer grid
- Every typed debuff colors the frame, whether or not your class can remove it. Debuffs without a type do not
- What you can dispel keeps its bright frame over the color, and with several types on a member its color is the one shown
- The health level, the name and the icons stay readable over the color
- On and off with the existing "Dispel highlight" switch. Test mode shows it on the member with the magic debuff

## 2.1.4

The real fixes of 2.1.1 are back, with the look of 2.1.0:

- Interrupter on nameplates: only the kick that went to that mob names a player, so two kicks on two mobs no longer swap names. The name is in class color again in dungeons too, without a question mark
- Trinket and potion icons: a buff that only happened to come right after a trinket use still shows that once, but is no longer remembered as the trinket's effect. Item data that was not loaded at login is asked for again, so the icon does not stay missing until a reload. No question marks; what SlimARK learned before is kept
- Gold: kept under the character itself, so a renamed character is listed and counted once. The tooltip looks as before
- Auto quest: a grey quest is left to you when an NPC opens its details directly too, as in the quest lists

## 2.1.3

Four more 2.1.1 changes are undone; these work as in 2.1.0 again:

- Auto quest accepts a quest whose details open directly, grey ones too
- The gold tooltip lists your characters on the realm with one total, and a click opens your bags. Characters 2.1.1 saved in its own way are put back in the list
- Trinket and potion icons have no question mark, and the effects SlimARK learns are kept again
- After an interrupt the nameplate shows the interrupter's name without a question mark, as before

## 2.1.2

- Cinematics you have already seen are skipped again by default, as before 2.1.1. The setting is back as "Skip seen cinematics" on the Cinematics page
- Details!, DBM and BigWigs switch back to the SlimARK profile at login again, as before 2.1.1

## 2.1.1

- Settings apply the values just saved, including changes shared with Edit Mode and other addons. Changing the rotation icons' Y or the marker bar placement also clears an older dragged position.
- A failed apply reports the affected part, keeps the UI open and allows a retry. It does not mark an incomplete setup as finished or reload away the error. Failed window skins retry once per frame, then stop until reload; BetterBags themes remain retryable.
- Details!, DBM and BigWigs keep a different profile you select in their own menus. Only an explicit apply switches back to SlimARK.
- Group frames keep a Blizzard fallback when their SlimARK replacement is disabled; the aggro edge uses the current unit. The test player's role is preserved.
- Tooltip and ready check use current Retail/PTR/Forever APIs. Ready check fits every class-buff row, and its item buttons are hidden before combat starts.
- Consumable recognition uses item and spell identity across client languages. Effect learning no longer stores a nearby unrelated buff as an item effect, and failed item-data requests remain retryable.
- Temporary effect estimates carry a question mark and are not learned. Older unverified effect mappings are cleared once; verified item spell IDs are retained.
- A Mythic+ preview stops before a real run. Already completed bosses have no invented kill time after reload, and a delayed keystone link can still be announced. Forever does not build unsupported Mythic+/vault widgets.
- Action bars return at combat start without needing a target. Interrupt attribution avoids naming the wrong player from an unrelated recent kick.
- Turning off Vendor stops its automatic sale and repair too. Junk-sale messages do not treat other money changes as sale proceeds, and bursts of item data do not repeatedly process the full merchant list.
- Disabled Group Finder automation preserves manual roles. Directly opened low-level quests are skipped, and a different cinematic in a previously visited zone is not treated as already seen.
- Cinematics play by default. Skipping by place is a separate opt-in setting with a warning that it can skip new scenes; movies are still remembered by their ID.
- Gold snapshots follow a renamed character, show the last update and allow manual removal. Older unidentified snapshots remain visible outside the total until that character next logs in.
- Added regression checks and release-package validation; unused upstream oUF developer tools are excluded from the installable package.

## 2.1.0

New on the party, raid and healer grid frames (each one can be switched off on the frame's page in /slimark):

- Private auras: the boss debuffs the game keeps from addons now show in the middle of the frame, above everything. The game draws them itself, with its own icon and countdown
- Incoming heals as a pale green bar after the health, and heal absorbs (debuffs that eat healing) in dark red stripes at the end of the health. The shield now starts after the incoming heals
- Your own HoTs as small icons on the right under the health value, the remaining time as a dark swipe. On the raid frame they sit at the end of the name row
- Leader crown and raid marker on the left; resurrection, summon, ready check and phase icons in the middle
- A red frame inside the edge of the group member a mob is hitting

## 2.0.8

- New: junk is sold at every vendor. SlimARK presses the game's own Sell All Junk for you (grey items; bags you excluded from it in the bag menu stay untouched) and prints how many items it sold and for how much. Switch: Vendor page, "Sell junk (grey items)"; on by default
- Fixed: the text of NPC conversations (the greeting and the options) was dark brown and black on the dark window, because the game colored it for parchment again after every update. It stays light now

## 2.0.7

- Fixed: a click on a dungeon in the keystone teleport list did nothing. With the game's "cast on key down" setting on, SlimARK's buttons waited for a key press that a mouse click never sends. The same fix makes the marker bar, the ready check Use buttons and the micro menu buttons on the top bar act on the click

## 2.0.6

- **Combat text:** SlimARK's own floating numbers are gone; the game's combat text stays and uses the SlimARK font (one switch under Modules: Combat text font). If you had SlimARK's combat text on, the game's own numbers come back as you had them before

## 2.0.5

- **Achievements:** the achievement points and their title no longer float above the window; they sit on one line in the window's header band

## 2.0.4

- **Group Finder:** the refresh button of the premade group list and the Filter button are flat like the other buttons; every dropdown has a thin grey arrow in place of Blizzard's yellow one
- **Talents:** the spec picture, its clouds and the hero talent backplates are gone; the tree sits on the dark window body and the hero talent panel is a flat box
- **Mythic+:** the dungeon picture and the runes behind "This Week" stay hidden after the tab updates
- **World map:** the red bar with "World" is a flat dark bar with flat buttons; the ornate frame around the quest log and the quest details is gone
- **Traveler's Log:** completed activities are readable (light grey instead of black), the red ribbons are gone and the progress bar sits in a flat dark field
- **Achievements:** the gold and blue edges around the summary and the achievement cards are gone, the colored title banners stay hidden, and descriptions and criteria are light instead of black
- **Housing dashboard:** new; the house picture, the filigree corners and the wood signs go, the panels are flat boxes and the side tabs flat buttons (own switch under Blizzard windows)

## 2.0.3

- **Mail:** the parchment behind the inbox letters is gone, and so is the old bar under the sender and subject of an open letter
- **Page arrows:** the round arrows Blizzard took from the old spellbook (mail, merchant, books and letters, calendar, collections, spellbook pages) are flat squares with a thin arrow, dimmed while there is no page to turn to

## 2.0.2

Every SlimARK window was checked against the windows of the 12.1 game and now follows what the game actually draws there.

- **Character sheet:** enchant texts on the left and the right side no longer run into each other; each side gets half of the room between the slot columns and the "Enchant Slot -" prefix is left out. The stat headers are flat bands instead of the ornate frames, the class picture behind the stats is gone
- **Inspect:** the inner border around the model is gone
- **Spellbook and talents:** the book pages, the bookmark and the page corner are gone; spell rows are flat with light names, the talent and specialization pages lose their dark bars
- **Group Finder:** the category buttons (Dungeon Finder, Raid Finder, Premade Groups) and the premade categories are flat boxes with a gold line on the selected one; the role backgrounds and streaks are gone
- **PvP:** the category buttons and every queue (random battlegrounds, arenas, brawls, Solo Shuffle, Blitz, rated, Training Grounds) are flat rows with a gold film on the selected one
- **Mythic+:** the dungeon icons have a black edge instead of the frames, the background art is gone
- **Great Vault:** the row backgrounds, borders and dividers are gone
- **Adventure Guide:** the path bar at the top (Home and the steps after it) is flat; the rock behind Journeys and the expansion picture behind the dungeon lists are gone; renown and journey cards are flat with a light hover, the dividers are thin lines; the Traveler's Log loses its themed border, paper and shadows; suggested content, item sets and the loot tab are flat. The pages of a dungeon or a boss stay on their parchment, because the game writes their text in black
- **Collections:** mount, pet and appearance set lists are flat rows with a gold film on the selected one; the landscape behind the mount, the pet battle slot frames and the pet card art are gone; the collected bars are flat
- **Transmogrifier:** the 12.x window keeps its gear slots (they show pending and saved states); its extra dark layers, the ornate tab frame and the divider lines are gone
- **Achievements:** the wood frame and the gold edges are gone (the game draws them as backdrops now), achievement rows, categories, statistics, comparison and the summary bars are flat
- **Friends:** the Battle.net bar, the Who column headers and the rock behind invite headers are flat
- **Guild and communities:** the blue menu with gold filigree is gone, communities are flat rows with a gold film on the selected one; the side tabs, the member list headers, the chat input and the finder pages are flat
- **Calendar:** the event, holiday and invite windows are flat too
- **Mail:** inbox rows are flat, the stationery is gone and letters are written and read in light text
- **Books and letters:** the page and its material are gone, the text stays light on every page
- **NPC talk:** the letter material in the corners is gone
- **Quests:** only the quest window's own pages turn light; the quest log beside the map keeps its parchment and dark text
- **Auction House:** the category list, its buttons, the result and sell panels and the item headers are flat
- **Professions:** the recipe list, its category headers, the profession picture behind the recipe, the skill bar and the crafting order panels are flat; the specialization dials stay, like the talent trees. The profession book (your list of professions) is flat with light texts

## 2.0.1

- **Combat text:** off by default. The game's own numbers stay as they are; switch the SlimARK combat text on under Combat: Combat text if you want it. If 2.0.0 had switched it on for you, the game's numbers come back exactly as you had them

## 2.0.0

- **Setup window:** after the update a window asks how Blizzard's windows should look: **Original** leaves them alone, **SlimARK** dresses them in the look of the rest of the UI. Nothing is picked for you; Apply now works once you choose, Later asks again at the next login. Change it any time under Interface: Blizzard windows
- **SlimARK windows:** flat and dark, a thin black edge, a 2 pixel gold line on top, a header band with the title on the left, square close buttons, flat tabs and buttons, item icons with their quality color as a thin edge
  - Character sheet, inspect, spellbook and talents, Group Finder and PvP, Great Vault, Adventure Guide, collections and appearances, achievements, friends list (BetterFriendlist's window too), guild and calendar, mail, world map and quest log, quests and NPC talk, the talking head, merchant and bank, Auction House and trade, professions, the game menu, pop-ups and the bags
  - Each window is dressed the first time you open it, so nothing runs for windows you never open, and nothing at all with Original
  - One switch per window on the Blizzard windows page. With BetterBags the bags keep the BetterBags skin
- **Combat text:** floating numbers in the SlimARK font, on by default. Crits are twice the size, orange on your target, brighter red and green on you, land with a pop and a short shake and stay up longer. Damage you take shows left of your character, heals you get further left, damage on your target above the middle while you are not in a group. In a group the game only tells addons the damage your target takes from everyone, so there your own hits stay the game's numbers, in the SlimARK font. Crit look, size and every part on the Combat text page
- **Deleting items:** destroying a good item asks for a click on Confirm, with the item shown, instead of typing DELETE. Switch on the Deleting items page
- **BetterBags:** the SlimARK theme has the gold line on top and the title on the left, like the new windows. Click Apply now after the update
- **Tooltip:** with Raider.IO installed the Mythic+ rating shows once, in Raider.IO's own lines, and the item level also takes the answers of the inspects Raider.IO makes in the background, so fewer requests go out

## 1.8.1

- **Tooltip:** the fixed place moved up, its bottom right corner now sits right above the bags and consumables row, so it covers neither the Details title bar nor the bag buttons
- **Quest tracker:** with the marker bar under the minimap the tracker gets shorter by the bar's height, so its bottom stays clear of the tooltip. Click Apply now after the update

## 1.8.0

- **Tooltip:** flat, with a black edge and the SlimARK font. The class, reaction or item quality color is a thin stripe on top, the health bar a thin line under it. Players show their guild in green, their Mythic+ rating in its color, their item level with spec and their target. The item level is asked for out of combat only and kept for 10 minutes. Place: fixed above the Details windows or next to the mouse, on the Tooltip page
- **Loot rolls and pop-ups:** one column left of your character. Rolls are flat rows with the item, its slot, item level and BoP, Need, Greed or Transmog and Pass buttons and a gold time bar. Loot won, upgrades, money, achievements and new mounts, pets, toys and cosmetics pop up as flat rows above them. Drag the column in Edit Mode
- **Marker bar:** in a group only. Eight target markers, eight ground markers (left click places, right click picks up), clear all, and for the leader a ready check and a 10 second pull countdown (right click stops it). Under the minimap, where the quest tracker moves down by its height, or next to the party frames
- **Ready check:** a flat window with the question and what is on you: flask, food, augment rune, weapon oil, the class buffs of your group and your durability. A missing flask, food, rune or oil gets a button that uses it from your bags. In combat Blizzard's window stays
- Every new part has its own switch, and the two-way choices are on their pages

## 1.7.0

- **Keystone:** your keystone goes into the Font of Power the moment you open it. After a run your new keystone is posted to the party as a link, as soon as the game allows addon chat again. Both on the Keystone page
- **Error messages:** the red error text and its voice for range, facing, line of sight, no or wrong target, moving, mana and items not ready are hidden. Blizzard already hides the out of energy and cooldown ones; full bags and every other message stay. Switch on the Error messages page
- **Action bars:** the fade of the upper bars runs no timer any more, the mouse over a button wakes it

## 1.6.0

- **Action bars:** flat buttons in the SlimARK look
  - A light layer on mouse-over, a dark one while pressed, a thin gold edge on an active aura, stance or auto attack
  - Procs get a gold edge in place of the spinning glow; Blizzard's assisted highlight becomes a turquoise edge. The cast fill and the round targeting and interrupt animations on the buttons are gone
  - Icon colors: red out of range, blue without enough mana, energy or focus, grey when the spell cannot be used
  - Short hotkeys: the modifier is a small gold letter in front of the key, `sT` for Shift-T. Macro names are hidden
  - Cooldowns count down in large SlimARK numbers; the global cooldown gets a lighter cover than a real cooldown
  - Out of combat the bars above the bottom three rows fade away. They come back in combat, with a target, under the mouse, while you drag a spell or in Edit Mode
  - Every part has its own switch on the Action bars page, with the cooldown font size and the faded opacity
- **Chattynator:** flat tabs with a black edge in the SlimARK font, the tab's color as a thin stripe on top, the selected tab in gold and a slow gold line at the bottom for a new message. The edit box gets the black edge and the SlimARK font too. Switches on the Chat page: flat tabs, color stripe or a gold line under the selected tab, tab font size

## 1.5.2

- Fixed: an error on nameplates when a cast was interrupted and the game hid the spell name
- Fixed: an error from the trinket and potion icons when the game hid a buff update in combat

## 1.5.1

- Fixed: a click on a dungeon in the keystone teleport list closed the list without teleporting
- Fixed: test mode showed no party and raid frames while you were not in a group
- Fixed: Details! added a percent column when the overall panel updated out of combat, and the texts ran into each other. The panels show total and per second only

## 1.5.0

- **Test mode:** see your layout without a group. Open `/slimark` → General → Test mode, or type `/slimark test`. Made-up players fill the frames:
  - **Party:** four group members next to your character, a tank, a healer and two damage dealers
  - **Raid 20** and **Raid 40:** a full raid of mixed classes and roles
  - **Mythic+:** the party and the Mythic+ panel with a running key in place of the quest tracker
  - Target, target of target, focus, pet and boss 1-5 are filled too, with cast bars
  - Everything a frame can show: class color, role icon, health with one decimal, shield stripes, debuffs, a defensive, the dispel highlight and a dead member
- Test mode can show the healer or the DPS and tank layout, whichever spec you play. Only the SlimARK frames move; Blizzard's own elements stay where your spec has them
- It stays on in Edit Mode, so you can drag the filled frames into place. A gold banner under the top bar shows the mode; click it to end. Combat or a reload ends it too
- Commands: `/slimark test party`, `raid`, `raid40`, `mplus`, `healer`, `dps`, `off`

## 1.4.1

- Fixed: the micro menu icons of the top bar showed only a colored patch instead of the symbol

## 1.4.0

- **Top bar:** a flat bar on the top row of the screen, over the whole width. Left: the micro menu as small flat icons, durability, FPS, latency, the queue time while you are queued (Dungeon Finder, Raid Finder, battlegrounds, premade applications) and your tracked currencies. Middle: the clock, a click opens the calendar. Right: gold with this session's gain or loss, item level, your keystone, the Great Vault, the auto quest switch and the icons of your other addons
- **Dungeon teleports:** click the keystone on the top bar for the dungeons of the season you have learned the teleport for; one click teleports. Dungeons without a teleport are not listed
- **Auto quest:** accepts and turns in quests, finished ones first, and picks the only talk option of an NPC. It stops when you have to choose a reward or pay gold, never picks an option that costs something, and leaves vendors, flight masters, innkeepers, trainers, banks and the transmogrifier alone. Hold Shift to pause it; the top bar switches it off and on
- **Minimap:** the clock moved to the top bar, your coordinates took its place, larger and on a dark strip
- The minimap, buffs, debuffs, quest tracker, Mythic+ panel and the other top elements moved down by the bar's height. The quest tracker now starts right under the minimap
- New settings pages: Top bar (every item can be switched off) and Auto quest
- Run `/slimark apply` once after updating, so the Blizzard elements move under the bar too

## 1.3.4

- Fixed: on the two-page vendor the Next button stayed where the narrow window had it and covered the page number. It now sits at the right edge, opposite Prev

## 1.3.3

- Fixed: a gap between two runes could vanish, so six runes looked like five with one double wide. Class power pips now sit on whole screen pixels, so every gap shows, on every screen size

## 1.3.2

- Class power takes the color of its resource, after the ElvUI defaults, instead of gold for every class
- Runes follow the spec: Blood red, Frost cyan, Unholy green
- Combo points, chi and essence change color pip by pip; charged combo points are blue
- Arcane charges blue, icicles light blue, soul shards purple, Maelstrom Weapon violet
- Holy power stays gold

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
