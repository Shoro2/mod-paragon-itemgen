# TODOs — mod-paragon-itemgen

> Offene Aufgaben für dieses Modul. Erledigte TODOs in `log.md` festhalten und hier entfernen.

## Performance

- [ ] **(niedrig)** In-Memory-Cache für ParagonLevel + Role: aktuell DB-Query bei jeder Item-Acquisition. Bei busy Servern > 100 Items/Min Player-induced könnte ein per-Player-Cache (analog mod-paragon) Last reduzieren.

## Korrektheit

- [ ] **(mittel)** Off-by-One in `BasePoints`: `Spell.dbc` speichert `EffectBasePoints = real_value - 1`. Beim Einfügen in `spell_dbc` darauf achten — bestehende Stat-Auras systematisch prüfen, ob "+50" wirklich 50 oder 51 in-game wirkt.
- [ ] **(niedrig)** `paragon_itemgen_enchantments.sql` ist mit ~11.323 Einträgen >100 KB. Migration auf einen Generator-Script-Pfad (`python_scripts/`) wäre wartbarer als statisches SQL.

## Doku

- [ ] **(hoch)** `CLAUDE.md` "Known Issues"-Liste enthält viele bereits erledigte Punkte (`~~strikethrough~~`). Phase B räumt das auf.

## Konvention

Erledigte Items NICHT durchstreichen — entfernen und in `log.md` dokumentieren.
