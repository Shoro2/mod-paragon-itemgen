# Functions & mechanics — mod-paragon-itemgen

> Detailed function and mechanics reference. For content/purpose docs see `CLAUDE.md`.

## Module loader

### `Addmod_paragon_itemgenScripts()` (`src/MP_loader.cpp`)
Calls three sub-loaders: `AddParagonItemGenScripts()`, `AddParagonItemGenCommands()`, `AddParagonItemGenNPC()`.

## 5-slot enchantment system

WoW 3.3.5 items have 5 free `PROP_ENCHANTMENT_SLOT_*` slots (slots 7-11 in the enchantment list). The module fills these:

| Slot | Contents | When filled |
|------|--------|--------------|
| 7 | Stamina | always |
| 8 | Main stat (Str/Agi/Int/Spi) | always (`mainStat` from `character_paragon_role`) |
| 9 | Combat rating 1 | always (random from role pool) |
| 10 | Combat rating 2 | always (random, no duplicate of slot 9) |
| 11 | Passive spell enchant **or** "Cursed" marker (920001) | cursed items only |

## Enchantment ID formula

```
ID = 900000 + statIndex × 1000 + amount
```

with `statIndex` 0..16 (see enum `ParagonStatIndex` in `ParagonItemGen.h`) and `amount` 1..666.

**Reverse** (for tooltip decoding):
```lua
statIndex = math.floor((id - 900000) / 1000)
amount    = (id - 900000) % 1000
```

Special IDs:
- `920001` — "Cursed" marker (no stat effect, label only)
- `950001-950099` — passive-spell enchants (`ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL`, cursed items only)

## Scaling

```
amount = ceil(paragonLevel × ScalingFactor × QualityMultiplier[quality])
amount = min(amount, 666)
```

`ScalingFactor` default = `8/15 ≈ 0.5333` (so cursed legendary @ 666 = exactly 666 stat).

| Quality | Multiplier (default) |
|---------|---------------------|
| Uncommon | 0.5 |
| Rare | 0.75 |
| Epic | 1.0 |
| Legendary | 1.25 |

Example values @ paragonLevel=666:
| | Normal | Cursed (×1.5) |
|---|--------|---------------|
| Uncommon | 178 | 267 |
| Rare | 267 | 401 |
| Epic | 356 | 534 |
| Legendary | 444 | **666** |

Random roll per slot: `RollStatAmount(maxAmount)` = `random(1, maxAmount)`. Each slot rolls independently.

## Role pools

Defined in `ParagonItemGen.cpp` as static arrays:

| Role | Pool (`ParagonStatIndex` values) |
|-------|--------------------------------|
| Tank (0) | Dodge(5), Parry(6), Defense(7), Block(8), Hit(9), Expertise(12) |
| DPS Melee (1, mainStat=Str/Agi) | Crit(10), Haste(11), Hit(9), ArmorPen(13), Expertise(12), AP(15) |
| DPS Caster (1, mainStat=Int/Spi) | Crit(10), Haste(11), Hit(9), SpellPower(14), ManaRegen(16) |
| Healer (2) | Crit(10), Haste(11), SpellPower(14), ManaRegen(16) |

The DPS pool is selected automatically via `mainStat` in `PickTwoRandomRatings(role, mainStat, &cr1, &cr2)`.

## Cursed items

`RollCursed(player, context)` returns true with chance `CursedChanceFor(player, context)` = `conf_CursedChance` (default 1.0 % in code, 50 % in the shipped conf) plus, while `ParagonItemGen.CursedTalentBonus` is on, the Forgotten Talents bonus for the context: `CursedContext::Create` reads the aura tag **76002** (*Tainted Craft*, 2/4/6/8/10), `CursedContext::QuestReward` the tag **76003** (*Dark Bargain*, the same); `Loot` and `Vendor` add nothing. The bonus is `TaggedAuraAmount(player, tag)` — the largest `GetAmount()` among the player's `SPELL_AURA_DUMMY` effects whose `GetMiscValue()` equals the tag, 0 when absent — so this module never names an FT spell id and the FT content may renumber freely (Round E / WP6). The sum is clamped to 0..100, and `CursedChance = 0` still disables cursed items entirely — the raw base is gated before the bonus is added, so the talent raises a rate the operator allowed and never resurrects one they turned off.

When cursed:
- all 4 stat slots: `amount = min(amount × conf_CursedMultiplier, 666)`
- `item->SetBinding(true)` (soulbound)
- `player->SendPlaySpellVisual(conf_CursedVisualKit)` (default 5765 = shadow effect)
- Slot 11:
  - if the player has `character_paragon_spec` set → random spell from `paragon_passive_spell_pool` (filtered by specId via `paragon_spec_spell_assign`, weighted, plus `minParagonLevel`/`minItemLevel` filter)
  - otherwise → marker enchant 920001

`character_paragon_item` is persisted with all roll data (for trade/mail restriction).

## Hook points (PlayerScript)

| Hook | Trigger | Effect |
|------|---------|---------|
| `OnPlayerLootItem` | Loot from mob/chest | `ApplyParagonEnchantment` if `OnLoot=true` |
| `OnPlayerCreateItem` | Crafting | ditto if `OnCreate=true` (`CursedContext::Create` → tag 76002) |
| `OnPlayerQuestRewardItem` | Quest reward | ditto if `OnQuest=true` (`CursedContext::QuestReward` → tag 76003) |
| `OnPlayerAfterStoreOrEquipNewItem` | Vendor purchase | ditto if `OnVendor=true` |
| `OnPlayerCanSetTradeItem` | Trade | block if `BlockTrade=true` and `targetParagonLevel < itemParagonLevel` |
| `OnPlayerCanSendMail` | Mail | block if `BlockMail=true` and `recipientParagonLevel < itemParagonLevel` |

## Eligibility check (`IsEligibleItem`)

```cpp
bool IsEligibleItem(Item* item) {
    ItemTemplate const* tpl = item->GetTemplate();
    if (tpl->Class != ITEM_CLASS_WEAPON && tpl->Class != ITEM_CLASS_ARMOR) return false;
    if (tpl->Quality < ITEM_QUALITY_UNCOMMON) return false;
    if (tpl->ItemLevel < conf_MinItemLevel) return false;
    if (paragonLevel < conf_MinParagonLevel) return false;
    if (ItemHasParagonEnchantment(item)) return false; // already enchanted
    return true;
}
```

## Slot read in Lua (critical)

Eluna's `Item:GetEnchantmentId(slot)` only covers slots 0-6 (`MAX_INSPECTED_ENCHANTMENT_SLOT`). Slots 7-11 require raw UpdateField access:

```lua
-- ItemGen_Server.lua
local PROP_ENCHANT_FIELD_OFFSET = 0x12  -- ITEM_FIELD_ENCHANTMENT_1_1 + slot*3
local function ReadProp(item, slot)
    local fieldOffset = PROP_ENCHANT_FIELD_OFFSET + (slot - 7) * 3
    return item:GetUInt32Value(fieldOffset)
end
```

Slot mapping: PROP_0=7, PROP_1=8, ..., PROP_4=11.

## AIO tooltip system (since March 2026)

### Server (`ItemGen_Server.lua`)
1. On `OnLogin` and `OnInventoryChange`: scans slots 7-11 raw for every inventory item.
2. Decodes `(statIndex, amount)` from the enchantment IDs via the formula.
3. Sends `(bag, slot, slot_data[])` per item position to the client via AIO.

### Client (`ItemGen_Client.lua`)
1. Cache: `paragonItems[bag][slot] = {sta, mainStat, cr1, cr2, cursed, passiveSpellId}`
2. Hooks `GameTooltip:SetBagItem`, `SetInventoryItem`, `SetMerchantItem`, `SetLootItem`, ...
3. Per tooltip: looks up the matching cache entry, appends custom lines to the tooltip ("Paragon +X Stamina", "Paragon +Y Strength", ..., gold/purple coloring).
4. Fallback: if the cache is empty (vendor/loot without bag/slot) → DBC text scan for "Paragon +", "Cursed", "Passive:" (only kicks in with a patched client DBC).

→ This way the tooltip system works **without** a client DBC patch for inventory/equipment, and additionally with a patch for loot/quest/vendor.

## Chat commands (`.paragon`)

```
.paragon role tank|dps|healer    # requires PLAYER_FLAGS_RESTING
.paragon stat str|agi|int|spi    # requires PLAYER_FLAGS_RESTING
.paragon info                    # shows current role, mainStat, Paragon level
```

## NPC (spec selection)

Implemented in `ParagonItemGenNPC.cpp`. The gossip lists all talent specs (talent tab IDs from `talenttab_dbc`); selection persists in `character_paragon_spec`. Affects only the cursed passive pool.

## Configuration options (excerpt)

| Key | Default | Effect |
|-----------|---------|---------|
| `ParagonItemGen.Enable` | true | master toggle |
| `ParagonItemGen.OnLoot/OnCreate/OnQuest/OnVendor` | true | per hook |
| `ParagonItemGen.ScalingFactor` | 0.5333 (8/15) | stat/level multiplier |
| `ParagonItemGen.MinParagonLevel` | 1 | minimum level for apply |
| `ParagonItemGen.MinItemLevel` | 150 | minimum iLvl for apply |
| `ParagonItemGen.QualityMult.Uncommon/Rare/Epic/Legendary` | 0.5/0.75/1.0/1.25 | quality multiplier |
| `ParagonItemGen.CursedChance` | 1.0 | % |
| `ParagonItemGen.CursedTalentBonus` | 1 | Forgotten Talents percent points on crafting / quest rewards (tags 76002 / 76003) |
| `ParagonItemGen.CursedMultiplier` | 1.5 | × cursed stats |
| `ParagonItemGen.CursedVisualKit` | 5765 | SpellVisualKit ID |
| `ParagonItemGen.BlockTrade/BlockMail` | true | restriction toggle |

## Known limitations

- **Auction house**: AzerothCore has no `CanCreateAuction` hook. `OnAuctionAdd` is void → cursed items are soulbound anyway, regular Paragon items theoretically tradable.
- **Random properties override**: items with vanilla random properties ("of the Bear") are overwritten — the player gets a chat hint.
- **Off-by-one in `BasePoints`**: `Spell.dbc` stores `EffectBasePoints = real_value - 1`. Be aware when inserting into `spell_dbc`.
- **In-memory cache** for ParagonLevel/Role would be useful — currently a DB query per item acquisition.
