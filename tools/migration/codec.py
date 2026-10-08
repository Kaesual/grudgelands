"""The codecs of saved game state (contract R5): core.serialize, JSON and
item strings, each mirroring the engine source it names.

Strings: the databases hold bytes. The tool hands steps `str` values decoded
from UTF-8 with the `surrogateescape` error handler, so every byte sequence,
valid UTF-8 or not, round-trips unchanged; `to_bytes` reverses it.

core.serialize / core.deserialize (reference_projects/luanti/
builtin/common/serialize.lua): the serializer writes `return <value>`, before
it optionally `local _={};` with `_[n]=<string or {}>;` for strings and
tables used more than once (lines 59-88) and `_[n].key=<value>;` /
`_[n][<key>]=<value>;` to fill shared or circular tables (lines 159-178);
numbers with `%.17g`, NaN as `0/0` and infinities as `1/0` and `-1/0`
(lines 106-116); strings with `%q` (line 52); tables as `{list,key=value}`
with short keys for identifiers that are no keywords (lines 92-94, 130-158).
`deserialize` runs that text in an environment with `inf` and `nan` (lines
229-230). `deserialize` here reads exactly that language: literals, table
constructors, the `_` reference statements, unary minus and `/` between
numbers; never a function (`loadstring`), which the game never stores.

Lua values in Python: nil is None, booleans and strings as such, a number
written without fraction or exponent is an int, any other a float; a table
whose keys are exactly 1..n (n >= 1) is a list, any other table (the empty
one too) a dict. Shared and circular tables stay shared and circular.
`serialize` writes the same shapes back (lists and tuples as sequences,
dicts as key/value tables; None values in a dict are left out, as Lua
cannot store them), without references: a shared table is written twice, a
circular one is refused.

JSON: the game stores JSON only in player meta it writes by hand
(grug_visuals/appearance.lua `appearance_json`) and reads JSON data files
with core.parse_json (jsoncpp, script/lua_api/l_util.cpp:99-146).
`parse_json` is the standard parser; `write_json` writes compact JSON in the
dict's own order, so a value read and written again keeps its key order.
The engine's own write_json (l_util.cpp:149-176, c_content.cpp:2224-2296)
sorts keys and writes an empty table as `null`; nothing the game saves
depends on either.

Item strings (src/inventory.cpp ItemStack::serialize lines 42-68 and
deSerialize lines 70-221; src/itemstackmetadata.cpp serialize lines 41-51,
deSerialize lines 53-75; the JSON-like quoting src/util/serialize.cpp
serializeJsonString lines 173-219, deSerializeJsonString lines 221-311,
...IfNeeded lines 313-336): `name [count [wear [meta]]]`, each part written
only when a later one or a non-default value needs it; the name and the
meta quoted when they hold a space, a quote, a control or a non-ASCII byte;
meta as `\\x01` then `key\\x02value\\x03` pairs. The pre-2012 legacy forms
(`MaterialItem`, `craft`, `tool` and the like) are refused.
"""

import json
import math
import re
from dataclasses import dataclass, field


def to_str(data):
    """Bytes from a database as the tool's str (UTF-8, surrogateescape)."""
    return data.decode("utf-8", "surrogateescape")


def to_bytes(text):
    """The inverse of `to_str`."""
    return text.encode("utf-8", "surrogateescape")


class CodecError(ValueError):
    pass


# ---------------------------------------------------------------------------
# core.serialize / core.deserialize
# ---------------------------------------------------------------------------

_KEYWORDS = frozenset((
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while", "goto"))
_NAME = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*")
_DEC = re.compile(rb"[0-9]*\.?[0-9]*(?:[eE][+-]?[0-9]+)?")
_HEX = re.compile(rb"0[xX][0-9A-Fa-f]+")
_WS = b" \t\n\r\f\v"
_ESCAPES = {ord("a"): 7, ord("b"): 8, ord("f"): 12, ord("n"): 10,
            ord("r"): 13, ord("t"): 9, ord("v"): 11, ord("\\"): 92,
            ord('"'): 34, ord("'"): 39}
_MAX_EXACT = 2 ** 53


class _Table:
    """A Lua table while parsing: keys are ("n", number), ("s", bytes) or
    ("b", bool), in insertion order."""

    __slots__ = ("entries",)

    def __init__(self):
        self.entries = {}


class _Ref:
    __slots__ = ("index",)

    def __init__(self, index):
        self.index = index


def _key(value):
    if isinstance(value, bool):
        return ("b", value)
    if isinstance(value, (int, float)):
        if isinstance(value, float):
            if math.isnan(value):
                raise CodecError("a table key is NaN")
            if value.is_integer():
                value = int(value)
        return ("n", value)
    if isinstance(value, bytes):
        return ("s", value)
    raise CodecError("a table key of an unsupported type")


class _Parser:
    def __init__(self, data):
        self.data = data
        self.pos = 0
        self.refs = {}

    def fail(self, what):
        raise CodecError("%s at byte %d" % (what, self.pos))

    def ws(self):
        data, pos = self.data, self.pos
        while pos < len(data) and data[pos] in _WS:
            pos += 1
        self.pos = pos

    def peek(self, text):
        self.ws()
        return self.data.startswith(text, self.pos)

    def accept(self, text):
        if self.peek(text):
            self.pos += len(text)
            return True
        return False

    def expect(self, text):
        if not self.accept(text):
            self.fail("expected %r" % text.decode())

    def name(self):
        self.ws()
        match = _NAME.match(self.data, self.pos)
        return match.group() if match else None

    def keyword(self, word):
        if self.name() == word:
            self.pos += len(word)
            return True
        return False

    def chunk(self):
        if self.keyword(b"local"):
            self.expect(b"_")
            self.expect(b"=")
            self.expect(b"{")
            self.expect(b"}")
            self.accept(b";")
            while self.peek(b"_["):
                self.statement()
        if not self.keyword(b"return"):
            self.fail("expected 'return'")
        value = self.expr()
        self.accept(b";")
        self.ws()
        if self.pos != len(self.data):
            self.fail("unexpected text after the value")
        return value

    def statement(self):
        self.expect(b"_[")
        index = self.expr()
        self.expect(b"]")
        if self.accept(b"="):
            self.refs[_key(index)] = self.expr()
        else:
            target = self.refs.get(_key(index))
            if not isinstance(target, _Table):
                self.fail("assignment into a missing reference")
            if self.accept(b"."):
                key = self.name()
                if key is None:
                    self.fail("expected a field name")
                self.pos += len(key)
            else:
                self.expect(b"[")
                key = self.expr()
                self.expect(b"]")
            self.expect(b"=")
            self.store(target, key, self.expr())
        self.accept(b";")

    def store(self, table, key, value):
        if isinstance(key, _Table):
            self.fail("a table used as a key")
        if key is None:
            self.fail("nil used as a key")
        key = _key(key)
        if value is None:
            table.entries.pop(key, None)
        else:
            table.entries[key] = value

    def expr(self):
        value = self.simple()
        if self.accept(b"/"):
            divisor = self.simple()
            if not _is_number(value) or not _is_number(divisor):
                self.fail("division of non-numbers")
            value = _divide(value, divisor)
        return value

    def simple(self):
        self.ws()
        if self.accept(b"-"):
            value = self.simple()
            if not _is_number(value):
                self.fail("unary minus on a non-number")
            return -value
        data, pos = self.data, self.pos
        if pos >= len(data):
            self.fail("unexpected end")
        char = data[pos]
        if char in b"\"'":
            return self.string()
        if char == ord("{"):
            return self.table()
        if data.startswith(b"_[", pos):
            self.pos += 2
            index = self.expr()
            self.expect(b"]")
            try:
                return self.refs[_key(index)]
            except KeyError:
                self.fail("unknown reference")
        if char in b"0123456789." and not data.startswith(b"..", pos):
            return self.number()
        word = self.name()
        if word is None:
            self.fail("unexpected character")
        self.pos += len(word)
        if word == b"nil":
            return None
        if word == b"true":
            return True
        if word == b"false":
            return False
        if word == b"inf":
            return math.inf
        if word == b"nan":
            return math.nan
        self.fail("unsupported name %r" % word.decode("latin-1"))

    def number(self):
        data, pos = self.data, self.pos
        match = _HEX.match(data, pos)
        if match:
            self.pos = match.end()
            return int(match.group(), 16)
        match = _DEC.match(data, pos)
        text = match.group()
        if not text or text == b".":
            self.fail("malformed number")
        self.pos = match.end()
        if text.isdigit():
            return int(text)
        try:
            return float(text)
        except ValueError:
            self.fail("malformed number")

    def string(self):
        data = self.data
        quote = data[self.pos]
        pos = self.pos + 1
        out = bytearray()
        while True:
            if pos >= len(data):
                self.fail("unfinished string")
            char = data[pos]
            if char == quote:
                self.pos = pos + 1
                return bytes(out)
            if char in b"\n\r":
                self.pos = pos
                self.fail("unfinished string")
            if char != 92:
                out.append(char)
                pos += 1
                continue
            pos += 1
            if pos >= len(data):
                self.fail("unfinished string")
            char = data[pos]
            if char in _ESCAPES:
                out.append(_ESCAPES[char])
                pos += 1
            elif char in b"\n\r":
                out.append(10)
                pos += 1
                if pos < len(data) and data[pos] in b"\n\r" and data[pos] != char:
                    pos += 1
            elif 48 <= char <= 57:
                end = pos
                while end < len(data) and end - pos < 3 and 48 <= data[end] <= 57:
                    end += 1
                value = int(data[pos:end])
                if value > 255:
                    self.pos = pos
                    self.fail("escape too large")
                out.append(value)
                pos = end
            else:
                self.pos = pos
                self.fail("invalid escape")

    def table(self):
        self.expect(b"{")
        table = _Table()
        index = 1
        while not self.accept(b"}"):
            if self.accept(b"["):
                key = self.expr()
                self.expect(b"]")
                self.expect(b"=")
                self.store(table, key, self.expr())
            else:
                word = self.name()
                after = self.pos + len(word) if word else 0
                if word and word.decode() not in _KEYWORDS and self._assign_follows(after):
                    self.pos = after
                    self.expect(b"=")
                    self.store(table, word, self.expr())
                else:
                    self.store(table, index, self.expr())
                    index += 1
            if not (self.accept(b",") or self.accept(b";")):
                self.expect(b"}")
                break
        return table

    def _assign_follows(self, pos):
        data = self.data
        while pos < len(data) and data[pos] in _WS:
            pos += 1
        return data.startswith(b"=", pos) and not data.startswith(b"==", pos)


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _divide(a, b):
    if b == 0:
        if a == 0 or (isinstance(a, float) and math.isnan(a)):
            return math.nan
        return math.inf if a > 0 else -math.inf
    return a / b


def _convert(value, memo):
    if isinstance(value, bytes):
        return to_str(value)
    if not isinstance(value, _Table):
        return value
    done = memo.get(id(value))
    if done is not None:
        return done
    entries = value.entries
    count = len(entries)
    if count and all(key[0] == "n" and isinstance(key[1], int) for key in entries) \
            and set(key[1] for key in entries) == set(range(1, count + 1)):
        out = []
        memo[id(value)] = out
        out.extend(_convert(entries[("n", i)], memo) for i in range(1, count + 1))
        return out
    out = {}
    memo[id(value)] = out
    for key, item in entries.items():
        kind, raw = key
        pykey = to_str(raw) if kind == "s" else raw
        if pykey in out:
            raise CodecError("the keys %r collide in Python" % (pykey,))
        out[pykey] = _convert(item, memo)
    return out


def deserialize(text):
    """core.deserialize for the language core.serialize writes."""
    parser = _Parser(to_bytes(text) if isinstance(text, str) else text)
    return _convert(parser.chunk(), {})


def _quote(data):
    """LuaJIT's %q (the server's interpreter): a newline as a backslash and
    the newline, a control byte as a decimal escape, three digits when a
    digit follows."""
    out = bytearray(b'"')
    for index, char in enumerate(data):
        if char in (34, 92):
            out += b"\\%c" % char
        elif char == 10:
            out += b"\\\n"
        elif char < 32 or char == 127:
            following = data[index + 1:index + 2]
            out += (b"\\%03d" if following.isdigit() else b"\\%d") % char
        else:
            out.append(char)
    out.append(34)
    return bytes(out)


def _dump(value, out, path):
    if value is None:
        out.append(b"nil")
    elif value is True:
        out.append(b"true")
    elif value is False:
        out.append(b"false")
    elif isinstance(value, int):
        if abs(value) > _MAX_EXACT:
            raise CodecError("%d is not exact as a Lua number" % value)
        out.append(b"%d" % value)
    elif isinstance(value, float):
        if math.isnan(value):
            out.append(b"0/0")
        elif math.isinf(value):
            out.append(b"1/0" if value > 0 else b"-1/0")
        else:
            out.append(b"%.17g" % value)
    elif isinstance(value, str):
        out.append(_quote(to_bytes(value)))
    elif isinstance(value, bytes):
        out.append(_quote(value))
    elif isinstance(value, (list, tuple, dict)):
        if id(value) in path:
            raise CodecError("a circular table cannot be serialized")
        path.add(id(value))
        out.append(b"{")
        if isinstance(value, dict):
            # The sequence part first, as the engine writes it.
            ints = {key for key in value if type(key) is int}
            length = 0
            while length + 1 in ints and value[length + 1] is not None:
                length += 1
            sequence = [value[i] for i in range(1, length + 1)]
            pairs = [(k, v) for k, v in value.items()
                     if v is not None and not (type(k) is int and 1 <= k <= length)]
        else:
            sequence, pairs = value, ()
        first = True
        for item in sequence:
            if item is None:
                raise CodecError("nil inside a sequence")
            if not first:
                out.append(b",")
            first = False
            _dump(item, out, path)
        for key, item in pairs:
            if not first:
                out.append(b",")
            first = False
            if isinstance(key, str) and key not in _KEYWORDS \
                    and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                out.append(key.encode())
            elif key is None or isinstance(key, (list, tuple, dict)):
                raise CodecError("unsupported table key %r" % (key,))
            else:
                out.append(b"[")
                _dump(key, out, path)
                out.append(b"]")
            out.append(b"=")
            _dump(item, out, path)
        out.append(b"}")
        path.discard(id(value))
    else:
        raise CodecError("cannot serialize %s" % type(value).__name__)


def serialize(value):
    """core.serialize: the text core.deserialize reads back as `value`."""
    out = [b"return "]
    _dump(value, out, set())
    return to_str(b"".join(out))


# ---------------------------------------------------------------------------
# JSON
# ---------------------------------------------------------------------------

def parse_json(text):
    """core.parse_json: JSON null reads as None."""
    return json.loads(text)


def write_json(value):
    """Compact JSON in the value's own key order."""
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"),
                      allow_nan=False)


# ---------------------------------------------------------------------------
# Item strings
# ---------------------------------------------------------------------------

_HEXCHARS = "0123456789abcdef"
_JSON_ESCAPES = {'"': '\\"', "\\": "\\\\", "\b": "\\b", "\f": "\\f",
                 "\n": "\\n", "\r": "\\r", "\t": "\\t"}
_JSON_UNESCAPES = {"b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t"}
_LEGACY_NAMES = frozenset(("MaterialItem", "MaterialItem2", "node", "NodeItem",
                           "MaterialItem3", "craft", "CraftItem", "MBOItem",
                           "tool", "ToolItem"))
_META_START, _META_KV, _META_PAIR = "\x01", "\x02", "\x03"


def _byte(char):
    """The byte a str character of the tool's convention stands for, or
    None for a character beyond one byte (UTF-8 bytes >= 0x80 count as
    above 0x7f either way)."""
    code = ord(char)
    if 0xDC80 <= code <= 0xDCFF:
        return code - 0xDC00
    return code if code < 0x80 else 0xFF


def _json_string(text):
    out = ['"']
    for char in text:
        if char in _JSON_ESCAPES:
            out.append(_JSON_ESCAPES[char])
        elif ord(char) < 32 or char == "\x7f":
            out.append("\\u00" + _HEXCHARS[ord(char) >> 4] + _HEXCHARS[ord(char) & 15])
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


def _json_string_if_needed(text):
    for char in text:
        byte = _byte(char)
        if byte <= 0x1F or byte >= 0x7F or char in ' "':
            return _json_string(text)
    return text


def _read_json_string(text, pos):
    """The engine's deSerializeJsonString from `pos` (at the quote): the
    string and the position after it."""
    end = pos + 1
    backslash = False
    while True:
        if end >= len(text):
            raise CodecError("JSON string ended prematurely")
        char = text[end]
        end += 1
        if backslash:
            backslash = False
        elif char == "\\":
            backslash = True
        elif char == '"':
            break
    body = text[pos + 1:end - 1]
    out = []
    i = 0
    while i < len(body):
        char = body[i]
        i += 1
        if char != "\\":
            out.append(char)
            continue
        if i >= len(body):
            raise CodecError("JSON string ended prematurely")
        char = body[i]
        i += 1
        if char == "u":
            if i + 4 > len(body):
                raise CodecError("JSON string ended prematurely")
            try:
                value = int(body[i:i + 4], 16) & 0xFF
            except ValueError:
                raise CodecError("invalid \\u escape") from None
            i += 4
            out.append(chr(value) if value < 0x80 else chr(0xDC00 + value))
        else:
            out.append(_JSON_UNESCAPES.get(char, char))
    return "".join(out), end


def _read_part(text, pos):
    """deSerializeJsonStringIfNeeded: a quoted string or text up to a space."""
    if pos >= len(text):
        return "", pos
    if text[pos] == '"':
        return _read_json_string(text, pos)
    end = text.find(" ", pos)
    end = len(text) if end < 0 else end
    return text[pos:end], end


def _token(text, pos):
    """std::getline(is, token, ' '): the token and the position after the
    space."""
    end = text.find(" ", pos)
    if end < 0:
        return text[pos:], len(text)
    return text[pos:end], end + 1


def _sanitize(text):
    return text.replace(_META_START, "").replace(_META_KV, "").replace(_META_PAIR, "")


@dataclass
class ItemStack:
    """An item stack: `name` "" is the empty stack. `meta` maps the item's
    meta keys to their strings, in their stored order."""

    name: str = ""
    count: int = 1
    wear: int = 0
    meta: dict = field(default_factory=dict)

    def is_empty(self):
        return self.name == "" or self.count == 0

    @classmethod
    def parse(cls, text):
        """ItemStack::deSerialize without an item definition manager (no
        aliases, a tool's count kept as stored)."""
        name, pos = _read_part(text, 0)
        if pos < len(text):
            if text[pos] != " ":
                raise CodecError("unexpected text after the item name")
            pos += 1
        if name in _LEGACY_NAMES:
            raise CodecError("legacy item string %r" % name)
        stack = cls(name)
        if pos < len(text):
            count, pos = _token(text, pos)
            if count != "":
                stack.count = int(count)
                wear, pos = _token(text, pos)
                if wear != "":
                    stack.wear = int(wear)
                    raw, pos = _read_part(text, pos)
                    if raw.startswith(_META_START):
                        rest = raw[1:]
                        while rest:
                            key, _, rest = rest.partition(_META_KV)
                            value, _, rest = rest.partition(_META_PAIR)
                            stack.meta[key] = value
                    elif raw:
                        stack.meta[""] = raw
        if stack.is_empty():
            return cls("", 0)
        return stack

    def to_string(self):
        """ItemStack::serialize with the meta."""
        if self.is_empty():
            return ""
        meta = {_sanitize(k): _sanitize(v) for k, v in self.meta.items()}
        parts = 4 if meta else 3 if self.wear != 0 else 2 if self.count != 1 else 1
        out = [_json_string_if_needed(self.name)]
        if parts >= 2:
            out.append(str(int(self.count)))
        if parts >= 3:
            out.append(str(int(self.wear)))
        if parts >= 4:
            raw = _META_START + "".join(
                k + _META_KV + v + _META_PAIR for k, v in meta.items() if k or v)
            out.append(_json_string_if_needed(raw))
        return " ".join(out)
