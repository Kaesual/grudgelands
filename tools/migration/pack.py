"""The pre-reset pass (Round 50 rulings 4, 5 and 8, plan section 3; upgrade
contract section 3.5): before the map is emptied, every node that holds
items in a housing claim is packed for the claim's owner, and the Claim
Stone's remaining fuel comes back as charcoal. The game hands them out at
the Claim Stone after the reset.

What it reads (mods/PLAYER/grug_housing/registry.lua, frozen here and held
to the file by tools/r50_ptool/test_pack.py):
  claims    grug_housing mod storage `claim:<id>`,
            `v2|owner|x|y|z|placed_at|activated_at|paid_until|expired_for|perms`
            (decode_claim); a record that does not decode is skipped, as the
            game's load drops it. Drafts and claims without fuel count too.
  the area  x +- RADIUS, z +- RADIUS, from y = MIN_Y upward (claim_at), only
            the blocks stored in the map.
  in it     every node whose metadata has an inventory with at least one
            list, empty ones too (ruling 13: the game turns an empty one into
            its node's item; counted in `empty` as well), and every personal
            workspace record (grug_jobs/workspaces.lua: node meta
            `grug_jobs:workspace:<name>`, a core.serialize'd
            {lists = {list = {item strings}}, process = ...}) that holds an
            item (plan D7: its items go into a packed chest).

What it writes, only mod storage, only new keys (plan section 3):
  grug_housing `recovered:<owner>:<seq>:<n>`   one item string each:
      a grug_housing:packed_container with item meta `node` (the node
      name), `lists` (a core.serialize'd {list name = {item string per
      slot, "" when empty}}, the item strings exactly as the map stores
      them) and `seq`; or charcoal stacks: ceil((paid_until - now) /
      LUMP_SECONDS) pieces, in stacks of at most CHARCOAL_STACK;
  grug_housing `pack_seq`                       the pass number, seq;
  grug_core `map_reset_pack:<seq>`              the world marker for the
      game's next load (removed items, plan D6, the descriptions).
n counts from 1 per owner and pass: the owner's containers in claim id and
position (x, y, z) order, then that claim's charcoal.
"""

import math
from dataclasses import dataclass, field

from . import codec, data
from .codec import ItemStack
from .mapblock import BLOCK, BlockError, decode, index_offsets

HOUSING = "grug_housing"
CORE = "grug_core"
# grug_housing/registry.lua: M.RADIUS, M.MIN_Y, M.LUMP_SECONDS.
RADIUS = 50
MIN_Y = -100
LUMP_SECONDS = 26160
MAX_BLOCK_Y = 2047
PACKED_ITEM = "grug_housing:packed_container"
# grug_housing/api.lua: REFUND_ITEM; the engine's default stack size.
CHARCOAL = "grug_smelting:charcoal"
CHARCOAL_STACK = 99
WORKSPACE_PREFIX = "grug_jobs:workspace:"
WORKSPACE_NODE = "default:chest"
WORKSPACE_LIST = "main"
SEQ_KEY = "pack_seq"
MARKER_PREFIX = "map_reset_pack:"
ENTRY = "recovered:%s:%d:%d"
COUNT_KEYS = ("claims", "players", "containers", "items", "charcoal", "blocks_read")


class PackError(Exception):
    """The map holds something the pass cannot read: refused, nothing written."""


@dataclass
class Claim:
    id: int
    owner: str
    x: int
    y: int
    z: int
    paid_until: int


@dataclass
class Container:
    pos: tuple
    node: str
    lists: dict          # list name -> [item string per slot]
    source: str = "node"  # "node" or "workspace:<name>"


@dataclass
class ClaimScan:
    claim: Claim
    blocks: int = 0
    containers: list = field(default_factory=list)
    empty: dict = field(default_factory=dict)   # node name -> packed empty ones


def _number(text):
    """Lua tonumber for the record's decimal fields, or None."""
    try:
        value = float(text)
    except ValueError:
        return None
    if value != value or value in (float("inf"), float("-inf")):
        return None
    return int(value) if value.is_integer() else value


def read_claims(store):
    """Every claim record that decodes (registry.lua decode_claim), by id;
    and the number of `claim:` keys that did not."""
    claims, bad = [], 0
    for key, value in data.ModStorage(_Store(store), HOUSING).items().items():
        if not key.startswith("claim:"):
            continue
        number = key[len("claim:"):]
        fields = value.split("|")
        if not number.isdigit() or fields[0] != "v2" or len(fields) != 10 or not fields[1]:
            bad += 1
            continue
        values = [_number(fields[i]) for i in (2, 3, 4, 7)]
        if any(v is None for v in values) or any(_number(fields[i]) is None for i in (5, 6, 8)):
            bad += 1
            continue
        x, y, z, paid_until = values
        claims.append(Claim(int(number), fields[1], x, y, z, paid_until))
    claims.sort(key=lambda claim: claim.id)
    return claims, bad


class _Store:
    """What data.ModStorage needs from a World: the mod-storage backend."""

    def __init__(self, store):
        self._store = store


def storage_get(store, modname, key):
    return data.ModStorage(_Store(store), modname).get(key)


def pending_markers(store):
    return sorted(k for k in data.ModStorage(_Store(store), CORE).keys()
                  if k.startswith(MARKER_PREFIX))


def area_blocks(claim):
    """The block box of the claim's area: (low, high) block positions."""
    def block(value):
        return value // BLOCK
    return ((block(claim.x - RADIUS), block(MIN_Y), block(claim.z - RADIUS)),
            (block(claim.x + RADIUS), MAX_BLOCK_Y, block(claim.z + RADIUS)))


def in_area(claim, x, y, z):
    return (claim.x - RADIUS <= x <= claim.x + RADIUS and
            claim.z - RADIUS <= z <= claim.z + RADIUS and y >= MIN_Y)


def _workspace_items(text):
    """The non-empty item strings of a workspace record, list by list in
    name order; None when the record is no table of lists."""
    try:
        record = codec.deserialize(text)
    except codec.CodecError:
        return None
    lists = record.get("lists") if isinstance(record, dict) else None
    if isinstance(lists, list) and not lists:
        lists = {}
    if not isinstance(lists, dict):
        return None
    items = []
    for name in sorted(lists, key=str):
        stacks = lists[name]
        if isinstance(stacks, dict) and not stacks:
            stacks = []
        if not isinstance(stacks, list):
            return None
        items += [s for s in stacks if isinstance(s, str) and s]
    return items


def scan_claim(map_reader, claim):
    """Reads the claim's blocks and finds what it holds."""
    scan = ClaimScan(claim)
    low, high = area_blocks(claim)
    for (bx, by, bz), row in map_reader.blocks(low, high):
        scan.blocks += 1
        try:
            block = decode(row)
        except BlockError as err:
            raise PackError("claim %d (%s): block (%d, %d, %d): %s"
                            % (claim.id, claim.owner, bx, by, bz, err)) from None
        for index, meta in sorted(block.meta.items()):
            ox, oy, oz = index_offsets(index)
            pos = (bx * BLOCK + ox, by * BLOCK + oy, bz * BLOCK + oz)
            if not in_area(claim, *pos):
                continue
            node = block.name_at(index)
            if node is None:
                raise PackError("claim %d: block (%d, %d, %d) has no name for the node at %s"
                                % (claim.id, bx, by, bz, pos))
            if meta.lists:
                scan.containers.append(Container(
                    pos, node, {inv.name: list(inv.items) for inv in meta.lists}))
                if not meta.has_items():
                    scan.empty[node] = scan.empty.get(node, 0) + 1
            for name in sorted(meta.fields):
                if not name.startswith(WORKSPACE_PREFIX):
                    continue
                items = _workspace_items(meta.fields[name])
                if items is None:
                    raise PackError("claim %d: the workspace record %s at %s does not decode"
                                    % (claim.id, name, pos))
                if items:
                    scan.containers.append(Container(
                        pos, WORKSPACE_NODE, {WORKSPACE_LIST: items},
                        "workspace:" + name[len(WORKSPACE_PREFIX):]))
    scan.containers.sort(key=lambda c: (c.pos, c.source))
    return scan


def charcoal_count(claim, now):
    """The stone's remaining fuel as charcoal, rounded up (plan section 3)."""
    remaining = claim.paid_until - now
    return math.ceil(remaining / LUMP_SECONDS) if remaining > 0 else 0


def packed_string(container, seq):
    lists = {name: container.lists[name] for name in sorted(container.lists)}
    return ItemStack(PACKED_ITEM, 1, 0, {
        "node": container.node,
        "lists": codec.serialize(lists),
        "seq": str(seq),
    }).to_string()


def build(scans, seq, now):
    """The pass's entries [(key, item string)] and its counts."""
    entries, numbers, owners = [], {}, set()
    counts = dict.fromkeys(COUNT_KEYS, 0)
    for scan in scans:
        claim = scan.claim
        counts["claims"] += 1
        counts["blocks_read"] += scan.blocks

        def add(text):
            numbers[claim.owner] = numbers.get(claim.owner, 0) + 1
            owners.add(claim.owner)
            entries.append((ENTRY % (claim.owner, seq, numbers[claim.owner]), text))

        for container in scan.containers:
            add(packed_string(container, seq))
            counts["containers"] += 1
            counts["items"] += sum(1 for item in
                                   (s for stacks in container.lists.values() for s in stacks)
                                   if item)
        pieces = charcoal_count(claim, now)
        counts["charcoal"] += pieces
        while pieces > 0:
            stack = min(pieces, CHARCOAL_STACK)
            add(ItemStack(CHARCOAL, stack).to_string())
            pieces -= stack
    counts["players"] = len(owners)
    return entries, counts


def by_node(scans):
    """What the pass packed by node name, and the empty ones among them."""
    packed, empty = {}, {}
    for scan in scans:
        for container in scan.containers:
            name = container.node if container.source == "node" else "workspace record"
            packed[name] = packed.get(name, 0) + 1
        for name, count in scan.empty.items():
            empty[name] = empty.get(name, 0) + count
    return dict(sorted(packed.items())), dict(sorted(empty.items()))


def verify(entries, scans, seq):
    """Every entry parses back to exactly what was packed (the codecs the
    game's ItemStack and core.deserialize mirror)."""
    containers = [c for scan in scans for c in scan.containers]
    packed = [text for _, text in entries if ItemStack.parse(text).name == PACKED_ITEM]
    if len(packed) != len(containers):
        raise AssertionError("%d packed entries for %d containers"
                             % (len(packed), len(containers)))
    for text, container in zip(packed, containers):
        stack = ItemStack.parse(text)
        if (stack.count, stack.wear) != (1, 0) or sorted(stack.meta) != ["lists", "node", "seq"] \
                or stack.meta["node"] != container.node or stack.meta["seq"] != str(seq):
            raise AssertionError("a packed entry does not read back: %r" % text[:120])
        lists = codec.deserialize(stack.meta["lists"])
        lists = {k: (v if v != {} else []) for k, v in lists.items()} if lists != [] else {}
        if lists != container.lists:
            raise AssertionError("the lists of a packed %s do not read back" % container.node)


def taken_keys(store, entries):
    """The entries' keys that exist already (none, unless pack_seq was set
    back by hand)."""
    return [key for key, _ in entries if storage_get(store, HOUSING, key) is not None]


def write(store, entries, seq):
    """The pass's writes in the open mod-storage transaction; checked
    before the commit: only new keys, each reads back, nothing else
    changed. Returns the number of keys written."""
    table = data._storage_table(store)

    def rows():
        return store.execute("SELECT COUNT(*) FROM %s" % table).fetchone()[0]

    before = rows()
    writes = list(entries) + [(SEQ_KEY, str(seq))]
    for key, _ in entries:
        if storage_get(store, HOUSING, key) is not None:
            raise AssertionError("the key %s exists already" % key)
    new_seq_key = storage_get(store, HOUSING, SEQ_KEY) is None
    marker = MARKER_PREFIX + str(seq)
    for key, value in writes:
        data.storage_write(store, HOUSING, key, value)
    data.storage_write(store, CORE, marker, "1")
    for key, value in writes:
        if storage_get(store, HOUSING, key) != value:
            raise AssertionError("grug_housing %s does not read back" % key)
    if storage_get(store, CORE, marker) != "1":
        raise AssertionError("grug_core %s does not read back" % marker)
    added = len(entries) + (1 if new_seq_key else 0) + 1
    if rows() != before + added:
        raise AssertionError("mod storage has %d rows, expected %d"
                             % (rows(), before + added))
    return len(writes) + 1
