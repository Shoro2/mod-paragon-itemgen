# TODOs — mod-paragon-itemgen

> Open tasks for this module. Record completed TODOs in `log.md` and remove them here.

## Performance

- [ ] **(low)** In-memory cache for ParagonLevel + Role: currently a DB query happens on every item acquisition. On busy servers > 100 items/min driven by players, a per-player cache (similar to mod-paragon) could reduce load.

## Correctness

- [ ] **(medium)** Off-by-one in `BasePoints`: `Spell.dbc` stores `EffectBasePoints = real_value - 1`. Be aware when inserting into `spell_dbc` — systematically check existing stat auras to confirm "+50" actually applies as 50, not 51, in-game.
- [ ] **(low)** `paragon_itemgen_enchantments.sql` is >100 KB with ~11,323 entries. Migrating to a generator script path (`python_scripts/`) would be more maintainable than static SQL.

## Docs

- [ ] **(high)** The `CLAUDE.md` "Known Issues" list contains many already-resolved items (`~~strikethrough~~`). Phase B will clean this up.

## Convention

Do NOT cross out completed items — remove them and document them in `log.md`.
