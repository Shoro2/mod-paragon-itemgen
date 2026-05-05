# INDEX — mod-paragon-itemgen

Entry point for AI tools.

## Files in this repo

| File | Size | Purpose |
|-------|------:|-------|
| `INDEX.md` | <1 KB | this file — navigation |
| `CLAUDE.md` | ~5 KB | **What** this module is, what role, which IDs/DB tables |
| `data_structure.md` | ~5 KB | Folder/file listing |
| `functions.md` | ~8 KB | **How**: 5-slot system, scaling, cursed roll, AIO tooltip pipeline |
| `log.md` | ~2 KB | Commit log |
| `todo.md` | ~1 KB | open tasks |

## Cross-Repo

- Project overview: [`share-public/AI_GUIDE.md`](https://github.com/Shoro2/share-public/blob/main/AI_GUIDE.md)
- Cross-repo history: [`share-public/claude_log.md`](https://github.com/Shoro2/share-public/blob/main/claude_log.md)
- Custom IDs registry: [`share-public/docs/06-custom-ids.md`](https://github.com/Shoro2/share-public/blob/main/docs/06-custom-ids.md)
- DBC system: [`share-public/docs/03-spell-system.md`](https://github.com/Shoro2/share-public/blob/main/docs/03-spell-system.md)
- DBC patcher tooling: [`share-public/python_scripts/patch_dbc.py`](https://github.com/Shoro2/share-public/blob/main/python_scripts/patch_dbc.py)

## Quick Facts

- 5-slot bonus-stat enchantment system on looted/crafted/quested/vendor-bought items
- Scaling via Paragon level + item quality (cap 666)
- 4 role pools (Tank / DPS Melee / DPS Caster / Healer); the DPS pool is selected automatically by `mainStat`
- **Cursed items** (1% default): all stats × 1.5, soulbound, shadow visual, exclusive passive spells
- DB: 3 tables in `acore_characters`, 2 in `acore_world` + `spellitemenchantment_dbc` override (~11,323 custom enchants)
- AIO-based tooltip system (no client DBC patch needed for inventory/equipment)
