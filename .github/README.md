# mod-paragon-itemgen

An [AzerothCore](https://www.azerothcore.org/) module that adds **Paragon-level-based item scaling**. When players loot, craft, buy, or receive quest items, bonus stats are automatically applied as enchantments based on the player's Paragon level, chosen role, and main stat.

Requires [mod-paragon](https://github.com/Shoro2/mod-paragon) for the Paragon progression system.

## Features

- **5-slot enchantment system** on weapons and armor:

| Slot | Content | Source |
|------|---------|--------|
| 0 | Stamina | Always applied |
| 1 | Main Stat | Player choice (Str/Agi/Int/Spi) |
| 2 | Combat Rating | Random from role pool |
| 3 | Combat Rating | Random from role pool (no duplicate) |
| 4 | Talent Spell | Role-based (TODO: custom spells) |

- **3 roles** with distinct combat rating pools:

| Role | Combat Rating Pool |
|------|--------------------|
| Tank | Dodge, Parry, Defense, Block, Hit, Expertise |
| DPS | Crit, Haste, Hit, Armor Pen, Expertise, Attack Power, Spell Power |
| Healer | Crit, Haste, Spell Power, Mana Regen |

- **Scaling formula**: `ceil(paragonLevel * scalingFactor * qualityMultiplier)`
- **Permanent stats**: Items keep their enchantments forever. Changing role/stat only affects *new* items.
- **Transfer restrictions**: Trade and mail of paragon-enchanted items is blocked to players with a lower Paragon level.

## Player Commands

| Command | Description | Restriction |
|---------|-------------|-------------|
| `.paragon role tank\|dps\|healer` | Set your role | Rested area only |
| `.paragon stat str\|agi\|int\|spi` | Set your main stat | Rested area only |
| `.paragon info` | Show current role, stat, and rating pool | None |

## Scaling Examples

With `ScalingFactor = 0.5` (default):

| Paragon Level | Uncommon (×0.5) | Rare (×0.75) | Epic (×1.0) | Legendary (×1.25) |
|---------------|-----------------|--------------|-------------|-------------------|
| 10 | +3 per stat | +4 | +5 | +7 |
| 20 | +5 per stat | +8 | +10 | +13 |
| 50 | +13 per stat | +19 | +25 | +32 |
| 100 | +25 per stat | +38 | +50 | +63 |

Each item receives 4 stat enchantments (Stamina + Main Stat + 2 Combat Ratings), so total bonus is 4× the above values.

## Installation

1. Clone into `azerothcore-wotlk/modules/`:
   ```sh
   cd modules/
   git clone https://github.com/Shoro2/mod-paragon-itemgen.git
   ```
2. Re-run CMake and rebuild the worldserver.
3. Execute the SQL files:
   - `data/sql/db-world/paragon_itemgen_enchantments.sql` → world database
   - `data/sql/db-characters/paragon_item_enchants.sql` → characters database
4. Copy `conf/paragon_itemgen.conf.dist` to your server's config directory and adjust values.

## Configuration

See [`conf/paragon_itemgen.conf.dist`](conf/paragon_itemgen.conf.dist) for all options:

| Option | Default | Description |
|--------|---------|-------------|
| `ParagonItemGen.Enable` | 1 | Enable/disable module |
| `ParagonItemGen.ScalingFactor` | 0.5 | Base scaling multiplier |
| `ParagonItemGen.MinParagonLevel` | 1 | Minimum Paragon level for enchantments |
| `ParagonItemGen.MinItemLevel` | 150 | Minimum item level to receive enchantments |
| `ParagonItemGen.OnLoot` | 1 | Enchant looted items |
| `ParagonItemGen.OnCreate` | 1 | Enchant crafted items |
| `ParagonItemGen.OnQuest` | 1 | Enchant quest reward items |
| `ParagonItemGen.OnVendor` | 1 | Enchant vendor-purchased items |
| `ParagonItemGen.BlockTrade` | 1 | Block trading to lower-paragon players |
| `ParagonItemGen.BlockMail` | 1 | Block mailing to lower-paragon players |
| `ParagonItemGen.QualityMult.*` | varies | Per-quality scaling multipliers |

## Database Tables

### `spellitemenchantment_dbc` (world DB)

3,400 custom enchantment entries (IDs 900001–916200). 17 stat types × 200 amount levels. Each entry has a single `ITEM_ENCHANTMENT_TYPE_STAT` effect.

### `character_paragon_role` (characters DB)

| Column | Type | Description |
|--------|------|-------------|
| `characterID` | INT (PK) | Character GUID |
| `role` | TINYINT | 0=Tank, 1=DPS, 2=Healer |
| `mainStat` | TINYINT | ITEM_MOD value: 3=Agi, 4=Str, 5=Int, 6=Spi |

### `character_paragon_item` (characters DB)

Tracks paragon enchantments on items for transfer restriction enforcement.

| Column | Type | Description |
|--------|------|-------------|
| `itemGuid` | INT (PK) | Item GUID |
| `paragonLevel` | INT | Paragon level at enchantment time |
| `role` | TINYINT | Role used |
| `mainStat` | TINYINT | Main stat used |
| `combatRating1` | TINYINT | First combat rating (ParagonStatIndex) |
| `combatRating2` | TINYINT | Second combat rating (ParagonStatIndex) |
| `statAmount` | INT | Amount per stat |

## Enchantment ID Layout

```
Base ID: 900000
Formula: 900000 + statIndex × 1000 + amount

Stat Index | Stat              | ITEM_MOD | ID Range
-----------|-------------------|----------|------------------
0          | Stamina           | 7        | 900001 – 900200
1          | Strength          | 4        | 901001 – 901200
2          | Agility           | 3        | 902001 – 902200
3          | Intellect         | 5        | 903001 – 903200
4          | Spirit            | 6        | 904001 – 904200
5          | Dodge Rating      | 13       | 905001 – 905200
6          | Parry Rating      | 14       | 906001 – 906200
7          | Defense Rating    | 12       | 907001 – 907200
8          | Block Rating      | 15       | 908001 – 908200
9          | Hit Rating        | 31       | 909001 – 909200
10         | Crit Rating       | 32       | 910001 – 910200
11         | Haste Rating      | 36       | 911001 – 911200
12         | Expertise Rating  | 37       | 912001 – 912200
13         | Armor Penetration | 44       | 913001 – 913200
14         | Spell Power       | 45       | 914001 – 914200
15         | Attack Power      | 38       | 915001 – 915200
16         | Mana Regeneration | 43       | 916001 – 916200

Reserved: 920000+ for talent spell enchantments
```

## Known Limitations / TODO

- **Talent Spell (Slot 4)**: Not yet implemented. Waiting for custom spell creation.
- **Auction House restriction**: AzerothCore has no `CanListAuction` hook. Possible solutions: core patch, `OnAuctionAdd` cancellation, or soulbinding paragon items.
- **PROP_ENCHANTMENT_SLOT conflict**: Items with existing random properties (e.g., "of the Bear") will have those replaced by paragon enchantments.
- **DB queries on every item drop**: Paragon level and role are fetched from DB on each item acquisition. Consider in-memory caching for high-traffic servers.

## Dependencies

- [AzerothCore WotLK](https://github.com/azerothcore/azerothcore-wotlk)
- [mod-paragon](https://github.com/Shoro2/mod-paragon) (provides `character_paragon` table with account-wide Paragon levels)

## License

Released under the [GNU AGPL v3](https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3) license.
