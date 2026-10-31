"""Generate the Tainted Heartstone (item 920301) loot rows of the cursed altar.

The item drops ONCE in the corpse / chest loot of the end boss of every level-80
HEROIC 5-man dungeon (count 1, heroic version only) and of every level-80 RAID
(count 10, every size and difficulty). Operator rule: "dungeon 100% 1x,
pd 50% 1x, raid 100% 10x". The Procedural Dungeon half is C++ in
mod-procedural-dungeon (ProceduralDungeon.V2.Heartstone.*), not here.

    data/sql/db-world/paragon_heartstone_loot.sql
        DELETE ... WHERE Item = 920301   (idempotent)
        creature_loot_template      Entry = the creature's lootid
        gameobject_loot_template    Entry = the chest's data1 (type 3)

The boss list below is curated by hand (the AzerothCore instance scripts under
src/server/scripts/Northrend decide which creature / chest carries the end
loot, and a few of them are not what the encounter name suggests); everything
that CAN come from the world DB does: the lootid of a creature, the data1 of a
chest, the heroic / 25-man / heroic-raid entries through
creature_template.difficulty_entry_1..3, the cross-check against
instance_encounters (lastEncounterDungeon > 0), the "does another creature share
this loot table" check and the loot-window estimate. The DB is only ever READ.

    set MYSQL_PWD=<password of the acore user>      (never on the command line)
    python tools/gen_heartstone_loot.py             writes the SQL file
    python tools/gen_heartstone_loot.py --check     exit 1 when the file is stale
    python tools/gen_heartstone_loot.py --print     SQL to stdout instead

Host, port, user and database come from WorldDatabaseInfo of
C:\\wowstuff\\dcore\\configs\\worldserver.conf (the password field is NOT used).
"""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.dirname(HERE)
SQL_OUT = os.path.join(MODULE, "data", "sql", "db-world", "paragon_heartstone_loot.sql")

ITEM = 920301
COMMENT = "Tainted Heartstone (Cursed Altar)"
COUNT_DUNGEON = 1
COUNT_RAID = 10
WINDOW = 18                      # MAX_NR_LOOT_ITEMS, the 3.3.5a loot window

MYSQL_EXE = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
WORLDSERVER_CONF = r"C:\wowstuff\dcore\configs\worldserver.conf"

# --------------------------------------------------------------------------
# The boss list.
#
# creature entries: "root" is the creature that carries the NORMAL / 10-man
# version; the other versions come from its difficulty_entry_1..3.
#   versions = labels for [root, d1, d2, d3]; a None label means "must be 0".
# chest entries: the gameobject_template entries (type 3) whose data1 is the loot
# id. One boss may list several chests that share a loot id (the table dedupes).
# `enc` is the creature the instance_encounters row credits (creditType 0), as a
# cross-check that this really is the end boss of that dungeon.
# --------------------------------------------------------------------------
HEROIC_5MAN = [
    # (dungeon, boss, kind, root/chest entries, name check, enc credit entry)
    ("Utgarde Keep", "Ingvar the Plunderer", "creature", [23954], "Ingvar", 23954),
    ("Utgarde Pinnacle", "King Ymiron", "creature", [26861], "Ymiron", 26861),
    ("Azjol-Nerub", "Anub'arak", "creature", [29120], "Anub'arak", 29120),
    ("Ahn'kahet", "Herald Volazj", "creature", [29311], "Volazj", 29311),
    ("Drak'Tharon Keep", "The Prophet Tharon'ja", "creature", [26632], "Tharon'ja", None),
    ("The Violet Hold", "Cyanigosa", "creature", [31134], "Cyanigosa", 31134),
    ("Gundrak", "Gal'darah", "creature", [29306], "Gal'darah", 29306),
    ("Halls of Stone", "Sjonnir The Ironshaper", "creature", [27978], "Sjonnir", 27978),
    ("Halls of Lightning", "Loken", "creature", [28923], "Loken", 28923),
    ("The Nexus", "Keristrasza", "creature", [26723], "Keristrasza", 26723),
    # Eregos' own table holds one 0.1 % item; the loot is the Cache of Eregos
    # the instance script summons (instance_oculus.cpp, GO_CACHE_OF_EREGOS*).
    ("The Oculus", "Ley-Guardian Eregos (Cache of Eregos)", "chest", [193603], "Cache of Eregos", None),
    # Mal'ganis' creature has lootid 0; boss_mal_ganis.cpp:122 summons the chest.
    ("Culling of Stratholme", "Mal'ganis (Dark Runed Chest)", "chest", [193597], "Dark Runed Chest", None),
    # AC's Black Knight carries the real end loot on the creature (gear
    # reference + Emblem of Triumph); the "Champion's Cache" chests belong to
    # the Grand Champions / Argent Challenge, not to him.
    ("Trial of the Champion", "The Black Knight", "creature", [35451], "Black Knight", None),
    ("Forge of Souls", "Devourer of Souls", "creature", [36502], "Devourer of Souls", 36502),
    ("Pit of Saron", "Scourgelord Tyrannus", "creature", [36658], "Tyrannus", 36658),
    # Static spawns on the two ship maps (712 / 713); 202337 carries the same loot id.
    ("Halls of Reflection", "The Captain's Chest", "chest", [202336, 202337], "Captain's Chest", None),
]

# (raid, boss, kind, root entries, version labels for [root,d1,d2,d3], name, enc)
RAIDS = [
    ("Naxxramas", "Kel'Thuzad", "creature", [15990], ["10", "25", None, None], "Kel'Thuzad", 15990),
    ("Obsidian Sanctum", "Sartharion", "creature", [28860], ["10", "25", None, None], "Sartharion", 28860),
    ("Eye of Eternity", "Malygos (Alexstrasza's Gift)", "chest", {"10": 193905, "25": 193967}, None, "Alexstrasza's Gift", None),
    ("Vault of Archavon", "Toravon the Ice Watcher", "creature", [38433], ["10", "25", None, None], "Toravon", 38433),
    ("Onyxia's Lair", "Onyxia", "creature", [10184], ["10", "25", None, None], "Onyxia", 10184),
    # Algalon is NOT the end boss here by operator choice; Yogg-Saron has no
    # instance_encounters row with lastEncounterDungeon > 0.
    ("Ulduar", "Yogg-Saron", "creature", [33288], ["10", "25", None, None], "Yogg-Saron", None),
    ("Trial of the Crusader", "Anub'arak", "creature", [34564], ["10N", "25N", "10H", "25H"], "Anub'arak", 34564),
    ("Icecrown Citadel", "The Lich King", "creature", [36597], ["10N", "25N", "10H", "25H"], "The Lich King", 36597),
    ("Ruby Sanctum", "Halion", "creature", [39863], ["10N", "25N", "10H", "25H"], "Halion", 39863),
]


# --------------------------------------------------------------------------
# read-only DB access through mysql.exe
# --------------------------------------------------------------------------
CHRONICLE_ENTRIES = (970000, 970999)   # mod-endless-chronicle creature band (vault 06-custom-ids)
CHRONICLE_MAP = 770


def db_params():
    text = open(WORLDSERVER_CONF, encoding="utf-8", errors="replace").read()
    m = re.search(r'^\s*WorldDatabaseInfo\s*=\s*"([^"]*)"', text, re.M)
    if not m:
        sys.exit("WorldDatabaseInfo not found in " + WORLDSERVER_CONF)
    host, port, user, _pwd, db = m.group(1).split(";")
    return host, port, user, db


def query(sql):
    host, port, user, db = db_params()
    if "MYSQL_PWD" not in os.environ:
        sys.exit("set MYSQL_PWD first (the password is never taken from the command line)")
    cmd = [MYSQL_EXE, "-h", host, "-P", port, "-u", user, db, "--batch",
           "--skip-column-names", "--default-character-set=utf8mb4", "-e", sql]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        sys.exit("mysql failed: " + res.stderr.strip())
    return [line.split("\t") for line in res.stdout.splitlines() if line]


def ints(row):
    return [int(x) for x in row]


# --------------------------------------------------------------------------
# resolution
# --------------------------------------------------------------------------
class Row:
    def __init__(self, table, entry, count, source):
        self.table, self.entry, self.count, self.source = table, entry, count, source


def creature(entry):
    r = query("SELECT entry, name, lootid, difficulty_entry_1, difficulty_entry_2, "
              "difficulty_entry_3 FROM creature_template WHERE entry = %d" % entry)
    if not r:
        sys.exit("creature_template %d missing" % entry)
    e, name, lootid, d1, d2, d3 = r[0]
    return dict(entry=int(e), name=name, lootid=int(lootid), d=[int(d1), int(d2), int(d3)])


def chest(entry):
    r = query("SELECT entry, name, type, data1 FROM gameobject_template WHERE entry = %d" % entry)
    if not r:
        sys.exit("gameobject_template %d missing" % entry)
    e, name, typ, data1 = r[0]
    if int(typ) != 3:
        sys.exit("gameobject %d is not a type-3 chest" % entry)
    return dict(entry=int(e), name=name, lootid=int(data1))


def encounter_ok(credit):
    r = query("SELECT COUNT(*) FROM instance_encounters WHERE creditType = 0 "
              "AND creditEntry = %d AND lastEncounterDungeon > 0" % credit)
    return int(r[0][0]) > 0


def window_estimate(table, entry):
    """Worst-case number of loot slots a table fills (all loot modes, every
    chance-below-100 row assumed to drop), without our row."""
    rows = query("SELECT Item, Reference, Chance, QuestRequired, GroupId, MaxCount FROM %s "
                 "WHERE Entry = %d AND Item <> %d" % (table, entry, ITEM))
    ungrouped = 0
    groups = set()
    refs = 0
    for item, ref, chance, quest, grp, maxc in rows:
        ref, quest, grp, maxc = int(ref), int(quest), int(grp), int(maxc)
        if quest:
            continue                      # quest items live in their own 4 slots
        if ref:
            per_roll = 0
            rr = query("SELECT Reference, QuestRequired, GroupId FROM reference_loot_template "
                       "WHERE Entry = %d" % ref)
            rgroups = set()
            for rref, rq, rg in rr:
                if int(rq):
                    continue
                if int(rg):
                    rgroups.add(int(rg))
                else:
                    per_roll += 1
            per_roll += len(rgroups) or 0
            refs += maxc * max(per_roll, 1)
        elif grp:
            groups.add(grp)
        else:
            ungrouped += 1
    return ungrouped + len(groups) + refs


def shared_creatures(lootid, own_entries):
    r = query("SELECT entry, name FROM creature_template WHERE lootid = %d" % lootid)
    return [(int(e), n) for e, n in r if int(e) not in own_entries]


def shared_chests(lootid, own_entries):
    r = query("SELECT entry, name FROM gameobject_template WHERE type = 3 AND data1 = %d" % lootid)
    return [(int(e), n) for e, n in r if int(e) not in own_entries]


# --------------------------------------------------------------------------
def build():
    rows = {}           # (table, entry) -> Row
    notes = []          # report lines (also written into the header)
    skipped = []
    table_lines = []    # (kind label, boss text, table, entry, count)
    chronicle_shared = set()  # creature loot ids a Chronicle echo borrows (map 770 must not drop it)

    def add(table, entry, count, label):
        key = (table, entry)
        if key in rows:
            if rows[key].count != count:
                sys.exit("conflicting counts for %s %d" % (table, entry))
            rows[key].source.append(label)
            return
        rows[key] = Row(table, entry, count, [label])

    def record(group, dungeon, boss, version, table, entry, count):
        table_lines.append((group, dungeon, boss, version, table, entry, count))

    def examine(table, entry, owners, label):
        est = window_estimate(table, entry)
        if est + 1 > WINDOW:
            notes.append("%s: %s %d fills up to %d of %d slots with the heartstone "
                         "(row may be pushed out)" % (label, table, entry, est + 1, WINDOW))
        if table == "creature_loot_template":
            sh = shared_creatures(entry, owners)
        else:
            sh = shared_chests(entry, owners)
        for e, n in sh:
            if table == "creature_loot_template" and CHRONICLE_ENTRIES[0] <= e <= CHRONICLE_ENTRIES[1]:
                chronicle_shared.add(entry)
            notes.append("%s: loot table %d is ALSO used by %s %d '%s' - the heartstone "
                         "drops there too" % (label, entry, "creature" if table.startswith("creature") else "chest", e, n))

    # ---- heroic 5-mans ----------------------------------------------------
    for dungeon, boss, kind, entries, nm, enc in HEROIC_5MAN:
        label = "%s / %s" % (dungeon, boss)
        if kind == "creature":
            c = creature(entries[0])
            if nm.lower() not in c["name"].lower():
                sys.exit("%s: creature %d is '%s'" % (label, c["entry"], c["name"]))
            if enc is not None and not encounter_ok(enc):
                sys.exit("%s: no instance_encounters row credits %d" % (label, enc))
            h = c["d"][0]
            if not h:
                sys.exit("%s: no heroic difficulty_entry_1" % label)
            hc = creature(h)
            if hc["lootid"] == 0:
                skipped.append("%s: heroic creature %d has lootid 0" % (label, h))
                continue
            if hc["lootid"] == c["lootid"]:
                notes.append("%s: heroic and normal share lootid %d - normal mode drops it too"
                             % (label, hc["lootid"]))
            add("creature_loot_template", hc["lootid"], COUNT_DUNGEON, label)
            record("5-man heroic", dungeon, boss, "heroic creature %d" % h,
                   "creature_loot_template", hc["lootid"], COUNT_DUNGEON)
            examine("creature_loot_template", hc["lootid"], {h}, label)
        else:
            loots = set()
            for e in entries:
                g = chest(e)
                if nm.lower() not in g["name"].lower():
                    sys.exit("%s: chest %d is '%s'" % (label, e, g["name"]))
                if g["lootid"] == 0:
                    skipped.append("%s: chest %d has data1 0" % (label, e))
                    continue
                loots.add(g["lootid"])
            for lid in sorted(loots):
                add("gameobject_loot_template", lid, COUNT_DUNGEON, label)
                record("5-man heroic", dungeon, boss, "chest %s" % "/".join(str(x) for x in entries),
                       "gameobject_loot_template", lid, COUNT_DUNGEON)
                examine("gameobject_loot_template", lid, set(entries), label)

    # ---- raids ------------------------------------------------------------
    for raid, boss, kind, entries, versions, nm, enc in RAIDS:
        label = "%s / %s" % (raid, boss)
        if kind == "creature":
            c = creature(entries[0])
            if nm.lower() not in c["name"].lower():
                sys.exit("%s: creature %d is '%s'" % (label, c["entry"], c["name"]))
            if enc is not None and not encounter_ok(enc):
                sys.exit("%s: no instance_encounters row credits %d" % (label, enc))
            chain = [c["entry"]] + c["d"]
            for ver, ent in zip(versions, chain):
                if ver is None:
                    if ent:
                        sys.exit("%s: unexpected difficulty entry %d" % (label, ent))
                    continue
                if not ent:
                    sys.exit("%s: version %s has no creature entry" % (label, ver))
                vc = creature(ent)
                if vc["lootid"] == 0:
                    skipped.append("%s %s: creature %d has lootid 0" % (label, ver, ent))
                    continue
                add("creature_loot_template", vc["lootid"], COUNT_RAID, "%s %s" % (label, ver))
                record("raid", raid, boss, "%s creature %d" % (ver, ent),
                       "creature_loot_template", vc["lootid"], COUNT_RAID)
                examine("creature_loot_template", vc["lootid"], {ent}, "%s %s" % (label, ver))
        else:
            for ver, ent in entries.items():
                g = chest(ent)
                if nm.lower() not in g["name"].lower():
                    sys.exit("%s: chest %d is '%s'" % (label, ent, g["name"]))
                if g["lootid"] == 0:
                    skipped.append("%s %s: chest %d has data1 0" % (label, ver, ent))
                    continue
                add("gameobject_loot_template", g["lootid"], COUNT_RAID, "%s %s" % (label, ver))
                record("raid", raid, boss, "%s chest %d" % (ver, ent),
                       "gameobject_loot_template", g["lootid"], COUNT_RAID)
                examine("gameobject_loot_template", g["lootid"], {ent}, "%s %s" % (label, ver))

    item = query("SELECT entry FROM item_template WHERE entry = %d" % ITEM)
    if not item:
        notes.append("item %d is not in item_template on the queried DB yet (the item "
                     "SQL must be applied before the rows are useful)" % ITEM)
    return rows, table_lines, notes, skipped, chronicle_shared


def render(rows, table_lines, notes, skipped, chronicle_shared):
    out = []
    w = out.append
    w("-- ============================================================================")
    w("-- Tainted Heartstone (item %d), the cursed altar's token: end-boss loot." % ITEM)
    w("--")
    w("-- GENERATED by tools/gen_heartstone_loot.py from the world DB - do not edit by")
    w("-- hand; edit the boss list in the script and regenerate.")
    w("--")
    w("-- Operator rule: dungeon 100% 1x, pd 50% 1x, raid 100% 10x. One certain row in")
    w("-- the boss's loot (Chance 100, LootMode 1, group 0): it lies once and goes to ONE")
    w("-- player under the normal loot rules. Normal-mode 5-mans drop nothing; the")
    w("-- Procedural Dungeon's final boss is C++ (mod-procedural-dungeon,")
    w("-- ProceduralDungeon.V2.Heartstone.*), not here.")
    w("--")
    w("-- Entry = the creature's lootid (creature_loot_template) or the chest's data1")
    w("-- (gameobject_loot_template). Boss -> table / entry -> count:")
    w("--")
    last = None
    for group, dungeon, boss, version, table, entry, count in table_lines:
        if group != last:
            w("--   [%s]" % group)
            last = group
        short = "creature" if table.startswith("creature") else "gameobject"
        w("--     %-22s %-38s %-26s -> %s_loot_template %-6d x%d"
          % (dungeon, boss[:38], version, short, entry, count))
    if skipped:
        w("--")
        w("-- SKIPPED (no loot id):")
        for s in skipped:
            w("--   " + s)
    if notes:
        w("--")
        w("-- NOTES from the generator (suspicious spots, review before shipping):")
        for n in notes:
            w("--   " + n)
    w("-- ============================================================================")
    w("")
    for table in ("creature_loot_template", "gameobject_loot_template"):
        mine = sorted((r for r in rows.values() if r.table == table), key=lambda r: r.entry)
        w("DELETE FROM `%s` WHERE `Item` = %d;" % (table, ITEM))
        if not mine:
            w("")
            continue
        w("INSERT INTO `%s` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, "
          "`LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES" % table)
        vals = ["(%d, %d, 0, 100, 0, 1, 0, %d, %d, '%s')" % (r.entry, ITEM, r.count, r.count, COMMENT)
                for r in mine]
        w(",\n".join(vals) + ";")
        w("")
    # The Endless Chronicle's echoes (map 770, mod-endless-chronicle) borrow the loot ids of
    # the 25-man Onyxia, Yogg-Saron and Lich King; an echo is no raid's end boss, so the row
    # is refused to a looter on map 770 (CONDITION_MAPID 22, negated).
    w("DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 1 AND `SourceEntry` = %d;" % ITEM)
    if chronicle_shared:
        w("INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, "
          "`ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, "
          "`ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES")
        vals = ["(1, %d, %d, 0, 0, 22, 0, %d, 0, 0, 1, 0, 0, '', 'Tainted Heartstone: not from a Chronicle echo')"
                % (e, ITEM, CHRONICLE_MAP) for e in sorted(chronicle_shared)]
        w(",\n".join(vals) + ";")
    w("")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 when the SQL file is stale")
    ap.add_argument("--print", dest="to_stdout", action="store_true", help="write to stdout")
    args = ap.parse_args()

    rows, table_lines, notes, skipped, chronicle_shared = build()
    sql = render(rows, table_lines, notes, skipped, chronicle_shared)
    for s in skipped:
        print("SKIPPED: " + s, file=sys.stderr)
    for n in notes:
        print("NOTE: " + n, file=sys.stderr)

    if args.to_stdout:
        sys.stdout.write(sql)
        return 0
    if args.check:
        have = open(SQL_OUT, encoding="utf-8", newline="").read() if os.path.exists(SQL_OUT) else ""
        if have.replace("\r\n", "\n") != sql:
            print("stale: " + SQL_OUT, file=sys.stderr)
            return 1
        return 0
    os.makedirs(os.path.dirname(SQL_OUT), exist_ok=True)
    with open(SQL_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    print("wrote %s (%d rows)" % (SQL_OUT, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
