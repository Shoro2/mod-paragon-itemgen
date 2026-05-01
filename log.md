# Change Log — mod-paragon-itemgen

> Minimaler Commit-Log. Eine Zeile pro Änderung mit Verweis auf den Commit.

## 2026

- 2026-04-07 — fix(sql): create paragon_passive_spell_pool and paragon_spec_spell_assign ([7d18b36](https://github.com/Shoro2/mod-paragon-itemgen/commit/7d18b36430dcff50953bc3cc13983a7cd799fefb)) — `CREATE TABLE IF NOT EXISTS` vor DELETE/INSERT, frische AC-Server starteten sonst mit Tabellen-Fehler ab.
- 2026-03-22 — feat: adjust ScalingFactor so cursed legendary @ paragon 666 = +666 stats ([05ff905](https://github.com/Shoro2/mod-paragon-itemgen/commit/05ff905423e0b4fdf49a64787519ad31b16770a5)) — `0.5 → 8/15 (~0.5333)`. Ergibt Cursed Legendary @ 666 = exakt 666 Stat.
- 2026-03-22 — fix(Lua): use GetUInt32Value for PROP_ENCHANTMENT slots 7-11 ([4d8d473](https://github.com/Shoro2/mod-paragon-itemgen/commit/4d8d473ce6b115d4fd35adace80e08713ca673e0)) — Eluna `GetEnchantmentId()` deckt nur Slots 0-6 ab, daher raw UpdateField-Access.
- 2026-03-22 — fix(Lua): AIO-based tooltip display for paragon stats and cursed items ([a8111bb](https://github.com/Shoro2/mod-paragon-itemgen/commit/a8111bb7f7d572647dfa23b3536432020c3c5a8b)) — **architektonischer Schritt**: Tooltip-Daten kommen jetzt vom Server via AIO, nicht mehr aus gepatchter Client-DBC. DBC-Text-Scan bleibt als Fallback.
- 2026-03-20 — chore: remove unused files ([60a563d](https://github.com/Shoro2/mod-paragon-itemgen/commit/60a563df0ce30de92d426d029b6e636f986721f7)).
- 2026-03-18 — docs: update CLAUDE.md with comprehensive resource references ([Merge #21](https://github.com/Shoro2/mod-paragon-itemgen/commit/b25b852023fe187a38ecbeaee01b80bda93c7d93)).

## Konvention

Neue Einträge oben anhängen. Detail-Beschreibungen gehören in den Commit-Body bzw. `share-public/claude_log.md`.
