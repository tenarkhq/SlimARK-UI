# SlimARK-UI checks

Everything here runs without the game. It loads the real addon files into a stand-in WoW
environment (fake frames, fake API answers that each test sets), so it proves the addon's own
logic, not the game client's behaviour. What only the game can show is in the manual list at the
end, **none of which has been run yet**.

## Run everything

From the repository root:

```sh
python3 -m pip install -r requirements-test.txt   # lupa 2.8: Lua 5.1 and LuaJIT, no system Lua needed
python3 tests/run.py
```

`tests/run.py` exits with 0 only when every check passes. It prints a short summary, and the full
output of every failing check:

1. **syntax**: every Lua file of `SlimARK-UI/` and `!SlimARK_Media/` (vendored libraries
   included) compiles in Lua 5.1 and in LuaJIT;
2. **toc**: the four TOC files agree on `## Version`, which is also the newest heading of
   `CHANGELOG.md`; `## Interface` is `120105, 120107` in the retail TOCs and `16001` in the
   Forever TOCs (change `INTERFACE` in `tests/run.py` with the clients); `## X-SlimARK-Flavor`
   is `retail` / `forever`; the retail and the Forever TOC of an addon load the same files;
   every file a TOC or an XML include loads exists with that exact case; every Lua and XML file
   is loaded by something;
3. **lua tests**: `tests/claude/*.lua` and `tests/codex/*.lua`, each in its own process, once with
   Lua 5.1 and once with LuaJIT;
4. **py tests**: `tests/package_*.py`.

Options: `--engine lua51` or `--engine luajit` (one engine only), `--only TEXT` (only the tests
whose path holds TEXT), `-v` (show the output of passing tests too).

GitHub Actions runs the same on every push and pull request (`.github/workflows/tests.yml`).

## Layout

| Path | What |
| --- | --- |
| `tests/claude/*.lua` | Regression tests of the fixes F2, F3, F5, F7, F9–F11, F13–F18, F24, F26 |
| `tests/codex/*.lua` | Regression tests of the fixes F1, F4, F6, F8, F12, the F13 setting, F19, F20, F22, F23, the F24 buyback follow-up, F27–F29 |
| `tests/claude/lib/helpers.lua` | The stand-in WoW environment (fake frames, events, timers, fresh SavedVariables per test) |
| `tests/codex/lib/` | Helpers of the Codex tests |
| `tests/package_release.py` | The release zip check (F25) |
| `tools/package.py` | Builds the release zip |
| `tools/apicheck.py` | Optional: checks the used game API against the three clients' UI source |

A Lua test is a plain Lua 5.1 file, run from the repository root. It passes when it ends without
an error and without `os.exit` with a non-zero code. `lib/` folders are helpers, not tests.

## Release zip

```sh
python3 tools/package.py            # dist/SlimARK-UI-<version>.zip
```

The zip holds `SlimARK-UI/` and `!SlimARK_Media/`: every file git tracks in them, the repository's
`LICENSE` as `LICENSE.txt` in both, and the libraries' own licence files. Upstream oUF's developer
scripts (`SlimARK-UI/Libs/oUF/utils/`) are left out. The build is reproducible (sorted entries,
the last commit's time). `tests/package_release.py` builds it twice and checks the name, the two
folders, every file the TOC and XML files load, that every Lua and XML file in it is loaded, the
exclusion, the licences, every `Interface\AddOns\...` path the code names, that both builds are
the same, and that `.pkgmeta` (CurseForge's packager) has the same exclusion.

## Game API check (optional, needs the network)

```sh
python3 tools/apicheck.py --fetch                  # clone or update .cache/wow-ui-source/{live,ptr,forever}
python3 tools/apicheck.py --source DIR             # use checkouts already in DIR/live, DIR/ptr, DIR/forever
python3 tools/apicheck.py --luacheck PATH          # luacheck is needed (luarocks install luacheck, or apt install lua-check)
```

It compares every game global, `C_` function and `Enum` value the addon reads with the branches
of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source): `live` (retail), `ptr` and
`forever`, and prints each branch's commit and `version.txt` with the result. It reports a global
that exists only as a deprecated fallback (`Blizzard_Deprecated*`, loaded only while the
`loadDeprecationFallbacks` CVar is on), one the client does not load for its game type (live and
ptr: `standard`, forever: `camelot`, read from the TOC files), and one that is missing. The few
names allowed on purpose are listed with their reason in `ALLOWED` and shown in the report. On the
audited 2.1.0 code it reports F3 (`GetSpecialization`, `GetSpecializationInfo`,
`GetInspectSpecialization`, `GetWeaponEnchantInfo`); on 2.1.1 it reports no problem (checked
against live 12.1.5.70783, ptr 12.1.7.70740, forever 1.60.1.70888). The `apicheck` workflow runs
it by hand on GitHub Actions.

## Manual checks in the game: NOT RUN YET

These need a logged-in client. **None of them has been run**: each status below is "not run". Use
BugSack/BugGrabber for Lua errors and the taint log for blocked actions:
`/console taintLog 2`, play, `/reload`, then read `Logs/taint.log`. A check passes when it shows
the expected result, no Lua error and no SlimARK line in the taint log.

| # | Area (audit) | Steps | Expected | Retail 12.1.5 | PTR 12.1.7 | Forever 1.60.1 |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | Taint baseline | Play 20 min with every module on: group, vendor (page 2 purchase), marker bar, micro menu, Edit Mode, `/slimark apply`. | No `ADDON_ACTION_BLOCKED` / `FORBIDDEN` naming SlimARK. | not run | not run | not run |
| M2 | Combat start (F14) | Action bar fade on, no target; let a mob attack you; then kill it. | The upper bars show as the fight starts and fade after it. | not run | not run | not run |
| M3 | Ready check combat (F9) | Ready check with a missing flask, then pull a mob; let the check end in combat; click where the Use button was. | The Use button goes as combat starts; the click targets the world and uses no item. | not run | not run | not run |
| M4 | Ready check content (F3, F10, F11) | Full raid with mage, priest, warrior, druid, shaman, evoker, worn gear; on retail also `/console loadDeprecationFallbacks 0`; one test on a German client. | 11 rows incl. durability; weapon oil time from the main hand; window answers the check; rune/oil/flask found on deDE. | not run | not run | not run |
| M5 | Tooltip (F3) | Hover your own character; with `loadDeprecationFallbacks 0` hover other players until their item level shows. | Item level and spec lines, no Lua error. | not run | not run | not run |
| M6 | Group frames (F2, F5) | DPS spec, Party and Raid modules off, grid on: join a party and a raid; switch to a healer spec and back; `/reload` in combat. A mob attacks a party member whose frame was never hovered. | Blizzard frames for the DPS, the grid for the healer, swapped after combat; the red aggro frame shows. | not run | not run | not run |
| M7 | Interrupt names (F18) | Mythic+ (secret GUIDs): kick your target; kick another mob; let a party member kick. | Exact names without "?"; a party kick at the targeted plate as "Name?"; no name on the wrong mob. | not run | not run | — |
| M8 | Secret values (audit H2) | Mythic+ and an arena or battleground: hover players who target you; a ready check started by someone else; the nameplate targeter list in a raid; a raid marker on your target. | No Lua error; the marker bar's gold edge follows the target marker. | not run | not run | not run |
| M9 | Vendor (F7, F24, F26) | Vendor module off: visit a vendor with junk. On: sell 3 junk stacks, then more than 12; open a vendor with 200+ items. | Off: no sale, no repair. On: report equals the buyback list ("at least" over 12); no stutter; page 2 buys what it shows. | not run | not run | not run |
| M10 | Cutscenes (F13) | Two in-game cutscenes of one quest chain in one place; then turn on the place option. | Both play by default; with the option the second is skipped. | not run | not run | not run |
| M11 | Auto quest (F16) | An NPC with only a grey quest. | The quest is not accepted. | not run | not run | not run |
| M12 | Settings and Edit Mode (F1, F8, F27) | Change the action bar button size and Save; fill Edit Mode to its layout limit and run `/slimark apply`. | The bars have the new size after the reload; a full Edit Mode is reported and asked again later. | not run | not run | not run |
| M13 | Other addons' profiles (F20) | After `/slimark apply`, switch Details!, DBM and BigWigs back to your own profile; `/reload`. | Your own profiles stay selected. | not run | not run | — |
| M14 | Mythic+ panel (F4, F22) | Start a key while the test mode shows the Mythic+ preview; `/reload` mid-run. | The real timer is not overwritten; killed bosses show done without a made-up time. | not run | not run | — |
| M15 | WoW Forever (F28) | Install the zip in the Forever client. | Loads without "out of date" (`_Forever.toc` read); no keystone, vault or Mythic+ panel. | — | — | not run |
