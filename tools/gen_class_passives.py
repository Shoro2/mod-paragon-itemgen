"""Generate the cursed-item pool rows of the custom class spells.

Every spell of mod-custom-spells' /spells picker is also a "Paragon Passive
Spell" a cursed item can roll for its owner's spec (concept, section "Paragon
Passive Spells"). This tool turns the picker's manifest
(mod-custom-spells/data/spellbook_enUS.json: id, class, spec, name) into

    data/sql/db-world/paragon_passive_spells_class.sql
        spellitemenchantment_dbc   one ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL row per spell
        paragon_passive_spell_pool the catalog row (its name is the tooltip line)
        paragon_spec_spell_assign  the spell's spec(s), weight CLASS_WEIGHT

Enchantment ids are FROZEN in data/class_passive_enchants.json: items in
acore_characters keep the id they rolled, so a spell's id never changes and a
new spell takes the next free id (band 950001-950999, share-public
06-custom-ids.md). The six Arms rows 950007-950012 predate this tool and keep
their ids.

    python tools/gen_class_passives.py            write the map + the SQL file
    python tools/gen_class_passives.py --check    exit 1 when either file is stale
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.dirname(HERE)
MANIFEST = os.path.join(os.path.dirname(MODULE), "mod-custom-spells", "data", "spellbook_enUS.json")
ID_MAP = os.path.join(MODULE, "data", "class_passive_enchants.json")
SQL_OUT = os.path.join(MODULE, "data", "sql", "db-world", "paragon_passive_spells_class.sql")

BAND_LO, BAND_HI = 950001, 950999
FIRST_FREE = 950013            # 950001-950006 stat passives, 950007-950012 the Arms rows
CLASS_WEIGHT = 10              # the weight the July Arms rows use; stat passives use 100
LEGACY = {900100: 950007, 900101: 950008, 900102: 950009,
          900103: 950010, 900104: 950011, 900105: 950012}
# player-castable actives: an EQUIP_SPELL enchantment would CAST them on equip
EXCLUDED = {
    900534: "active (Barrage, a channel)",
    900713: "active (Targeted Blink)",
    900771: "active (Comet Shower)",
    900741: "active (Meteor)",
}
SPECS = {
    ("Warrior", "Arms"): [1], ("Warrior", "Fury"): [2], ("Warrior", "Protection"): [3],
    ("Paladin", "Holy"): [4], ("Paladin", "Protection"): [5], ("Paladin", "Retribution"): [6],
    ("Death Knight", "Blood"): [7], ("Death Knight", "Frost"): [8], ("Death Knight", "Unholy"): [9],
    ("Shaman", "Elemental"): [10], ("Shaman", "Enhancement"): [11], ("Shaman", "Restoration"): [12],
    ("Hunter", "Beast Mastery"): [13], ("Hunter", "Marksmanship"): [14], ("Hunter", "Survival"): [15],
    ("Hunter", "Shared"): [13, 14, 15],
    ("Druid", "Balance"): [16], ("Druid", "Restoration"): [17],
    ("Rogue", "Assassination"): [20], ("Rogue", "Combat"): [21], ("Rogue", "Subtlety"): [22],
    ("Mage", "Arcane"): [23], ("Mage", "Fire"): [24], ("Mage", "Frost"): [25],
    ("Warlock", "Affliction"): [26], ("Warlock", "Demonology"): [27], ("Warlock", "Destruction"): [28],
    ("Priest", "Discipline"): [29], ("Priest", "Holy"): [30], ("Priest", "Shadow"): [31],
    ("Global", "Global"): list(range(1, 32)),
}
# per-spell specs where the picker's one label is not the whole story: the
# picker's single "Feral" group splits into the two ParagonSpec ferals, and the
# concept lists some spells under several specs (Whirlwind unlimited: Arms and
# Fury; Whirlwind -> Overpower: Arms; Thunder Clap Rend/Sunder: Arms and Prot;
# Evocation power: all three mage specs)
SPELL_SPECS = {901033: [18], 901035: [18], 901049: [19], 901051: [19],
               900108: [1, 2], 900118: [1], 900170: [1, 3], 900707: [23, 24, 25]}
SPEC_NAMES = {1: "Arms", 2: "Fury", 3: "WarProt", 4: "HolyPala", 5: "ProtPala", 6: "Ret",
              7: "Blood", 8: "DKFrost", 9: "Unholy", 10: "Ele", 11: "Enhance", 12: "RestoSham",
              13: "BM", 14: "MM", 15: "Surv", 16: "Balance", 17: "RestoDru", 18: "FeralTank",
              19: "FeralDPS", 20: "Assa", 21: "Combat", 22: "Sub", 23: "Arcane", 24: "Fire",
              25: "MageFrost", 26: "Affli", 27: "Demo", 28: "Destro", 29: "Disc", 30: "HolyPri",
              31: "Shadow"}


def sql_str(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "''") + "'"


def load_map():
    if not os.path.exists(ID_MAP):
        return {str(k): v for k, v in LEGACY.items()}
    return json.load(open(ID_MAP, encoding="utf-8"))["map"]


def build():
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    entries = [e for e in manifest["entries"] if e["id"] not in EXCLUDED]
    idmap = load_map()
    for sid, ench in LEGACY.items():
        if idmap.get(str(sid)) != ench:
            raise SystemExit("frozen map lost the legacy row %d -> %d" % (sid, ench))
    used = set(idmap.values())
    nxt = max([FIRST_FREE - 1] + [v for v in used if v >= FIRST_FREE]) + 1
    for e in entries:
        if str(e["id"]) not in idmap:
            if nxt > BAND_HI:
                raise SystemExit("enchantment band %d-%d is full" % (BAND_LO, BAND_HI))
            idmap[str(e["id"])] = nxt
            nxt += 1
    if len(set(idmap.values())) != len(idmap):
        raise SystemExit("duplicate enchantment id in the map")
    stale = sorted(int(k) for k in idmap if int(k) not in {e["id"] for e in entries})
    if stale:
        raise SystemExit("map holds spells the picker no longer offers: %s (decide, then edit the map)" % stale)

    rows = []
    for e in entries:
        specs = SPELL_SPECS.get(e["id"]) or SPECS.get((e["class"], e["spec"]))
        if not specs:
            raise SystemExit("no ParagonSpec for %d (%s / %s)" % (e["id"], e["class"], e["spec"]))
        rows.append((idmap[str(e["id"])], e["id"], e["name"], specs, e["class"], e["spec"]))
    rows.sort()
    ids = [r[0] for r in rows]
    lo, hi = min(ids), max(ids)
    if hi - lo + 1 != len(ids):
        raise SystemExit("enchantment ids %d-%d have gaps; the SQL deletes the whole range" % (lo, hi))

    out = []
    out.append("-- =============================================================")
    out.append("-- Cursed-item passives: the custom class spells of mod-custom-spells")
    out.append("-- GENERATED by tools/gen_class_passives.py from the picker manifest")
    out.append("-- (mod-custom-spells/data/spellbook_enUS.json) - edit the manifest or the")
    out.append("-- tool, never this file. Enchantment ids are frozen in")
    out.append("-- data/class_passive_enchants.json (items keep the id they rolled).")
    out.append("-- %d spells, enchantments %d-%d, weight %d per spec (the stat passives"
               % (len(rows), lo, hi, CLASS_WEIGHT))
    out.append("-- of paragon_passive_spells.sql weigh 100). Not in the pool: %s."
               % ", ".join("%d %s" % kv for kv in sorted(EXCLUDED.items())))
    out.append("-- =============================================================")
    out.append("")
    cols = ("`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, "
            "`EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, "
            "`EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, "
            "`ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, "
            "`RequiredSkillRank`, `MinLevel`")
    out.append("-- Effect_1 3 = ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL: the item casts EffectArg_1 on equip")
    out.append("DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spellitemenchantment_dbc` (%s) VALUES" % cols)
    out.append(",\n".join("(%d, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, %d, 0, 0, %s, 0, 0, 0, 0, 0, 0, 0)"
                          % (ench, sid, sql_str("Passive: " + name)) for ench, sid, name, *_ in rows) + ";")
    out.append("")
    out.append("DELETE FROM `paragon_passive_spell_pool` WHERE `enchantmentId` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `paragon_passive_spell_pool` (`enchantmentId`, `spellId`, `name`, `category`, "
               "`minParagonLevel`, `minItemLevel`) VALUES")
    out.append(",\n".join("(%d, %d, %s, 0, 1, 0)" % (ench, sid, sql_str(name))
                          for ench, sid, name, *_ in rows) + ";")
    out.append("")
    out.append("DELETE FROM `paragon_spec_spell_assign` WHERE `enchantmentId` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `paragon_spec_spell_assign` (`specId`, `enchantmentId`, `weight`) VALUES")
    assign = []
    for ench, sid, name, specs, cls, spec in rows:
        assign.append("-- %d %s (%s %s -> %s)" % (sid, name, cls, spec, ", ".join(SPEC_NAMES[s] for s in specs)))
        assign.append(", ".join("(%d, %d, %d)" % (s, ench, CLASS_WEIGHT) for s in specs) + ",")
    assign[-1] = assign[-1][:-1] + ";"
    out.extend(assign)
    sql = "\n".join(out) + "\n"
    idjson = json.dumps({"about": "spellId -> spellitemenchantment id of a cursed-item class passive. "
                                  "Append-only: items keep the id they rolled.",
                         "map": {k: idmap[k] for k in sorted(idmap, key=lambda x: idmap[x])}},
                        indent=1) + "\n"
    return sql, idjson, rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="exit 1 when the files are stale")
    args = ap.parse_args()
    sql, idjson, rows = build()
    current = [open(p, encoding="utf-8").read() if os.path.exists(p) else None for p in (SQL_OUT, ID_MAP)]
    if args.check:
        stale = [p for p, cur, new in ((SQL_OUT, current[0], sql), (ID_MAP, current[1], idjson)) if cur != new]
        print("stale: %s" % stale if stale else "up to date (%d spells)" % len(rows))
        return 1 if stale else 0
    for path, text in ((SQL_OUT, sql), (ID_MAP, idjson)):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("%d spells -> %s, map %s" % (len(rows), SQL_OUT, ID_MAP))
    return 0


if __name__ == "__main__":
    sys.exit(main())
