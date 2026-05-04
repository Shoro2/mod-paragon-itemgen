# File and directory structure — mod-paragon-itemgen

> Static inventory. Maintain this when adding/removing files.

## Tree

```
mod-paragon-itemgen/
├── conf/
│   ├── conf.sh.dist                       # Build: SQL paths
│   └── paragon_itemgen.conf.dist          # Module configuration
├── data/sql/
│   ├── db-characters/
│   │   └── paragon_item_enchants.sql      # character_paragon_role + character_paragon_item
│   └── db-world/
│       ├── paragon_itemgen_enchantments.sql  # ~11,323 spellitemenchantment_dbc entries
│       └── paragon_passive_spells.sql        # paragon_passive_spell_pool + paragon_spec_spell_assign
├── Paragon_System_LUA/
│   ├── ItemGen_Server.lua                 # AIO server: reads PROP_ENCHANTMENT, decodes IDs (~6 KB)
│   └── ItemGen_Client.lua                 # AIO client: tooltip cache + custom lines (~12 KB)
├── src/
│   ├── MP_loader.cpp                      # Loader: Addmod_paragon_itemgenScripts() (~300 B)
│   ├── ParagonItemGen.h                   # Header: enums (StatIndex, Role), constants (~5 KB)
│   ├── ParagonItemGen.cpp                 # Core logic (~37 KB!) — scaling, roll, hooks, cursed
│   ├── ParagonItemGenCommands.cpp         # CommandScript: .paragon role/stat/info (~7 KB)
│   └── ParagonItemGenNPC.cpp              # NPC for spec selection (~8 KB)
├── apps/                                   # CI helpers (if present)
├── include.sh                              # Build integration
├── pull_request_template.md
├── CLAUDE.md                               # Detailed content doc
├── log.md                                  # Commit log (modular)
├── data_structure.md                       # This file
└── functions.md                            # Mechanics reference
```

## File purposes

| File | Purpose |
|-------|-------|
| `conf/paragon_itemgen.conf.dist` | `Enable`, `OnLoot`/`OnCreate`/`OnQuest`/`OnVendor`, `ScalingFactor`, `MinParagonLevel`, `MinItemLevel`, `BlockTrade`, `BlockMail`, quality multipliers, `CursedChance`, `CursedMultiplier`, `CursedVisualKit` |
| `conf/conf.sh.dist` | SQL path registration |
| `data/sql/db-characters/paragon_item_enchants.sql` | Schema: `character_paragon_role`, `character_paragon_item` |
| `data/sql/db-world/paragon_itemgen_enchantments.sql` | DELETE+INSERT for ~11,323 custom enchantment IDs (900001-916666 stat, 920001 cursed marker) |
| `data/sql/db-world/paragon_passive_spells.sql` | `paragon_passive_spell_pool` + `paragon_spec_spell_assign` with `CREATE TABLE IF NOT EXISTS` |
| `Paragon_System_LUA/ItemGen_Server.lua` | AIO handlers: `RequestData`, `ReceiveSlots` (server pushes on login + bag update); decodes `enchantmentId → (statIndex, amount)` |
| `Paragon_System_LUA/ItemGen_Client.lua` | Cache per `(bag, slot)`; hooks `GameTooltip:SetX()` methods for custom tooltip lines; DBC text fallback |
| `src/MP_loader.cpp` | `Addmod_paragon_itemgenScripts()` calls `AddParagonItemGenScripts`, `AddParagonItemGenCommands`, `AddParagonItemGenNPC` |
| `src/ParagonItemGen.h` | Enums `ParagonStatIndex` (0=Sta,1=Str,...,16=ManaRegen), `ParagonRole` (0=Tank,1=DPS,2=Healer); constants for slot IDs, multiplier defaults |
| `src/ParagonItemGen.cpp` | `ApplyParagonEnchantment`, `RollStatAmount`, `RollCursed`, hook implementations, `LoadPassiveSpellPool`, `LoadSpecSpellAssign`, trade/mail restriction |
| `src/ParagonItemGenCommands.cpp` | `.paragon role`, `.paragon stat`, `.paragon info` CommandScript |
| `src/ParagonItemGenNPC.cpp` | NPC gossip for spec selection (talent spec → `character_paragon_spec`) |

## Size notes (as of 2026-05-01)

- ⚠️ `src/ParagonItemGen.cpp` is **~37 KB** — close to the read limit. Use chunked reads with offset/limit if needed.
- `Paragon_itemgen_enchantments.sql` can become **large** (>100 KB for 11,323 entries) — never read it all at once, only grep.
- All other files: < 13 KB

## External dependencies

- **azerothcore-wotlk** (core): `PlayerScript`, `WorldScript`, `CommandScript`, `CreatureScript`, prepared statements for the World+Characters DBs.
- **AIO framework**: from `share-public/AIO_Server/`.
- **mod-paragon**: reads `character_paragon.level` for scaling. Without mod-paragon, `paragonLevel = 0` and no items get enchanted.
- **Spell.dbc**: 99 custom spell IDs (950001-950099) for passives must exist in the server Spell.dbc.

## DB tables

### `acore_characters`
| Table | PK | Contents |
|---------|----|--------|
| `character_paragon_role` | `characterID` | role (0/1/2), mainStat (3/4/5/6) |
| `character_paragon_item` | `itemGuid` | paragonLevel, role, mainStat, combatRating1/2, statAmount, cursed |
| `character_paragon_spec` | `characterID` | specId for the cursed passive pool |

### `acore_world`
| Table | Contents |
|---------|--------|
| `spellitemenchantment_dbc` | DBC override (~11,323 entries: stats + cursed marker + 99 passives) |
| `paragon_passive_spell_pool` | spellId, enchantmentId, name, category, minParagonLevel, minItemLevel |
| `paragon_spec_spell_assign` | specId, enchantmentId, weight |

## What is not where?

- **No own NPC spawn definition** — the NPC must be spawned separately via `creature_template`/`creature` SQL.
- **No custom build slot** — included via AzerothCore auto-detection.
- **No unit tests**.
