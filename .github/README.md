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
| 4 | Cursed Marker | "Cursed" label if item rolled cursed |

- **Random stat rolls**: Each stat rolls independently from 1 to the calculated max value
- **Cursed items** (1% chance, configurable): All stats boosted to 150% of max, item becomes soulbound, shadow visual plays
- **3 roles** with distinct combat rating pools:

| Role | Combat Rating Pool |
|------|--------------------|
| Tank | Dodge, Parry, Defense, Block, Hit, Expertise |
| DPS | Crit, Haste, Hit, Armor Pen, Expertise, Attack Power, Spell Power |
| Healer | Crit, Haste, Spell Power, Mana Regen |

- **Scaling formula**: `ceil(paragonLevel * scalingFactor * qualityMultiplier)`, capped at 666
- **Permanent stats**: Items keep their enchantments forever. Changing role/stat only affects *new* items.
- **Transfer restrictions**: Trade and mail of paragon-enchanted items is blocked to players with a lower Paragon level.
- **AIO tooltip enhancement**: Client-side Lua addon colorizes cursed items in purple with a warning line.

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

Each stat rolls **randomly from 1 to the max value** shown above. Cursed items get all stats at 150% of max instead.

Each item receives 4 stat enchantments (Stamina + Main Stat + 2 Combat Ratings).

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
5. (Optional) Copy `Paragon_System_LUA/*.lua` to your server's `lua_scripts/` folder for AIO tooltip enhancement.
6. (Optional) Patch client DBC: `python3 tools/patch_dbc.py SpellItemEnchantment.dbc SpellItemEnchantment_patched.dbc`

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
| `ParagonItemGen.CursedChance` | 1.0 | Chance (%) for cursed roll (0 = disabled) |
| `ParagonItemGen.CursedMultiplier` | 1.5 | Stat multiplier for cursed items (1.5 = 150%) |
| `ParagonItemGen.CursedVisualKit` | 5765 | SpellVisualKit ID for shadow animation |

## Database Tables

### `spellitemenchantment_dbc` (world DB)

11,323 custom enchantment entries (IDs 900001–916666 + 920001). 17 stat types × 666 amount levels, plus one "Cursed" marker. Each stat entry has a single `ITEM_ENCHANTMENT_TYPE_STAT` effect.

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
| `cursed` | TINYINT | 1 if item rolled cursed |

## Enchantment ID Layout

```
Base ID: 900000
Formula: 900000 + statIndex × 1000 + amount

Stat Index | Stat              | ITEM_MOD | ID Range
-----------|-------------------|----------|------------------
0          | Stamina           | 7        | 900001 – 900666
1          | Strength          | 4        | 901001 – 901666
2          | Agility           | 3        | 902001 – 902666
3          | Intellect         | 5        | 903001 – 903666
4          | Spirit            | 6        | 904001 – 904666
5          | Dodge Rating      | 13       | 905001 – 905666
6          | Parry Rating      | 14       | 906001 – 906666
7          | Defense Rating    | 12       | 907001 – 907666
8          | Block Rating      | 15       | 908001 – 908666
9          | Hit Rating        | 31       | 909001 – 909666
10         | Crit Rating       | 32       | 910001 – 910666
11         | Haste Rating      | 36       | 911001 – 911666
12         | Expertise Rating  | 37       | 912001 – 912666
13         | Armor Penetration | 44       | 913001 – 913666
14         | Spell Power       | 45       | 914001 – 914666
15         | Attack Power      | 38       | 915001 – 915666
16         | Mana Regeneration | 43       | 916001 – 916666

920001     | Cursed (marker)   | —        | 920001 (slot 11)

Reserved: 920002+ for talent spell enchantments
```

## Known Limitations / TODO

- **Talent Spell (Slot 4)**: Currently used only for the "Cursed" marker. Custom talent spells (IDs 920002+) are not yet implemented.
- **Auction House restriction**: AzerothCore has no `CanListAuction` hook. Cursed items are soulbound and can't be listed. Non-cursed paragon items can still be auctioned.
- **PROP_ENCHANTMENT_SLOT conflict**: Items with existing random properties (e.g., "of the Bear") will have those replaced by paragon enchantments.
- **DB queries on every item drop**: Paragon level and role are fetched from DB on each item acquisition. Consider in-memory caching for high-traffic servers.

## Dependencies

- [AzerothCore WotLK](https://github.com/azerothcore/azerothcore-wotlk)
- [mod-paragon](https://github.com/Shoro2/mod-paragon) (provides `character_paragon` table with account-wide Paragon levels)

## License

Released under the [GNU AGPL v3](https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3) license.
