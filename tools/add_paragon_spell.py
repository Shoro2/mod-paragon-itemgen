#!/usr/bin/env python3
"""
Paragon Passive Spell — Enchantment Generator

Creates the SQL statements needed to register a new passive spell
in the Paragon item system after you've already added it to spell_dbc.

Generates:
  1. spellitemenchantment_dbc INSERT  (Effect=3 / EQUIP_SPELL)
  2. paragon_passive_spell_pool INSERT (spell catalog)
  3. paragon_spec_spell_assign INSERTs (per-spec assignments)

Usage:
  python3 add_paragon_spell.py

The script runs interactively and outputs the SQL to stdout
(and optionally appends it to paragon_passive_spells.sql).

Enchantment ID range: 950001–950099
"""

import sys
import os

# ── Spec definitions ────────────────────────────────────────────
SPECS = {
    1:  ("Warrior — Arms",       "Arms"),
    2:  ("Warrior — Fury",       "Fury"),
    3:  ("Warrior — Protection", "WarProt"),
    4:  ("Paladin — Holy",       "HolyPala"),
    5:  ("Paladin — Protection", "ProtPala"),
    6:  ("Paladin — Retribution","Ret"),
    7:  ("DK — Blood",          "Blood"),
    8:  ("DK — Frost",          "DKFrost"),
    9:  ("DK — Unholy",         "Unholy"),
    10: ("Shaman — Elemental",  "Ele"),
    11: ("Shaman — Enhancement","Enhance"),
    12: ("Shaman — Restoration","RestoSham"),
    13: ("Hunter — Beast Mastery","BM"),
    14: ("Hunter — Marksmanship","MM"),
    15: ("Hunter — Survival",   "Surv"),
    16: ("Druid — Balance",     "Balance"),
    17: ("Druid — Restoration", "RestoDru"),
    18: ("Druid — Feral Tank",  "FeralTank"),
    19: ("Druid — Feral DPS",   "FeralDPS"),
    20: ("Rogue — Assassination","Assa"),
    21: ("Rogue — Combat",      "Combat"),
    22: ("Rogue — Subtlety",    "Sub"),
    23: ("Mage — Arcane",       "Arcane"),
    24: ("Mage — Fire",         "Fire"),
    25: ("Mage — Frost",        "MageFrost"),
    26: ("Warlock — Affliction", "Affli"),
    27: ("Warlock — Demonology", "Demo"),
    28: ("Warlock — Destruction","Destro"),
    29: ("Priest — Discipline",  "Disc"),
    30: ("Priest — Holy",        "HolyPri"),
    31: ("Priest — Shadow",      "Shadow"),
}

# ── Preset groups for quick assignment ──────────────────────────
PRESETS = {
    "melee_dps":  [1, 2, 6, 8, 9, 11, 15, 19, 20, 21, 22],
    "ranged_dps": [10, 13, 14, 16, 23, 24, 25, 26, 27, 28, 31],
    "tank":       [3, 5, 7, 18],
    "healer":     [4, 12, 17, 29, 30],
    "all":        list(range(1, 32)),
    "all_dps":    [1, 2, 6, 8, 9, 10, 11, 13, 14, 15, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 31],
}


def prompt_input(msg, default=None):
    if default is not None:
        msg += f" [{default}]"
    val = input(msg + ": ").strip()
    return val if val else (str(default) if default is not None else "")


def prompt_int(msg, default=None, min_val=None, max_val=None):
    while True:
        raw = prompt_input(msg, default)
        try:
            val = int(raw)
            if min_val is not None and val < min_val:
                print(f"  Must be >= {min_val}")
                continue
            if max_val is not None and val > max_val:
                print(f"  Must be <= {max_val}")
                continue
            return val
        except ValueError:
            print("  Enter a valid integer.")


def prompt_yes_no(msg, default="y"):
    val = prompt_input(msg, default).lower()
    return val in ("y", "yes", "1", "true")


def print_specs():
    print("\n  Available specs:")
    for sid, (name, _) in sorted(SPECS.items()):
        print(f"    {sid:2d} = {name}")
    print(f"\n  Presets: {', '.join(PRESETS.keys())}")


def parse_spec_selection(raw):
    """Parse a comma/space-separated list of spec IDs and/or preset names."""
    specs = set()
    for token in raw.replace(",", " ").split():
        token = token.strip().lower()
        if token in PRESETS:
            specs.update(PRESETS[token])
        else:
            try:
                sid = int(token)
                if 1 <= sid <= 31:
                    specs.add(sid)
                else:
                    print(f"  Warning: ignoring out-of-range spec ID {sid}")
            except ValueError:
                print(f"  Warning: ignoring unknown token '{token}'")
    return sorted(specs)


def main():
    print("=" * 60)
    print("  Paragon Passive Spell — Enchantment Generator")
    print("=" * 60)

    # 1. Enchantment ID
    ench_id = prompt_int("\nEnchantment ID (950001-950099)", min_val=950001, max_val=950099)

    # 2. Spell ID (the spell_dbc entry the user already created)
    spell_id = prompt_int("Spell ID in spell_dbc", default=ench_id)

    # 3. Display name (used for tooltip AND pool catalog)
    name = prompt_input("Display name (e.g. '+3% Stamina' or 'Thunderstrike')")
    if not name:
        print("  Name is required.")
        sys.exit(1)

    # 4. Optional: min paragon level / min item level
    min_plvl = 1
    min_ilvl = 0
    if prompt_yes_no("Set minimum Paragon level / item level requirements?", default="n"):
        min_plvl = prompt_int("  Minimum Paragon level to roll", default=1, min_val=0)
        min_ilvl = prompt_int("  Minimum item level to roll", default=0, min_val=0)

    # 5. Spec assignments
    print_specs()
    raw_specs = prompt_input("\nAssign to specs (IDs, presets, or mix — e.g. 'all_dps 3 5 7 18')")
    spec_ids = parse_spec_selection(raw_specs)

    if not spec_ids:
        print("  No specs selected — will skip spec assignment SQL.")

    # 9. Weight
    weight = 100
    if spec_ids:
        weight = prompt_int("Roll weight for all selected specs", default=100, min_val=1)

    # ── Generate SQL ────────────────────────────────────────────
    sql_lines = []
    sql_lines.append("")
    sql_lines.append(f"-- Paragon Passive Spell: {name} (enchID={ench_id}, spellID={spell_id})")
    sql_lines.append("")

    # Escape single quotes for SQL
    name_sql = name.replace("'", "''")

    # spellitemenchantment_dbc
    sql_lines.append("-- spellitemenchantment_dbc: Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)")
    sql_lines.append(f"DELETE FROM `spellitemenchantment_dbc` WHERE `ID` = {ench_id};")
    sql_lines.append(
        f"INSERT INTO `spellitemenchantment_dbc` "
        f"(`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, "
        f"`EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, "
        f"`EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, "
        f"`EffectArg_1`, `EffectArg_2`, `EffectArg_3`, "
        f"`Name_Lang_enUS`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, "
        f"`RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES\n"
        f"({ench_id}, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, "
        f"{spell_id}, 0, 0, '{name_sql}', 0, 0, 0, 0, 0, 0, 0);"
    )
    sql_lines.append("")

    # paragon_passive_spell_pool
    sql_lines.append("-- paragon_passive_spell_pool: spell catalog entry")
    sql_lines.append(f"DELETE FROM `paragon_passive_spell_pool` WHERE `enchantmentId` = {ench_id};")
    sql_lines.append(
        f"INSERT INTO `paragon_passive_spell_pool` "
        f"(`enchantmentId`, `spellId`, `name`, `category`, `minParagonLevel`, `minItemLevel`) VALUES\n"
        f"({ench_id}, {spell_id}, '{name_sql}', 0, {min_plvl}, {min_ilvl});"
    )

    # paragon_spec_spell_assign
    if spec_ids:
        sql_lines.append("")
        spec_names = ", ".join(SPECS[s][1] for s in spec_ids)
        sql_lines.append(f"-- paragon_spec_spell_assign: {spec_names}")
        sql_lines.append(f"DELETE FROM `paragon_spec_spell_assign` WHERE `enchantmentId` = {ench_id};")
        sql_lines.append(
            f"INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES"
        )
        assign_rows = []
        for sid in spec_ids:
            assign_rows.append(f"({sid}, {ench_id}, {weight})")
        # Format: 4 per line
        for i in range(0, len(assign_rows), 4):
            chunk = assign_rows[i:i + 4]
            line = ", ".join(chunk)
            if i + 4 >= len(assign_rows):
                line += ";"
            else:
                line += ","
            sql_lines.append(line)

    sql_output = "\n".join(sql_lines)

    # ── Output ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  Generated SQL")
    print("=" * 60)
    print(sql_output)
    print()

    # Offer to append to the SQL file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sql_file = os.path.join(script_dir, "..", "data", "sql", "db-world", "paragon_passive_spells.sql")
    sql_file = os.path.normpath(sql_file)

    if os.path.isfile(sql_file):
        if prompt_yes_no(f"Append to {sql_file}?", default="y"):
            with open(sql_file, "a", encoding="utf-8") as f:
                f.write("\n" + sql_output + "\n")
            print(f"  Appended to {sql_file}")
        else:
            print("  Not appended. Copy the SQL above manually.")
    else:
        print(f"  SQL file not found at {sql_file} — copy the SQL above manually.")


if __name__ == "__main__":
    main()
