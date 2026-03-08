# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mod-paragon-itemgen** is an AzerothCore module that applies bonus stat enchantments to weapons and armor based on the player's Paragon level (from [mod-paragon](https://github.com/Shoro2/mod-paragon)). Items receive up to 5 enchantment slots filled with role-appropriate stats when looted, crafted, quest-rewarded, or vendor-purchased.

### Core Mechanics

- **5-slot enchantment system** using `PROP_ENCHANTMENT_SLOT_0` through `_4` (slots 7–11):
  - Slot 7: Stamina (always)
  - Slot 8: Main stat (player-chosen: Str/Agi/Int/Spi)
  - Slot 9: Random combat rating from role pool
  - Slot 10: Random combat rating from role pool (no duplicate of slot 9)
  - Slot 11: "Cursed" marker (enchantment ID 920001) or empty for normal items

- **3 roles**: Tank, DPS, Healer — each with a distinct combat rating pool
- **Scaling formula**: `ceil(paragonLevel × scalingFactor × qualityMultiplier)`, capped at 200
- **Random stat rolls**: Each stat rolls independently from 1 to the calculated max value
- **Cursed items**: 1% chance (configurable) for all stats to be set to 150% of max, item becomes soulbound, shadow visual plays on player
- **Permanent enchantments**: Items keep stats forever; role/stat changes only affect new items
- **Transfer restrictions**: Trade/mail blocked to players with lower Paragon level

### Role Combat Rating Pools

| Role | Pool (ParagonStatIndex values) |
|------|-------------------------------|
| Tank (0) | Dodge(5), Parry(6), Defense(7), Block(8), Hit(9), Expertise(12) |
| DPS (1) | Crit(10), Haste(11), Hit(9), ArmorPen(13), Expertise(12), AP(15), SP(14) |
| Healer (2) | Crit(10), Haste(11), SpellPower(14), ManaRegen(16) |

## File Structure

```
mod-paragon-itemgen/
├── conf/
│   ├── conf.sh.dist                  # Build: SQL path registration
│   └── paragon_itemgen.conf.dist     # Server config template
├── data/sql/
│   ├── db-characters/
│   │   └── paragon_item_enchants.sql # character_paragon_role + character_paragon_item tables
│   └── db-world/
│       └── paragon_itemgen_enchantments.sql  # 3401 spellitemenchantment_dbc entries (3400 stats + 1 cursed)
├── Paragon_System_LUA/
│   ├── ItemGen_Client.lua            # AIO client addon: tooltip enhancement for cursed items
│   └── ItemGen_Server.lua            # AIO server: registers client addon
├── src/
│   ├── MP_loader.cpp                 # Module entry point (Addmod_paragon_itemgenScripts)
│   ├── ParagonItemGen.h              # Header: constants, enums (ParagonStatIndex, ParagonRole)
│   ├── ParagonItemGen.cpp            # Core: scaling logic, hooks, trade/mail restrictions
│   └── ParagonItemGenCommands.cpp    # CommandScript: .paragon role/stat/info
├── include.sh                        # Build integration
└── CLAUDE.md                         # This file
```

## Enchantment System

### ID Layout

```
Base: 900000
Formula: 900000 + statIndex × 1000 + amount (1–200)

Stat Index 0  = Stamina (ITEM_MOD 7)    → IDs 900001–900200
Stat Index 1  = Strength (ITEM_MOD 4)   → IDs 901001–901200
Stat Index 2  = Agility (ITEM_MOD 3)    → IDs 902001–902200
...
Stat Index 16 = Mana Regen (ITEM_MOD 43) → IDs 916001–916200

ID 920001 = "Cursed" marker (no stat effect, slot 11 label only)
Reserved: 920002+ for talent spell enchantments (not yet created)
```

Each enchantment has exactly **one** `ITEM_ENCHANTMENT_TYPE_STAT` (type 5) effect. Multiple stats per item are achieved by using separate enchantment slots.

### SpellItemEnchantment DBC Fields Used

For stat enchantments:
- `Effect_1` = 5 (`ITEM_ENCHANTMENT_TYPE_STAT`)
- `EffectPointsMin_1` = stat amount (1–200)
- `EffectArg_1` = `ITEM_MOD_*` enum value
- `Effect_2`, `Effect_3` = 0 (unused)

## Database Schema

### `character_paragon_role` (characters DB)

Stores each character's chosen role and main stat. Modified via `.paragon role` and `.paragon stat` commands.

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `characterID` | INT UNSIGNED (PK) | — | Character GUID |
| `role` | TINYINT UNSIGNED | 1 (DPS) | 0=Tank, 1=DPS, 2=Healer |
| `mainStat` | TINYINT UNSIGNED | 4 (Str) | ITEM_MOD value: 3=Agi, 4=Str, 5=Int, 6=Spi |

### `character_paragon_item` (characters DB)

Tracks paragon-enchanted items for trade/mail restriction enforcement.

| Column | Type | Notes |
|--------|------|-------|
| `itemGuid` | INT UNSIGNED (PK) | Item instance GUID |
| `paragonLevel` | INT UNSIGNED | Player's Paragon level at enchantment time |
| `role` | TINYINT UNSIGNED | Role used (ParagonRole enum) |
| `mainStat` | TINYINT UNSIGNED | Main stat index (ParagonStatIndex enum) |
| `combatRating1` | TINYINT UNSIGNED | First combat rating (ParagonStatIndex enum) |
| `combatRating2` | TINYINT UNSIGNED | Second combat rating (ParagonStatIndex enum) |
| `statAmount` | INT UNSIGNED | Per-stat amount applied |
| `cursed` | TINYINT UNSIGNED | 1 if item rolled cursed |

### External Dependency: `character_paragon` (from mod-paragon)

| Column | Type | Notes |
|--------|------|-------|
| `accountID` | INT UNSIGNED (PK) | Account ID |
| `level` | INT | Current Paragon level |
| `xp` | INT | XP remaining (counts down) |

## Key Functions

### ParagonItemGen.cpp

| Function | Purpose |
|----------|---------|
| `ApplyParagonEnchantment(Player*, Item*)` | Main entry: validates item, calculates stats, rolls random amounts (or cursed), applies 4 enchantment slots |
| `RollStatAmount(maxAmount)` | Rolls a random stat value from 1 to maxAmount |
| `RollCursed()` | Returns true with `conf_CursedChance`% probability |
| `GetPlayerParagonLevel(Player*)` | Queries `character_paragon` for account's Paragon level |
| `GetPlayerRoleInfo(Player*)` | Queries `character_paragon_role` for role + main stat |
| `PickTwoRandomRatings(role, &cr1, &cr2)` | Selects 2 distinct random ratings from role pool |
| `CalculateStatAmount(paragonLevel, quality)` | `ceil(level × scalingFactor × qualityMult[quality])` |
| `GetEnchantmentId(statIndex, amount)` | `900000 + statIndex × 1000 + amount` |
| `IsEligibleItem(Item*)` | Checks: weapon/armor, quality ≥ uncommon, itemLevel ≥ config min |
| `ItemHasParagonEnchantment(Item*)` | Checks slots 7–11 for existing paragon enchantments |
| `ApplySlotEnchantment(Player*, Item*, slot, enchId)` | Applies/re-applies a single enchantment slot |

### Hook Points (PlayerScript)

| Hook | Trigger |
|------|---------|
| `OnPlayerLootItem` | Mob/chest loot |
| `OnPlayerCreateItem` | Crafting |
| `OnPlayerQuestRewardItem` | Quest rewards |
| `OnPlayerAfterStoreOrEquipNewItem` | Vendor purchases |
| `OnPlayerCanSetTradeItem` | Trade restriction (blocks if target Paragon < item Paragon) |
| `OnPlayerCanSendMail` | Mail restriction (blocks if recipient Paragon < item Paragon) |

### Chat Commands (CommandScript)

Registered under `.paragon` prefix, all `SEC_PLAYER`:
- `.paragon role tank|dps|healer` — requires `PLAYER_FLAGS_RESTING`
- `.paragon stat str|agi|int|spi` — requires `PLAYER_FLAGS_RESTING`
- `.paragon info` — no restriction

## Configuration

All options read via `sConfigMgr->GetOption<>()` in `OnAfterConfigLoad`:

| Key | Type | Default |
|-----|------|---------|
| `ParagonItemGen.Enable` | bool | true |
| `ParagonItemGen.OnLoot` | bool | true |
| `ParagonItemGen.OnCreate` | bool | true |
| `ParagonItemGen.OnQuest` | bool | true |
| `ParagonItemGen.OnVendor` | bool | true |
| `ParagonItemGen.ScalingFactor` | float | 0.5 |
| `ParagonItemGen.MinParagonLevel` | uint32 | 1 |
| `ParagonItemGen.MinItemLevel` | uint32 | 150 |
| `ParagonItemGen.BlockTrade` | bool | true |
| `ParagonItemGen.BlockMail` | bool | true |
| `ParagonItemGen.QualityMult.Uncommon` | float | 0.5 |
| `ParagonItemGen.QualityMult.Rare` | float | 0.75 |
| `ParagonItemGen.QualityMult.Epic` | float | 1.0 |
| `ParagonItemGen.QualityMult.Legendary` | float | 1.25 |
| `ParagonItemGen.CursedChance` | float | 1.0 |
| `ParagonItemGen.CursedMultiplier` | float | 1.5 |
| `ParagonItemGen.CursedVisualKit` | uint32 | 5765 |

## Build & Integration

- Standard AzerothCore module: symlink or clone into `modules/` directory
- No custom `CMakeLists.txt` needed (uses auto-detection)
- Entry point: `Addmod_paragon_itemgenScripts()` in `MP_loader.cpp`
- SQL files auto-discovered via `include.sh` → `conf/conf.sh.dist`

## Code Style

Follow AzerothCore C++ conventions:
- 4-space indentation, no tabs
- UTF-8 encoding, LF line endings
- `Type const*` (not `const Type*`)
- Use `uint32`, `uint8`, `int32` etc. from `Define.h` (not `uint32_t`)
- `std::uniform_int_distribution<int>` (not `<uint8>` — MSVC rejects it)
- Backtick table/column names in SQL

## Cursed Items

Items have a configurable chance (default 1%) to roll "cursed" when enchanted:

- **All 4 stats** set to `conf_CursedMultiplier` × max value (default 150%), capped at 200
- **Soulbound** immediately via `item->SetBinding(true)`
- **Shadow visual** played on the player via `player->SendPlaySpellVisual(conf_CursedVisualKit)`
- **Slot 11** receives enchantment ID `920001` ("Cursed") — visible in the item tooltip via DBC
- **AIO Lua addon** enhances the tooltip: colorizes "Cursed" text purple, paragon stat lines get role-colored, and a red warning line is added

### Client-side Setup

1. Run `tools/patch_dbc.py` on the already-patched (or original) `SpellItemEnchantment.dbc` — the script auto-removes old paragon entries before adding new ones (including the Cursed marker)
2. Copy `Paragon_System_LUA/ItemGen_Client.lua` and `ItemGen_Server.lua` to the server's `lua_scripts/` folder (requires AIO)

## Known Issues and TODOs

### Not Yet Implemented

1. **Talent Spell Slot (Slot 11)**: Currently used only for the "Cursed" marker enchantment. Custom talent spells (IDs 920002+) are not yet implemented.

2. **Auction House Restriction**: AzerothCore has no `CanListAuction` or `CanCreateAuction` hook. The `OnAuctionAdd` hook fires *after* listing and returns void (cannot cancel). Options:
   - Core patch: add a `CanCreateAuction` hook returning bool
   - `OnAuctionAdd` + immediate auction cancellation/item return (hacky)
   - Cursed items are already soulbound, preventing AH listing

### Potential Improvements

3. **In-memory caching**: Paragon level and role info are queried from DB on every item acquisition. For high-traffic servers, cache in player data map.

4. **PROP_ENCHANTMENT_SLOT conflict**: Items with random properties ("of the Bear", etc.) will have those replaced by paragon enchantments. May want to only apply to items without existing PROP enchantments, or intentionally override.

5. **No prepared statements**: DB queries use string-formatted `.Query()`/`.Execute()`. Should migrate to `CharacterDatabasePreparedStatement` for production use.

6. **Combat rating pool overlap**: DPS pool contains both Attack Power and Spell Power. A physical DPS could roll Spell Power. Consider splitting into melee DPS and caster DPS pools, or filtering by class.
