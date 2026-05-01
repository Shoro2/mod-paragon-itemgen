# INDEX — mod-paragon-itemgen

Einstiegspunkt für KI-Tools.

## Files in diesem Repo

| Datei | Größe | Zweck |
|-------|------:|-------|
| `INDEX.md` | <1 KB | diese Datei — Navigation |
| `CLAUDE.md` | ~5 KB | **Was** ist dieses Modul, welche Rolle, welche IDs/DB-Tabellen |
| `data_structure.md` | ~5 KB | Folder/File-Auflistung |
| `functions.md` | ~8 KB | **Wie**: 5-Slot-System, Skalierung, Cursed-Roll, AIO-Tooltip-Pipeline |
| `log.md` | ~2 KB | Commit-Log |
| `todo.md` | ~1 KB | offene Aufgaben |

## Cross-Repo

- Projekt-Übersicht: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-Repo-Historie: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- Custom-IDs Registry: [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md)
- DBC-System: [`share-public/docs/03-spell-system.md`](https://github.com/Shoro2/share-public/blob/main/docs/03-spell-system.md)
- DBC-Patcher-Tooling: [`share-public/python_scripts/patch_dbc.py`](https://github.com/Shoro2/share-public/blob/main/python_scripts/patch_dbc.py)

## Quick Facts

- 5-Slot-Bonus-Stat-Enchantment-System auf gelooteten/gecrafteten/gequesteten/vendor-gekauften Items
- Skalierung über Paragon-Level + Item-Quality (cap 666)
- 4 Rollen-Pools (Tank / DPS-Melee / DPS-Caster / Healer); DPS-Pool wählt sich automatisch nach `mainStat`
- **Cursed Items** (1% Default): alle Stats × 1.5, Soulbound, Shadow-Visual, exklusive Passive-Spells
- DB: 3 Tabellen in `acore_characters`, 2 in `acore_world` + `spellitemenchantment_dbc`-Override (~11.323 Custom-Enchants)
- AIO-basiertes Tooltip-System (kein Client-DBC-Patch nötig für Inventar/Equipment)
