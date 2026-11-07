# SlimARK-UI

Karcsú World of Warcraft UI retailre (Midnight, 12.x), nulláról építve az oUF-re. Az ElvUI és a LuckyoneUI kinézetét követi, a sok extra nélkül.

2560×1600 felbontásra és 65%-os UI scale-re készült, DPS Retribution paladinhoz. Minden pozíció a `SlimARK-UI/Config.lua` fájlban van, valódi képpontban.

## Mit tartalmaz

- Unitframe-ek, party és raid keretek, boss keret
- Nameplate-ek: kiemelt célpont, elkülönülő casterek, fontos castok narancsban, látszik, ki szakította a castot és ki targeteli a mobot
- Cooldown sávok a fontos spellekhez és rotációs ikonsor
- Buffok, debuffok, dispellelhető jelzések
- Consumable bar: flask, poti, étel, fegyverolaj
- Vendor két oldalon, automatikus javítás
- Karakterlap: item level, gemek, enchantok és a hiányuk
- Négyzet alakú minimap, alatta az addon jelek
- Quest tracker skin
- Skin a Detailshez, DBM-hez, BigWigshez és Chattynatorhoz
- Edit Mode layout, amely minden Blizzard elemet a helyére tesz

A meglévő profilokat és layoutokat nem írja felül, mindenből saját, `SlimARK-UI` nevű újat hoz létre.

## Telepítés

1. Töltsd le a zipet a [Releases](https://github.com/tenarkhq/SlimARK-UI/releases) oldalról.
2. Csomagold ki a `World of Warcraft/_retail_/Interface/AddOns` mappába. Mindkét mappa kell: `SlimARK-UI` és `!SlimARK_Media`.
3. Játékban írd be: `/slim apply`.

## Parancsok

| Parancs | Mit csinál |
| --- | --- |
| `/slim apply` | Beállítja az összes pozíciót és skint, majd újratölt |
| `/rl` | Újratölti a felületet |

A SlimARK-UI saját keretei Edit Mode-ban húzhatók. A Blizzard ablakok a címsoruknál mozgathatók, és Ctrl+görgővel méretezhetők.

## Felhasznált könyvtárak és betűtípus

| Név | Licenc |
| --- | --- |
| [oUF](https://github.com/oUF-wow/oUF) | `SlimARK-UI/Libs/oUF/LICENSE.txt` |
| LibSharedMedia-3.0 | LGPL v2.1 |
| LibStub | Public Domain |
| CallbackHandler-1.0 | a könyvtár saját feltételei szerint |
| [Barlow](https://github.com/jpt/barlow) betűtípus | SIL Open Font License 1.1, `SlimARK-UI/Media/SlimARK-font-OFL.txt` |
