# mod-paragon-itemgen

> Lies zuerst [`INDEX.md`](./INDEX.md). Mechanik, Hooks, Skalierungs-Formel: [`functions.md`](./functions.md). Folder-Layout: [`data_structure.md`](./data_structure.md). Offenes: [`todo.md`](./todo.md). Commit-Spur: [`log.md`](./log.md).

## Was ist das Modul?

AzerothCore-Modul für **WoW 3.3.5a (WotLK)**. Wendet beim Looten / Craften / Quest-Reward / Vendor-Kauf automatisch **Bonus-Stat-Enchantments** auf Waffen und Rüstung an. Die Stärke der Bonusse skaliert mit dem **Paragon-Level** (aus `mod-paragon`) des Spielers und dem **Item-Quality**. Items behalten ihre Stats permanent — nur neu bezogene Items werden enchantet.

Konkret werden bis zu 4 Stats + 1 optionaler Special-Slot in die `PROP_ENCHANTMENT_SLOT_0..4` (Item-Slot 7-11) geschrieben:

| Slot | Inhalt | Quelle |
|------|--------|--------|
| 7 | Stamina | immer |
| 8 | Main-Stat (Str/Agi/Int/Spi) | Spielerwahl per `.paragon stat <name>` |
| 9 | Combat-Rating 1 | Rollen-Pool, Random |
| 10 | Combat-Rating 2 | Rollen-Pool, kein Duplikat von Slot 9 |
| 11 | Passive-Spell oder "Cursed"-Marker | nur bei Cursed Items |

## Rolle im Gesamtprojekt

```
mod-paragon  ──── liefert Paragon-Level pro Account ───┐
                                                       │
Loot / Quest / Vendor / Craft → OnPlayerLootItem &c. ──┤
                                                       ▼
                                            mod-paragon-itemgen
                                            ├─ liest Paragon-Level
                                            ├─ liest Role + MainStat
                                            ├─ rollt Stats (mit Cursed-Chance)
                                            └─ schreibt 4-5 Enchantment-Slots
```

Trade-/Mail-Restriktion: Items werden gegen Recipient-Paragon-Level gegengeprüft (`OnPlayerCanSetTradeItem`, `OnPlayerCanSendMail`) — Items dürfen nur an Spieler mit gleichem oder höherem Paragon gehen.

## Custom-Daten

| Typ | Eintrag | Bemerkung |
|-----|--------|-----------|
| **DB-Tabellen (acore_characters)** | `character_paragon_role` | (Role 0=Tank, 1=DPS, 2=Healer) + (mainStat) |
| | `character_paragon_item` | Tracking pro `itemGuid` (paragonLevel, role, mainStat, statAmount, cursed) |
| | `character_paragon_spec` | Spec-Auswahl (für Cursed-Items-Passives) |
| **DB-Tabellen (acore_world)** | `paragon_passive_spell_pool` | Pool verfügbarer Passives (mit Min-Level, Min-Item-Level) |
| | `paragon_spec_spell_assign` | Spec → Spell-Gewichtung |
| | `spellitemenchantment_dbc` | DBC-Override mit ~11.323 Custom-Enchantments |
| **Custom-Enchantments** | 900001-916666 | 17 Stats × 666 Stufen, Formel `900000 + statIndex × 1000 + amount` |
| | 920001 | "Cursed"-Marker (nur Label) |
| | 950001-950099 | Passive-Spell-Enchantments (nur Cursed Items) |
| **Custom-Spells** | nutzt nur die Passives aus `paragon_passive_spell_pool` |
| **AIO-Handler-Namen** | `Paragon_ItemGen` (Server) / `Paragon_ItemGen_Client` (Client) | für Tooltip-Anzeige |
| **Slash-Commands** | (keine) | |
| **GM-Commands (alle SEC_PLAYER)** | `.paragon role tank/dps/healer` (resting required) | |
| | `.paragon stat str/agi/int/spi` (resting required) | |
| | `.paragon info` | zeigt Role, MainStat, ParagonLevel |

## Skalierung (Top-Level)

```
amount = ceil(paragonLevel × ScalingFactor × QualityMultiplier),  cap 666

Default ScalingFactor    = 0.5
Default QualityMult      = 0.5 / 0.75 / 1.0 / 1.25 (uncommon/rare/epic/legendary)
Default CursedChance     = 1.0 %
Default CursedMultiplier = 1.5  (alle Stats × 1.5, gecapped 666)
```

Random-Roll pro Slot von 1 bis `amount`. Details und Konfig-Optionen: [`functions.md`](./functions.md#konfiguration).

## Rollen-Pools (Combat Ratings)

| Rolle | Pool |
|-------|------|
| Tank (0) | Dodge, Parry, Defense, Block, Hit, Expertise |
| DPS Melee (mainStat = Str/Agi) | Crit, Haste, Hit, ArmorPen, Expertise, AP |
| DPS Caster (mainStat = Int/Spi) | Crit, Haste, Hit, SpellPower, ManaRegen |
| Healer (2) | Crit, Haste, SpellPower, ManaRegen |

DPS-Pool wird automatisch über `mainStat` gewählt.

## Tooltip-System (zweischichtig)

1. **AIO-Daten (Primärweg)**: Server liest die Slots 7-11 vom Item-Instance, decodiert `(slot, enchantmentId)` zurück zu `(statIndex, amount)`, sendet via AIO an den Client. Cache nach `(bag, slot)`. **Funktioniert ohne Client-DBC-Patch** für Inventar/Equipment.
2. **DBC-Text-Fallback**: Scant Tooltip-Text auf "Paragon +", "Cursed", "Passive:" — greift bei Loot/Quest/Vendor-Tooltips, wo das Item-Instance nicht direkt am Tooltip hängt. Erfordert vorgepatchte Client-`SpellItemEnchantment.dbc` (`python_scripts/patch_dbc.py`).

## Was das Modul **nicht** tut

- **kein** Re-Enchanting bestehender Items (Stats sind permanent — nur neu erworbene Items werden enchantet)
- **kein** Auction-House-Block (siehe [`todo.md`](./todo.md) — `CanCreateAuction`-Hook fehlt im AzerothCore-Core)
- **kein** Stat-Re-Roll für den Spieler

## Hinweise zur Architektur

- Items mit Random-Properties ("of the Bear" etc.) werden bewusst überschrieben — Paragon-Stats sind wertvoller, der Spieler bekommt eine Chat-Nachricht.
- BasePoints-Off-by-One: `Spell.dbc` speichert `EffectBasePoints = real_value - 1`. Beim Schreiben in `spell_dbc` darauf achten — siehe [`share-public/docs/03-spell-system.md`](https://github.com/Shoro2/share-public/blob/main/docs/03-spell-system.md#off-by-one-basepoints).

## Lizenz

GPL v2.
