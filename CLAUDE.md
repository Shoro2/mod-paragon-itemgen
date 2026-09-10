# mod-paragon-itemgen

> Read [`INDEX.md`](./INDEX.md) first. Mechanics, hooks, scaling formula: [`functions.md`](./functions.md). Folder layout: [`data_structure.md`](./data_structure.md). Open items: [`todo.md`](./todo.md). Commit trail: [`log.md`](./log.md).

## What is the module?

AzerothCore module for **WoW 3.3.5a (WotLK)**. Automatically applies **bonus stat enchantments** to weapons and armor on loot / craft / quest reward / vendor purchase. The strength of the bonuses scales with the player's **Paragon level** (from `mod-paragon`) and the **item quality**. Items keep their stats permanently — only newly acquired items are enchanted.

Specifically, up to 4 stats + 1 optional special slot are written into `PROP_ENCHANTMENT_SLOT_0..4` (item slots 7-11):

| Slot | Contents | Source |
|------|--------|--------|
| 7 | Stamina | always |
| 8 | Main stat (Str/Agi/Int/Spi) | player choice via `.paragon stat <name>` |
| 9 | Combat rating 1 | role pool, random |
| 10 | Combat rating 2 | role pool, no duplicate of slot 9 |
| 11 | Passive spell or "Cursed" marker | only on cursed items |

## Role in the overall project

```
mod-paragon  ──── provides Paragon level per account ───┐
                                                       │
Loot / Quest / Vendor / Craft → OnPlayerLootItem &c. ──┤
                                                       ▼
                                            mod-paragon-itemgen
                                            ├─ reads Paragon level
                                            ├─ reads role + main stat
                                            ├─ rolls stats (with cursed chance)
                                            └─ writes 4-5 enchantment slots
```

Trade/mail restriction: items are cross-checked against the recipient's Paragon level (`OnPlayerCanSetTradeItem`, `OnPlayerCanSendMail`) — items may only go to players with equal or higher Paragon.

## Custom data

| Type | Entry | Note |
|-----|--------|-----------|
| **DB tables (acore_characters)** | `character_paragon_role` | (role 0=Tank, 1=DPS, 2=Healer) + (mainStat) |
| | `character_paragon_item` | Tracking per `itemGuid` (paragonLevel, role, mainStat, statAmount, cursed) |
| | `character_paragon_spec` | Spec selection (for cursed-item passives) |
| **DB tables (acore_world)** | `paragon_passive_spell_pool` | Pool of available passives (with min level, min item level) |
| | `paragon_spec_spell_assign` | Spec → spell weighting |
| | `spellitemenchantment_dbc` | DBC override with ~11,323 custom enchantments |
| **Custom enchantments** | 900001-916666 | 17 stats × 666 levels, formula `900000 + statIndex × 1000 + amount` |
| | 920001 | "Cursed" marker (label only) |
| | 950001-950099 | Passive-spell enchantments (cursed items only) |
| **Custom spells** | only uses the passives from `paragon_passive_spell_pool` |
| **AIO handler names** | `Paragon_ItemGen` (server) / `Paragon_ItemGen_Client` (client) | for tooltip display |
| **Slash commands** | (none) | |
| **GM commands (all SEC_PLAYER)** | `.paragon role tank/dps/healer` (resting required) | |
| | `.paragon stat str/agi/int/spi` (resting required) | |
| | `.paragon info` | shows role, mainStat, ParagonLevel |

## Scaling (top level)

```
amount = ceil(paragonLevel × ScalingFactor × QualityMultiplier),  cap 666

Default ScalingFactor    = 0.5
Default QualityMult      = 0.5 / 0.75 / 1.0 / 1.25 (uncommon/rare/epic/legendary)
Default CursedChance     = 1.0 %
Default CursedMultiplier = 1.5  (all stats × 1.5, capped at 666)
Default CursedTalentBonus = 1  (Round E / WP6: FT aura tags 76002 craft / 76003 quest add percent points to CursedChance)
```

Random roll per slot from 1 to `amount`. Details and config options: [`functions.md`](./functions.md#configuration).

## Role pools (combat ratings)

| Role | Pool |
|-------|------|
| Tank (0) | Dodge, Parry, Defense, Block, Hit, Expertise |
| DPS Melee (mainStat = Str/Agi) | Crit, Haste, Hit, ArmorPen, Expertise, AP |
| DPS Caster (mainStat = Int/Spi) | Crit, Haste, Hit, SpellPower, ManaRegen |
| Healer (2) | Crit, Haste, SpellPower, ManaRegen |

The DPS pool is selected automatically via `mainStat`.

## Tooltip system (two-layered)

1. **AIO data (primary path)**: the server reads slots 7-11 from the item instance, decodes `(slot, enchantmentId)` back to `(statIndex, amount)`, and sends it to the client via AIO. Cache by `(bag, slot)`. **Works without a client DBC patch** for inventory/equipment.
2. **DBC text fallback**: scans tooltip text for "Paragon +", "Cursed", "Passive:" — kicks in for loot/quest/vendor tooltips where the item instance is not directly attached to the tooltip. Requires a pre-patched client `SpellItemEnchantment.dbc` (`python_scripts/patch_dbc.py`).

## What this module does **not** do

- **no** re-enchanting of existing items (stats are permanent — only newly acquired items get enchanted)
- **no** auction-house block (see [`todo.md`](./todo.md) — `CanCreateAuction` hook is missing in the AzerothCore core)
- **no** stat re-roll for the player

## Architecture notes

- Items with random properties ("of the Bear", etc.) are deliberately overwritten — Paragon stats are more valuable, the player gets a chat message.
- BasePoints off-by-one: `Spell.dbc` stores `EffectBasePoints = real_value - 1`. Be aware when writing to `spell_dbc` — see [`share-public/docs/03-spell-system.md`](https://github.com/Shoro2/share-public/blob/main/docs/03-spell-system.md#off-by-one-basepoints).

## License

GPL v2.
