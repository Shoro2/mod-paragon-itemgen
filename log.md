# Change Log — mod-paragon-itemgen

> Minimal commit log. One line per change with a reference to the commit.

## 2026

- 2026-10-08 — feat(pool): the 45 passives of the operator's second concept list join the pool - `tools/gen_class_passives.py` places the new Feral lines (901036/901037/901039 tank, 901052-901054 DPS); 218 class passives, enchantments 950007-950224; the workbench loads 449 spec-spell assignments across 31 specs (T1); branch `claude/custom-spells-revision-c66d21fd`

- 2026-10-08 — feat(pool): the custom class spells of mod-custom-spells' `/spells` picker are cursed-item passives - `tools/gen_class_passives.py` generates `paragon_passive_spells_class.sql` (173 spells, enchantments 950007-950179 frozen in `data/class_passive_enchants.json`, weight 10 per spec, concept spec placement, the four actives excluded); the six Arms rows moved there from `paragon_passive_spells.sql`; passive band 950001-950999 (`PARAGON_PASSIVE_ENCHANT_MAX`, `ItemGen_Server.lua`). T1: the workbench loads 404 spec-spell assignments across 31 specs; branch `claude/custom-spells-rework-c66d21fd`

- 2026-09-28 — feat(Core): an API for other modules - `ParagonItemGenSetProfile` (role, main stat, spec in one transaction) and `ParagonItemGenRollCursed` (a forced cursed roll with a given profile, optionally quiet; `CursedContext::Module`); `ApplyParagonEnchantment` reports success - for mod-ptr-template's templates (the operator: template gear rolls cursed at the Paragon level)

- 2026-09-10 — feat(cursed): crafting and quest-reward cursed chance gains the Forgotten Talents tagged bonus (76002/76003) ([1605a7c](https://github.com/Shoro2/mod-paragon-itemgen/commit/1605a7cecfcec271144b4472e1ae978fbd5bc686)) — `RollCursed(Player const*, CursedContext)`, `CursedChanceFor` adds the tagged dummy-aura amount as percent points (clamped 0..100), `ParagonItemGen.CursedTalentBonus`; branch `claude/pdv2-round-e-63ac9a2a` (PDv2 Round E / WP6, not merged). Review fix ([547f4de](https://github.com/Shoro2/mod-paragon-itemgen/commit/547f4deb39e72e1731da2c5df5b791eff63b810d)): `RollCursed` gates on the raw `CursedChance <= 0` before the bonus, so `0 = disabled` stays a kill switch.

- 2026-04-07 — fix(sql): create paragon_passive_spell_pool and paragon_spec_spell_assign ([7d18b36](https://github.com/Shoro2/mod-paragon-itemgen/commit/7d18b36430dcff50953bc3cc13983a7cd799fefb)) — `CREATE TABLE IF NOT EXISTS` before DELETE/INSERT; otherwise fresh AC servers aborted with a table error.
- 2026-03-22 — feat: adjust ScalingFactor so cursed legendary @ paragon 666 = +666 stats ([05ff905](https://github.com/Shoro2/mod-paragon-itemgen/commit/05ff905423e0b4fdf49a64787519ad31b16770a5)) — `0.5 → 8/15 (~0.5333)`. Yields cursed legendary @ 666 = exactly 666 stat.
- 2026-03-22 — fix(Lua): use GetUInt32Value for PROP_ENCHANTMENT slots 7-11 ([4d8d473](https://github.com/Shoro2/mod-paragon-itemgen/commit/4d8d473ce6b115d4fd35adace80e08713ca673e0)) — Eluna `GetEnchantmentId()` only covers slots 0-6, so raw UpdateField access is used.
- 2026-03-22 — fix(Lua): AIO-based tooltip display for paragon stats and cursed items ([a8111bb](https://github.com/Shoro2/mod-paragon-itemgen/commit/a8111bb7f7d572647dfa23b3536432020c3c5a8b)) — **architectural step**: tooltip data now comes from the server via AIO, no longer from a patched client DBC. The DBC text scan remains as a fallback.
- 2026-03-20 — chore: remove unused files ([60a563d](https://github.com/Shoro2/mod-paragon-itemgen/commit/60a563df0ce30de92d426d029b6e636f986721f7)).
- 2026-03-18 — docs: update CLAUDE.md with comprehensive resource references ([Merge #21](https://github.com/Shoro2/mod-paragon-itemgen/commit/b25b852023fe187a38ecbeaee01b80bda93c7d93)).

## Convention

Append new entries at the top. Detailed descriptions belong in the commit body or in `share-public/claude_log.md`.
