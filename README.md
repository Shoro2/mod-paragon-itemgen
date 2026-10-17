# mod-paragon-itemgen

Automatic bonus-stat enchantment system for freshly acquired items on an [AzerothCore](https://www.azerothcore.org/) **WoW 3.3.5a (WotLK)** server. Companion of [mod-paragon](https://github.com/Shoro2/mod-paragon); part of the Forgotten Land server project.

Whenever a player loots, crafts, receives from a quest, or buys an item, the module rolls up to **5 enchantment slots** on the item that scale with the player's Paragon level and the item's quality:

| Slot | Contents | Source |
|------|----------|--------|
| 7 | Stamina | always |
| 8 | Main stat (Str / Agi / Int / Spi) | player choice via `.paragon stat <name>` |
| 9 | Combat rating 1 | role pool (Tank / DPS Melee / DPS Caster / Healer), random |
| 10 | Combat rating 2 | role pool, no duplicate of slot 9 |
| 11 | Passive spell **or** "Cursed" marker | cursed items; passive pool depends on the chosen talent spec |

Stats are written into the free `PROP_ENCHANTMENT_SLOT_0..4` and stay on the item permanently. Only newly acquired items are enchanted; existing gear is untouched.

## Features

- **Scaling formula**: `amount = ceil(paragonLevel * ScalingFactor * QualityMultiplier)`, capped at 666. With the default factor a Paragon-666 player on a legendary item lands on +444 per stat (+666 when cursed).
- **Quality multipliers** (defaults): Uncommon `0.5`, Rare `0.75`, Epic `1.0`, Legendary `1.25`.
- **Role pools**: each role rolls combat ratings from its own pool; the DPS pool follows the main stat.
- **Cursed items**: a configurable chance for an item to be cursed: all stats multiplied (default 1.5), soulbound, a shadow visual on the player, and an exclusive passive-spell pool. If mod-forgotten-talents is installed, its *Tainted Craft* / *Dark Bargain* nodes can add percent points to the chance for crafted items / quest rewards (`ParagonItemGen.CursedTalentBonus`).
- **Trade and mail restriction**: items can only go to recipients with an equal or higher Paragon level.
- **AIO tooltips**: the server pushes per-item slot data to the client, so inventory and equipment tooltips show the bonuses without a client DBC patch.
- **Spec-aware passives** for cursed items, chosen at the "Paragon Artificer" NPC.

## Requirements

- AzerothCore WotLK, **the [Shoro2/azerothcore-wotlk](https://github.com/Shoro2/azerothcore-wotlk) fork**. The module uses prepared statements (`CHAR_*_PARAGON_*`, `WORLD_SEL_PARAGON_SPEC_SPELL_ASSIGN`) that are defined in the fork's core database layer, so it does not build against upstream AzerothCore. Build core and module together.
- [mod-paragon](https://github.com/Shoro2/mod-paragon), which provides the Paragon level used for scaling and shares its DB statements. Without it no item is enchanted.
- A Lua engine module ([mod-ale](https://github.com/azerothcore/mod-ale), Eluna-compatible) and the [AIO framework](https://github.com/Rochet2/AIO) for the client tooltip overlay.

## Installation

1. Clone the module into `modules/` next to mod-paragon:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Shoro2/mod-paragon-itemgen.git
   ```
2. Re-run CMake and rebuild the server.
3. SQL: the files under `data/sql/db-characters/` and `data/sql/db-world/` are applied by the AzerothCore DB updater on the next server start. They contain the custom enchantment IDs (about 11,000 `SpellItemEnchantment` rows), the passive-spell pool, and the "Paragon Artificer" NPC (entry `900100`, script `ParagonSpecNPC`).
4. Copy `conf/paragon_itemgen.conf.dist` to your server's module config folder as `paragon_itemgen.conf`.
5. Copy `Paragon_System_LUA/ItemGen_Server.lua` and `ItemGen_Client.lua` into the server's `lua_scripts/` folder (AIO delivers the client file to players, who need the AIO client addon).
6. Optional: patch the client `SpellItemEnchantment.dbc` with the module's enchantment IDs so loot, quest and vendor tooltips also show the bonus text; without it only inventory and equipment tooltips are covered.
7. Restart the world server.

## Configuration

`conf/paragon_itemgen.conf.dist` documents every key. The main ones:

- `ParagonItemGen.Enable` - master toggle; `OnLoot`, `OnCreate`, `OnQuest`, `OnVendor` - per-source toggles.
- `ParagonItemGen.ScalingFactor`, `QualityMult.Uncommon/Rare/Epic/Legendary` - scaling.
- `ParagonItemGen.MinParagonLevel`, `MinItemLevel` - minimum Paragon level and item level to enchant.
- `ParagonItemGen.CursedChance` (percent), `CursedMultiplier`, `CursedVisualKit`, `CursedTalentBonus`.
- `ParagonItemGen.BlockTrade`, `BlockMail` - transfer restrictions.
- `ParagonItemGen.PassiveSpell.Enable`, `PassiveSpell.Chance` - passive spell on slot 11.

## Usage

Player commands (rested area only for `role` and `stat`; they affect only items acquired afterwards):

- `.paragon role tank|dps|healer` - choose the role pool.
- `.paragon stat str|agi|int|spi` - choose the main stat.
- `.paragon info` - show the current role, main stat and spec.

The "Paragon Artificer" NPC lets a player pick a talent specialization, which decides the passive-spell pool of cursed items.

## License

MIT (see `LICENSE`).
