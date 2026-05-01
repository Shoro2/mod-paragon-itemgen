# Datei- und Verzeichnisstruktur — mod-paragon-itemgen

> Statisches Inventar. Bei Hinzufügen/Löschen von Files hier mitpflegen.

## Tree

```
mod-paragon-itemgen/
├── conf/
│   ├── conf.sh.dist                       # Build: SQL-Pfade
│   └── paragon_itemgen.conf.dist          # Modul-Konfiguration
├── data/sql/
│   ├── db-characters/
│   │   └── paragon_item_enchants.sql      # character_paragon_role + character_paragon_item
│   └── db-world/
│       ├── paragon_itemgen_enchantments.sql  # ~11.323 spellitemenchantment_dbc Einträge
│       └── paragon_passive_spells.sql        # paragon_passive_spell_pool + paragon_spec_spell_assign
├── Paragon_System_LUA/
│   ├── ItemGen_Server.lua                 # AIO-Server: liest PROP_ENCHANTMENT, decodiert IDs (~6 KB)
│   └── ItemGen_Client.lua                 # AIO-Client: Tooltip-Cache + Custom-Lines (~12 KB)
├── src/
│   ├── MP_loader.cpp                      # Loader: Addmod_paragon_itemgenScripts() (~300 B)
│   ├── ParagonItemGen.h                   # Header: Enums (StatIndex, Role), Konstanten (~5 KB)
│   ├── ParagonItemGen.cpp                 # Core-Logik (~37 KB!) — Skalierung, Roll, Hooks, Cursed
│   ├── ParagonItemGenCommands.cpp         # CommandScript: .paragon role/stat/info (~7 KB)
│   └── ParagonItemGenNPC.cpp              # NPC für Spec-Auswahl (~8 KB)
├── apps/                                   # CI-Helpers (falls vorhanden)
├── include.sh                              # Build-Integration
├── pull_request_template.md
├── CLAUDE.md                               # Detaillierte Inhalts-Doku
├── log.md                                  # Commit-Log (modular)
├── data_structure.md                       # Diese Datei
└── functions.md                            # Mechanik-Referenz
```

## Datei-Zwecke

| Datei | Zweck |
|-------|-------|
| `conf/paragon_itemgen.conf.dist` | `Enable`, `OnLoot`/`OnCreate`/`OnQuest`/`OnVendor`, `ScalingFactor`, `MinParagonLevel`, `MinItemLevel`, `BlockTrade`, `BlockMail`, Quality-Multiplikatoren, `CursedChance`, `CursedMultiplier`, `CursedVisualKit` |
| `conf/conf.sh.dist` | SQL-Pfad-Registrierung |
| `data/sql/db-characters/paragon_item_enchants.sql` | Schema: `character_paragon_role`, `character_paragon_item` |
| `data/sql/db-world/paragon_itemgen_enchantments.sql` | DELETE+INSERT für ~11.323 Custom-Enchantment-IDs (900001-916666 Stat, 920001 Cursed-Marker) |
| `data/sql/db-world/paragon_passive_spells.sql` | `paragon_passive_spell_pool` + `paragon_spec_spell_assign` mit `CREATE TABLE IF NOT EXISTS` |
| `Paragon_System_LUA/ItemGen_Server.lua` | AIO-Handler: `RequestData`, `ReceiveSlots` (Server pushed bei Login + Bag-Update); decodiert `enchantmentId → (statIndex, amount)` |
| `Paragon_System_LUA/ItemGen_Client.lua` | Cache pro `(bag, slot)`; hookt `GameTooltip:SetX()`-Methoden für Custom-Tooltip-Zeilen; DBC-Text-Fallback |
| `src/MP_loader.cpp` | `Addmod_paragon_itemgenScripts()` ruft `AddParagonItemGenScripts`, `AddParagonItemGenCommands`, `AddParagonItemGenNPC` |
| `src/ParagonItemGen.h` | Enums `ParagonStatIndex` (0=Sta,1=Str,...,16=ManaRegen), `ParagonRole` (0=Tank,1=DPS,2=Healer); Konstanten für Slot-IDs, Multiplier-Defaults |
| `src/ParagonItemGen.cpp` | `ApplyParagonEnchantment`, `RollStatAmount`, `RollCursed`, Hook-Implementierungen, `LoadPassiveSpellPool`, `LoadSpecSpellAssign`, Trade-/Mail-Restriktion |
| `src/ParagonItemGenCommands.cpp` | `.paragon role`, `.paragon stat`, `.paragon info` CommandScript |
| `src/ParagonItemGenNPC.cpp` | NPC-Gossip für Spec-Auswahl (talent-spec → `character_paragon_spec`) |

## Größenhinweise (Stand: 2026-05-01)

- ⚠️ `src/ParagonItemGen.cpp` ist **~37 KB** — knapp am Lese-Limit. Bei Bedarf chunked Read mit offset/limit.
- `Paragon_itemgen_enchantments.sql` kann **groß** werden (>100 KB für 11.323 Einträge) — niemals am Stück lesen, nur greppen.
- alle anderen Dateien: < 13 KB

## Externe Abhängigkeiten

- **azerothcore-wotlk** (Core): `PlayerScript`, `WorldScript`, `CommandScript`, `CreatureScript`, Prepared-Statements für World+Characters DB.
- **AIO Framework**: aus `share-public/AIO_Server/`.
- **mod-paragon**: liest `character_paragon.level` zur Skalierung. Ohne mod-paragon ist `paragonLevel = 0` und keine Items werden enchantet.
- **Spell.dbc**: 99 Custom-Spell-IDs (950001-950099) für Passives müssen in der Server-Spell.dbc existieren.

## DB-Tabellen

### `acore_characters`
| Tabelle | PK | Inhalt |
|---------|----|--------|
| `character_paragon_role` | `characterID` | role (0/1/2), mainStat (3/4/5/6) |
| `character_paragon_item` | `itemGuid` | paragonLevel, role, mainStat, combatRating1/2, statAmount, cursed |
| `character_paragon_spec` | `characterID` | specId für Cursed-Passive-Pool |

### `acore_world`
| Tabelle | Inhalt |
|---------|--------|
| `spellitemenchantment_dbc` | DBC-Override (~11.323 Einträge: Stats + Cursed-Marker + 99 Passives) |
| `paragon_passive_spell_pool` | spellId, enchantmentId, name, category, minParagonLevel, minItemLevel |
| `paragon_spec_spell_assign` | specId, enchantmentId, weight |

## Wo ist was nicht?

- **Keine eigene NPC-Spawn-Definition** — der NPC muss separat via `creature_template`/`creature` SQL gespawnt werden.
- **Kein Custom-Build-Slot** — wird via AzerothCore Auto-Detection eingebunden.
- **Keine Unit-Tests**.
