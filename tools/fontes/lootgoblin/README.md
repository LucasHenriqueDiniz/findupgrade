# LootGoblin

LootGoblin compares gear for World of Warcraft: Forever. It supports levels 1–60 with 29 role profiles across all nine classes. Recommendations estimate gear stats and supported set bonuses against your equipped items, using a shared average encounter for conditional effects. They are not a simulation or a universal best-in-slot list.

## Getting started

1. Put the LootGoblin folder in your Forever client's Interface/AddOns directory and enable it in the AddOns list. Restart WoW after a new installation.
2. Enter /lg, click the minimap icon, or choose **Upgrades** on the character sheet.
3. Review **Profiles & Weights** and the item-source settings, select a slot, and use **Compare** to inspect a suggestion.

After updating while WoW is open, enter /reload to load the new files. Shift-drag the minimap icon to move it. Profile choices and preferences are saved per character.

When a guild or group member has a newer LootGoblin version, a chat reminder directs you to update through CurseForge. Reminders wait until combat ends and appear once per session. You may see reminders for up to three days after meeting that player. Older versions need one manual update before they can receive future reminders. LootGoblin learns about updates from other players and does not check CurseForge directly.

## Profiles and stat limits

Below level 10, LootGoblin uses your class leveling profile. From level 10, the talent tree with the most committed points selects the default. A tie or unavailable talent information may require a manual choice. Feral defaults to Cat and Survival to Melee; choose Bear or ranged Survival when appropriate.

Use **Profiles & Weights** to select a default or create a custom profile. Selecting an entry previews its weights; click **Apply** to use it for rankings. **Duplicate** makes an editable copy. **Add stats** offers supported stats, and **Advanced** provides Import and Export. Imported weights use Stat=number; full-line and trailing # comments are accepted. Defaults are locked. Choose the detected default and **Apply** to restore automatic specialization selection.

**Stat Limits**, also available through /lg limits, offers targets for enemies at your level, +1, +2 or +3. Select one enemy level per stat and choose **Apply**. Clear a selection to turn that stat's limit off. Relevant talents, race and weapons are included where supported. Defense and tank expertise are tracked goals that retain value above the target.

Supported set bonuses apply automatically. See [Scoring and stat limits](Model-Reference.md) for assumptions and limitations.

## Finding upgrades

Recommendations prepare when you enter the world and update when equipment changes or you open LootGoblin. Looted items are considered on the next check.

Item icons in Blizzard's bags, loot windows and quest rewards receive a LootGoblin badge when the item appears in the latest completed top-ten recommendations. Separate bags and the combined bag view are supported. Hover a badge to see the affected slot and estimated gain. Opening those windows does not refresh the rankings. The larger upgrade popup is reserved for items you actually loot.

**Compare** shows equipped and suggested items, stat changes, upgrade gains and set-bonus changes. Item sources include contacts, locations, quest steps and acquisition requirements. Effects excluded from the score are identified so you can consider them yourself.

World Drops is disabled by default in Item Sources. Enable it there to include world-drop upgrades. Existing saved source choices are preserved.

World-map pins show quest starters, vendors and dungeon entrances. Nearby opportunities share a numbered pin; hover it to see every upgrade and source. Approximate entrance locations are labeled. See [Catalog coverage](Forever-Acquisition.md) for eligibility and availability limits.

## Troubleshooting

- Enter /lg help for everyday commands, or /lg help support when troubleshooting with support.
- In Forever, window size adjusts automatically to your screen resolution: 100% at 1080p, 133% at 1440p and 200% at 4K. Windows shrink when needed to fit your screen. Custom sizes apply immediately to LootGoblin windows.
- Restart after a new installation. After an update, enter /reload and confirm that you updated the client you launched.
- For a bug report, include the game version, class, level, affected item, steps to reproduce and exact Lua error. Share diagnostic exports only when requested; remove account and character identifiers and avoid publishing full SavedVariables files.

The addon works offline in game and requires no other addon.

## Commands

Enter **/lg help** to see the everyday controls in chat. **/lootgoblin** works in place of **/lg** for every command. A short reminder appears when the addon loads.

| Command | What it does |
| --- | --- |
| /lg | Open or close LootGoblin. |
| /lg help | Show everyday commands. |
| /lg limits | Choose stat targets. |
| /lg scale | Show the current window-size preference. |
| /lg scale 150 | Save a custom size, from 50% to 300%. A trailing % is accepted. |
| /lg scale auto | Restore automatic sizing. /lg scale reset does the same. |
| /lg loot | Show upgrade badge and loot notification settings. Add on or off to change them. |
| /lg map | Show world-map upgrade pin settings. Add on or off to change them. |

Window size, badge and pin preferences are saved per character. Help and setting queries remain available during combat. Use window actions and setting changes out of combat.

**/lg help support** lists the troubleshooting commands separately:

| Command | What it does |
| --- | --- |
| /lg status | Show detailed addon and calculation status. |
| /lg log | Show diagnostic recording status. Add on or off to change recording, or clear to remove recorded diagnostics. |
| /lg capture | Record the first recommendation for support. Add a result number from 1 to 10 to choose another. Diagnostic recording must be on. |
| /lg item ID | Look up an item's recorded requirements and sources in Forever. |

Diagnostics save to disk on /reload or logout. Status and recording controls also work during combat. Unknown commands show a help hint without opening or closing the window.
