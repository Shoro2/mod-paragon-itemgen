# mod-paragon-itemgen

Automatic bonus-stat enchantment system for freshly acquired items on an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server.

## What it does

Whenever a player loots, crafts, quests, or buys an item, the module rolls up to **5 enchantment slots** on the item that scale with the player's Paragon level (from [mod-paragon](https://github.com/Shoro2/mod-paragon)) and the item's quality:

| Slot | Contents | Source |
|------|----------|--------|
| 7 | Stamina | always |
| 8 | Main stat (Str / Agi / Int / Spi) | player choice via `.paragon stat <name>` |
| 9 | Combat rating 1 | role pool (Tank / DPS Melee / DPS Caster / Healer), random |
| 10 | Combat rating 2 | role pool, no duplicate of slot 9 |
| 11 | Passive spell **or** "Cursed" marker | only on cursed items |

Stats are written into the free `PROP_ENCHANTMENT_SLOT_0..4` and stay on the item permanently — only newly acquired items get enchanted, existing gear is untouched.

## Key features

- **Scaling formula**: `amount = ceil(paragonLevel × ScalingFactor × QualityMultiplier)`, capped at 666. Per default a Paragon-666 player on a legendary item lands on exactly +666 per stat (cursed).
- **Quality multipliers** (defaults): Uncommon `0.5`, Rare `0.75`, Epic `1.0`, Legendary `1.25`
- **Role pools**: each role rolls combat ratings from its own pool; the DPS pool selects automatically by `mainStat`
- **Cursed items** (default 1 % chance in code, 50 % in the shipped conf): all stats × 1.5, soulbound, shadow visual, exclusive passive-spell pool. Since Round E / WP6 the Forgotten Talents nodes *Tainted Craft* / *Dark Bargain* add +2…10 percent points for crafted items / quest rewards (`ParagonItemGen.CursedTalentBonus`), read from the aura tag `EffectMiscValue` 76002 / 76003 — never from a spell id
- **Trade & mail restriction**: items can only be transferred to recipients with equal-or-higher Paragon level
- **AIO-based tooltip system**: the server pushes per-item slot data (`bag, slot`) to the client; tooltips show the bonuses without requiring a client-side DBC patch for inventory/equipment
- **Spec-aware passives** for cursed items via in-game NPC gossip
- 5-row chat command interface: `.paragon role`, `.paragon stat`, `.paragon info`

## Installation

1. Place this module inside the AzerothCore `modules/` directory **next to [mod-paragon](https://github.com/Shoro2/mod-paragon)**:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-paragon-itemgen.git
   ```
2. Re-run CMake and build the server:
   ```bash
   cd ../build
   cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DSCRIPTS=static -DMODULES=static
   make -j$(nproc) && make install
   ```
3. Apply the SQL files shipped under `data/sql/db-characters/` and `data/sql/db-world/` (the AzerothCore SQL updater picks them up automatically). The world-DB import includes ~11,323 custom enchantment IDs.
4. Copy the config and adjust if needed:
   ```bash
   cp $HOME/azeroth-server/etc/paragon_itemgen.conf.dist $HOME/azeroth-server/etc/paragon_itemgen.conf
   ```
5. The client side requires the [AIO addon](https://github.com/Rochet2/AIO) for the tooltip overlay. Optional: pre-patch the client `SpellItemEnchantment.dbc` via `share-public/python_scripts/patch_dbc.py` to also cover loot/quest/vendor tooltips.
6. Restart the world server.

## Configuration (excerpt)

`conf/paragon_itemgen.conf.dist`:

- `ParagonItemGen.Enable` — master toggle
- Per-hook toggles: `OnLoot`, `OnCreate`, `OnQuest`, `OnVendor`
- `ParagonItemGen.ScalingFactor` (default `0.5333` = `8/15`)
- `ParagonItemGen.MinParagonLevel`, `MinItemLevel`
- Quality multipliers: `QualityMult.Uncommon/Rare/Epic/Legendary`
- `ParagonItemGen.CursedChance`, `CursedMultiplier`, `CursedVisualKit`, `CursedTalentBonus` (Forgotten Talents +% on crafting / quest rewards)
- `ParagonItemGen.BlockTrade`, `BlockMail`

## Requirements

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (WoW 3.3.5a / WotLK)
- [mod-paragon](https://github.com/Shoro2/mod-paragon) — provides the Paragon level used for scaling. Without it, no items get enchanted (`MinParagonLevel` check fails for everyone).
- [AIO framework](https://github.com/Rochet2/AIO) — for the client-side tooltip overlay

## Project context

Part of a multi-repo project. Items pass through this module on every loot/craft/quest/vendor event, then through [mod-loot-filter](https://github.com/Shoro2/mod-loot-filter) for filtering. Cross-cutting documentation lives in [share-public](https://github.com/Shoro2/share-public).

## License

GPL v2 (see `LICENSE`).
