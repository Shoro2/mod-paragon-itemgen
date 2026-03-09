#!/usr/bin/env python3
"""
Patch SpellItemEnchantment.dbc with Paragon custom enchantment entries.

Usage:
    python3 patch_dbc.py <original_dbc> <output_dbc>

Example:
    python3 patch_dbc.py SpellItemEnchantment.dbc SpellItemEnchantment_patched.dbc

The patched DBC should be placed in a client-side MPQ patch file
(e.g. patch-4.MPQ) under DBFilesClient/SpellItemEnchantment.dbc
"""

import struct
import sys
import os

# DBC format: WDBC header + records + string block
# SpellItemEnchantment.dbc: 38 fields, 152 bytes per record
#
# Fields (all uint32, 4 bytes each):
#  0: ID
#  1: Charges
#  2-4: Effect[3]
#  5-7: EffectPointsMin[3]
#  8-10: EffectPointsMax[3]
#  11-13: EffectArg[3]
#  14-29: Name_Lang[16]  (string offsets)
#  30: Name_Lang_Mask
#  31: ItemVisual
#  32: Flags
#  33: Src_ItemID
#  34: Condition_Id
#  35: RequiredSkillID
#  36: RequiredSkillRank
#  37: MinLevel

HEADER_SIZE = 20  # 4 (magic) + 4*4 (counts)
FIELDS_PER_RECORD = 38
RECORD_SIZE = FIELDS_PER_RECORD * 4  # 152 bytes

# Paragon stat definitions: (stat_index, ITEM_MOD, stat_name)
PARAGON_STATS = [
    (0,  7,  "Stamina"),
    (1,  4,  "Strength"),
    (2,  3,  "Agility"),
    (3,  5,  "Intellect"),
    (4,  6,  "Spirit"),
    (5,  13, "Dodge Rating"),
    (6,  14, "Parry Rating"),
    (7,  12, "Defense Rating"),
    (8,  15, "Block Rating"),
    (9,  31, "Hit Rating"),
    (10, 32, "Crit Rating"),
    (11, 36, "Haste Rating"),
    (12, 37, "Expertise Rating"),
    (13, 44, "Armor Penetration"),
    (14, 45, "Spell Power"),
    (15, 38, "Attack Power"),
    (16, 43, "Mana Regeneration"),
]

# ID layout: 900000 + stat_index * 1000 + amount (1-200)
BASE_ID = 900000
MAX_AMOUNT = 666
CURSED_ENCHANT_ID = 920001

# Passive spell enchantments: (enchantment_id, spell_id, name)
# These use Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL), EffectArg_1=spellId
# Names must match the server-side spellitemenchantment_dbc entries
PASSIVE_SPELL_ENCHANT_MIN = 950001
PASSIVE_SPELL_ENCHANT_MAX = 950099
PASSIVE_SPELL_ENCHANTS = [
    (950001, 900000, "Passive: +20% Strength"),
    (950002, 900001, "Passive: +20% Intellect"),
    (950003, 900002, "Passive: +20% Agility"),
    (950004, 900003, "Passive: +20% Spirit"),
    (950005, 900004, "Passive: +20% Stamina"),
    (950006, 900005, "Passive: +10% All Stats"),
    (950007, 900100, "Passive: +50% Mortal Strike Damage"),
    (950008, 900101, "Passive: -2 sec Mortal Strike CD"),
    (950009, 900102, "Passive: +50% Overpower Damage"),
    (950010, 900103, "Passive: Mortal Strike +9 Targets"),
    (950011, 900104, "Passive: Overpower +9 Targets"),
    (950012, 900105, "Passive: Critical Execution"),
]


def read_dbc(filepath):
    """Read a DBC file and return (records, string_block, field_count)."""
    with open(filepath, 'rb') as f:
        magic = f.read(4)
        if magic != b'WDBC':
            raise ValueError(f"Not a valid DBC file (magic: {magic})")

        record_count, field_count, record_size, string_size = struct.unpack('<4I', f.read(16))

        if record_size != RECORD_SIZE:
            raise ValueError(f"Unexpected record size: {record_size} (expected {RECORD_SIZE})")

        # Read all records as raw bytes
        records_data = f.read(record_count * record_size)
        string_block = f.read(string_size)

    # Parse records into list of field tuples
    records = []
    for i in range(record_count):
        offset = i * record_size
        fields = struct.unpack_from(f'<{FIELDS_PER_RECORD}I', records_data, offset)
        records.append(list(fields))

    return records, string_block, field_count


def write_dbc(filepath, records, string_block, field_count):
    """Write records and string block to a DBC file."""
    record_count = len(records)
    string_size = len(string_block)

    with open(filepath, 'wb') as f:
        # Header
        f.write(b'WDBC')
        f.write(struct.pack('<4I', record_count, field_count, RECORD_SIZE, string_size))

        # Records
        for fields in records:
            f.write(struct.pack(f'<{FIELDS_PER_RECORD}I', *fields))

        # String block
        f.write(string_block)


def add_string(string_block_bytes, text):
    """Add a string to the string block, return its offset."""
    offset = len(string_block_bytes)
    encoded = text.encode('utf-8') + b'\x00'
    return string_block_bytes + encoded, offset


def generate_paragon_entries(string_block):
    """Generate all paragon enchantment records and update string block."""
    new_records = []
    sb = bytearray(string_block)

    for stat_index, item_mod, stat_name in PARAGON_STATS:
        for amount in range(1, MAX_AMOUNT + 1):
            entry_id = BASE_ID + stat_index * 1000 + amount
            name = f"Paragon +{amount} {stat_name}"

            # Add name string to string block
            name_offset = len(sb)
            sb.extend(name.encode('utf-8'))
            sb.append(0)  # null terminator

            # Build record: 38 fields
            fields = [0] * FIELDS_PER_RECORD
            fields[0] = entry_id           # ID
            fields[1] = 0                  # Charges
            fields[2] = 5                  # Effect_1 (TYPE_STAT)
            fields[3] = 0                  # Effect_2
            fields[4] = 0                  # Effect_3
            fields[5] = amount             # EffectPointsMin_1
            fields[6] = 0                  # EffectPointsMin_2
            fields[7] = 0                  # EffectPointsMin_3
            fields[8] = 0                  # EffectPointsMax_1
            fields[9] = 0                  # EffectPointsMax_2
            fields[10] = 0                 # EffectPointsMax_3
            fields[11] = item_mod          # EffectArg_1 (ITEM_MOD)
            fields[12] = 0                 # EffectArg_2
            fields[13] = 0                 # EffectArg_3
            # fields[14-29]: Name_Lang[16] - only enUS (index 0)
            fields[14] = name_offset       # Name_Lang_enUS
            # fields[15-29] = 0            # other locales (already 0)
            fields[30] = 0                 # Name_Lang_Mask
            fields[31] = 0                 # ItemVisual
            fields[32] = 0                 # Flags
            fields[33] = 0                 # Src_ItemID
            fields[34] = 0                 # Condition_Id
            fields[35] = 0                 # RequiredSkillID
            fields[36] = 0                 # RequiredSkillRank
            fields[37] = 0                 # MinLevel

            new_records.append(fields)

    # Add "Cursed" marker enchantment (ID 920001, no stat effect)
    name = "Cursed"
    name_offset = len(sb)
    sb.extend(name.encode('utf-8'))
    sb.append(0)

    fields = [0] * FIELDS_PER_RECORD
    fields[0] = CURSED_ENCHANT_ID
    fields[14] = name_offset  # Name_Lang_enUS
    new_records.append(fields)

    # Add passive spell enchantments (950001+)
    # Effect_1=3 (ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL), EffectArg_1=spellId
    for enchant_id, spell_id, ench_name in PASSIVE_SPELL_ENCHANTS:
        name_offset = len(sb)
        sb.extend(ench_name.encode('utf-8'))
        sb.append(0)

        fields = [0] * FIELDS_PER_RECORD
        fields[0] = enchant_id          # ID
        fields[2] = 3                   # Effect_1 (EQUIP_SPELL)
        fields[11] = spell_id           # EffectArg_1 (spell ID)
        fields[14] = name_offset        # Name_Lang_enUS
        new_records.append(fields)

    return new_records, bytes(sb)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <original_dbc> <output_dbc>")
        print(f"Example: {sys.argv[0]} SpellItemEnchantment.dbc SpellItemEnchantment_patched.dbc")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(input_path):
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    print(f"Reading original DBC: {input_path}")
    records, string_block, field_count = read_dbc(input_path)
    print(f"  Original records: {len(records)}")
    print(f"  Original string block: {len(string_block)} bytes")

    # Check for existing paragon entries and remove them
    def is_paragon_id(rid):
        # Stat enchantments (900001-917000) and cursed marker (920001)
        if BASE_ID < rid <= CURSED_ENCHANT_ID:
            return True
        # Passive spell enchantments (950001-950099)
        if PASSIVE_SPELL_ENCHANT_MIN <= rid <= PASSIVE_SPELL_ENCHANT_MAX:
            return True
        return False

    existing_ids = {r[0] for r in records}
    paragon_existing = [rid for rid in existing_ids if is_paragon_id(rid)]
    if paragon_existing:
        print(f"  Removing {len(paragon_existing)} existing paragon entries...")
        records = [r for r in records if not is_paragon_id(r[0])]

    # Generate paragon entries
    total_entries = len(PARAGON_STATS) * MAX_AMOUNT + 1 + len(PASSIVE_SPELL_ENCHANTS)
    print(f"Generating {total_entries} paragon enchantment entries (stats + cursed + passive spells)...")
    new_records, string_block = generate_paragon_entries(string_block)

    # Merge and sort by ID
    all_records = records + new_records
    all_records.sort(key=lambda r: r[0])

    print(f"Writing patched DBC: {output_path}")
    print(f"  Total records: {len(all_records)}")
    print(f"  String block: {len(string_block)} bytes")
    write_dbc(output_path, all_records, string_block, field_count)

    file_size = os.path.getsize(output_path)
    print(f"  File size: {file_size:,} bytes")
    print()
    print("Done! Place the patched file in your client:")
    print("  <WoW>/Data/patch-4.MPQ/DBFilesClient/SpellItemEnchantment.dbc")
    print("  (or use an MPQ editor to add it to a custom patch MPQ)")


if __name__ == '__main__':
    main()
