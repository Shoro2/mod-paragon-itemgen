# Funktionen & Mechaniken — mod-paragon-itemgen

> Detaillierte Funktions- und Mechanik-Referenz. Inhalts-/Zweck-Doku siehe `CLAUDE.md`.

## Modul-Loader

### `Addmod_paragon_itemgenScripts()` (`src/MP_loader.cpp`)
Ruft drei Sub-Loader: `AddParagonItemGenScripts()`, `AddParagonItemGenCommands()`, `AddParagonItemGenNPC()`.

## 5-Slot-Enchantment-System

WoW 3.3.5 Items haben 5 freie `PROP_ENCHANTMENT_SLOT_*` (Slots 7-11 in der Enchantment-Liste). Diese werden vom Modul belegt:

| Slot | Inhalt | Wann gefüllt |
|------|--------|--------------|
| 7 | Stamina | immer |
| 8 | Main-Stat (Str/Agi/Int/Spi) | immer (`mainStat` aus `character_paragon_role`) |
| 9 | Combat-Rating 1 | immer (Random aus Rollen-Pool) |
| 10 | Combat-Rating 2 | immer (Random, kein Duplikat von 9) |
| 11 | Passive-Spell-Enchant **oder** "Cursed"-Marker (920001) | nur Cursed Items |

## Enchantment-ID-Formel

```
ID = 900000 + statIndex × 1000 + amount
```

mit `statIndex` 0..16 (siehe Enum `ParagonStatIndex` in `ParagonItemGen.h`) und `amount` 1..666.

**Reverse** (für Tooltip-Decoding):
```lua
statIndex = math.floor((id - 900000) / 1000)
amount    = (id - 900000) % 1000
```

Special-IDs:
- `920001` — "Cursed"-Marker (kein Stat-Effekt, nur Label)
- `950001-950099` — Passive-Spell-Enchants (`ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL`, nur Cursed Items)

## Skalierung

```
amount = ceil(paragonLevel × ScalingFactor × QualityMultiplier[quality])
amount = min(amount, 666)
```

`ScalingFactor` Default = `8/15 ≈ 0.5333` (so dass Cursed Legendary @ 666 = exakt 666 Stat).

| Quality | Multiplier (Default) |
|---------|---------------------|
| Uncommon | 0.5 |
| Rare | 0.75 |
| Epic | 1.0 |
| Legendary | 1.25 |

Beispielwerte @ paragonLevel=666:
| | Normal | Cursed (×1.5) |
|---|--------|---------------|
| Uncommon | 178 | 267 |
| Rare | 267 | 401 |
| Epic | 356 | 534 |
| Legendary | 444 | **666** |

Random-Roll pro Slot: `RollStatAmount(maxAmount)` = `random(1, maxAmount)`. Jeder Slot rollt unabhängig.

## Rollen-Pools

Definiert in `ParagonItemGen.cpp` als statische Arrays:

| Rolle | Pool (`ParagonStatIndex`-Werte) |
|-------|--------------------------------|
| Tank (0) | Dodge(5), Parry(6), Defense(7), Block(8), Hit(9), Expertise(12) |
| DPS Melee (1, mainStat=Str/Agi) | Crit(10), Haste(11), Hit(9), ArmorPen(13), Expertise(12), AP(15) |
| DPS Caster (1, mainStat=Int/Spi) | Crit(10), Haste(11), Hit(9), SpellPower(14), ManaRegen(16) |
| Healer (2) | Crit(10), Haste(11), SpellPower(14), ManaRegen(16) |

DPS-Pool wählt sich automatisch via `mainStat` in `PickTwoRandomRatings(role, mainStat, &cr1, &cr2)`.

## Cursed Items

`RollCursed()` returnt true mit Chance `conf_CursedChance` (Default 1.0%).

Bei Cursed:
- alle 4 Stat-Slots: `amount = min(amount × conf_CursedMultiplier, 666)`
- `item->SetBinding(true)` (Soulbound)
- `player->SendPlaySpellVisual(conf_CursedVisualKit)` (Default 5765 = Shadow-Effekt)
- Slot 11:
  - wenn Player `character_paragon_spec` gesetzt → Random-Spell aus `paragon_passive_spell_pool` (gefiltert nach specId via `paragon_spec_spell_assign`, gewichtet, plus `minParagonLevel`/`minItemLevel`-Filter)
  - sonst → Marker-Enchant 920001

`character_paragon_item` wird mit allen Roll-Daten persistiert (für Trade/Mail-Restriction).

## Hook-Punkte (PlayerScript)

| Hook | Trigger | Wirkung |
|------|---------|---------|
| `OnPlayerLootItem` | Loot von Mob/Chest | `ApplyParagonEnchantment` wenn `OnLoot=true` |
| `OnPlayerCreateItem` | Crafting | dito wenn `OnCreate=true` |
| `OnPlayerQuestRewardItem` | Quest-Reward | dito wenn `OnQuest=true` |
| `OnPlayerAfterStoreOrEquipNewItem` | Vendor-Kauf | dito wenn `OnVendor=true` |
| `OnPlayerCanSetTradeItem` | Trade | block wenn `BlockTrade=true` und `targetParagonLevel < itemParagonLevel` |
| `OnPlayerCanSendMail` | Mail | block wenn `BlockMail=true` und `recipientParagonLevel < itemParagonLevel` |

## Eligibility-Check (`IsEligibleItem`)

```cpp
bool IsEligibleItem(Item* item) {
    ItemTemplate const* tpl = item->GetTemplate();
    if (tpl->Class != ITEM_CLASS_WEAPON && tpl->Class != ITEM_CLASS_ARMOR) return false;
    if (tpl->Quality < ITEM_QUALITY_UNCOMMON) return false;
    if (tpl->ItemLevel < conf_MinItemLevel) return false;
    if (paragonLevel < conf_MinParagonLevel) return false;
    if (ItemHasParagonEnchantment(item)) return false; // schon enchantet
    return true;
}
```

## Slot-Read in Lua (kritisch)

Eluna's `Item:GetEnchantmentId(slot)` deckt nur Slots 0-6 ab (`MAX_INSPECTED_ENCHANTMENT_SLOT`). Für Slots 7-11 muss raw-UpdateField-Zugriff gemacht werden:

```lua
-- ItemGen_Server.lua
local PROP_ENCHANT_FIELD_OFFSET = 0x12  -- ITEM_FIELD_ENCHANTMENT_1_1 + slot*3
local function ReadProp(item, slot)
    local fieldOffset = PROP_ENCHANT_FIELD_OFFSET + (slot - 7) * 3
    return item:GetUInt32Value(fieldOffset)
end
```

Slot-Mapping: PROP_0=7, PROP_1=8, ..., PROP_4=11.

## AIO-Tooltip-System (seit März 2026)

### Server (`ItemGen_Server.lua`)
1. Bei `OnLogin` und `OnInventoryChange`: scannt für jedes Inventar-Item die Slots 7-11 raw.
2. Decodiert `(statIndex, amount)` aus den Enchantment-IDs via Formel.
3. Sendet pro Item-Position `(bag, slot, slot_data[])` an Client via AIO.

### Client (`ItemGen_Client.lua`)
1. Cache: `paragonItems[bag][slot] = {sta, mainStat, cr1, cr2, cursed, passiveSpellId}`
2. Hookt `GameTooltip:SetBagItem`, `SetInventoryItem`, `SetMerchantItem`, `SetLootItem`, ... 
3. Pro Tooltip: passendes Cache-Entry suchen, Custom-Lines an Tooltip anhängen ("Paragon +X Stamina", "Paragon +Y Strength", ..., gold/lila Färbung).
4. Fallback: wenn Cache leer (Vendor/Loot ohne bag/slot) → DBC-Text-Scan auf "Paragon +", "Cursed", "Passive:" (greift nur bei gepatchter Client-DBC).

→ Damit funktioniert das Tooltip-System **ohne** Client-DBC-Patch für Inventar/Equipment, mit Patch zusätzlich für Loot/Quest/Vendor.

## Chat-Commands (`.paragon`)

```
.paragon role tank|dps|healer    # erfordert PLAYER_FLAGS_RESTING
.paragon stat str|agi|int|spi    # erfordert PLAYER_FLAGS_RESTING
.paragon info                    # zeigt aktuelle Rolle, MainStat, Paragon-Level
```

## NPC (Spec-Auswahl)

Implementiert in `ParagonItemGenNPC.cpp`. Gossip listet alle Talent-Specs (Talent-Tab IDs aus `talenttab_dbc`); Auswahl persistiert in `character_paragon_spec`. Beeinflusst nur den Cursed-Passive-Pool.

## Konfigurations-Optionen (Auszug)

| Schlüssel | Default | Wirkung |
|-----------|---------|---------|
| `ParagonItemGen.Enable` | true | Master-Toggle |
| `ParagonItemGen.OnLoot/OnCreate/OnQuest/OnVendor` | true | pro Hook |
| `ParagonItemGen.ScalingFactor` | 0.5333 (8/15) | Stat/Level-Multiplikator |
| `ParagonItemGen.MinParagonLevel` | 1 | Mindest-Level für Apply |
| `ParagonItemGen.MinItemLevel` | 150 | Mindest-iLvl für Apply |
| `ParagonItemGen.QualityMult.Uncommon/Rare/Epic/Legendary` | 0.5/0.75/1.0/1.25 | Quality-Multiplikator |
| `ParagonItemGen.CursedChance` | 1.0 | % |
| `ParagonItemGen.CursedMultiplier` | 1.5 | × Cursed-Stats |
| `ParagonItemGen.CursedVisualKit` | 5765 | SpellVisualKit-ID |
| `ParagonItemGen.BlockTrade/BlockMail` | true | Restriction-Toggle |

## Bekannte Einschränkungen

- **Auction House**: AzerothCore hat keinen `CanCreateAuction`-Hook. `OnAuctionAdd` ist void → Cursed Items sind ohnehin Soulbound, normale Paragon-Items theoretisch handelbar.
- **Random Properties Override**: Items mit Vanilla-Random-Properties ("of the Bear") werden überschrieben — Spieler bekommt Chat-Hinweis.
- **Off-by-One in `BasePoints`**: `Spell.dbc` speichert `EffectBasePoints = real_value - 1`. Beim Einfügen in `spell_dbc` darauf achten.
- **In-Memory-Cache** für ParagonLevel/Role wäre sinnvoll — aktuell DB-Query pro Item-Acquisition.
