# WP44 Income-Ledger Preflight Handoff

Status: supplementary read-only research; not an accepted WP44 contract and
not an implementation GO
Snapshot date: 2026-08-29 (Europe/Berlin)

## 1. Purpose and verdict

Fable Task B reviewed the future WP44 income-ledger and price-calibration
boundary against the prepared repository snapshot. It found a coherent,
versionable architecture and no additional user design decision, but it did
not run code, build, test or independently accept an implementation.

Future WP44 work must revalidate every source against its own branch. This
record preserves the useful model and review provenance so the disposable
Anthropic snapshot can be removed without losing project context.

## 2. Recommended versioned baseline

- Use a one-hour normalization window (`3,600 s`) for analytic solo at-tier
  income. It matches the deterministic vendor-rotation period and is a model
  constant, not a sampled play session.
- Classify every stream as `observed`, `modeled` or `excluded`, with authority,
  owning WP and rerun trigger. Quest rewards begin at zero until WP8; repairs
  and future consumables remain explicit modeled rows until their owners ship.
- Exclude jackpots, named-rares, bosses, kings, player trade, PvP-only drops,
  direct coin drops and other non-routine rewards from reliable income.
- Compute expected vendor value analytically from registered drop tables using
  integer rational pairs. Do not use runtime sampling or floating-point money.
- Require a minimum expected event count and a maximum single-event share as
  versioned concentration gates before a stream may count as reliable income.
- Keep the dependency acyclic: the authored Common-price axis determines
  repair/consumable schedules; modeled deductions then determine net income;
  only claims, mounts and other derived sinks consume the measured result.
- Identify every published ledger by `(schema_version,
  model_constants_version, snapshot_commit)` and emit a canonical sorted
  integer/rational encoding plus SHA-256.

Mandatory rerun triggers include WP5, WP8, WP10, WP22, WP26, WP29, WP30,
WP34, WP37, WP40 and WP41 whenever they change a modeled or observed input.
A rerun never silently changes design prices: adopting new published copper
values remains an explicit documentation decision.

## 3. Arithmetic recommendations

For reference price `p >= 0`, the decided 5% ceiling buy-back cap is:

```text
buyback_cap(p) = floor((p + 19) / 20)
payout(item) = min(authored_payout, buyback_cap(reference_price))
```

The same-race buy discount remains
`max(1, floor(9 * p / 10))` and applies only on the buy side. Buy-back derives
from the undiscounted reference. A vendor-sold item must satisfy strict
`payout < discounted_buy_price`; consequently any vendor good priced at one or
two copper must remain unsellable.

For positive integer target `X`, choose the first accepted denomination from
`100, 25, 5, 1` copper:

```text
M(d) = floor((2 * X + d) / (2 * d)) * d
accept d iff 20 * abs(M(d) - X) <= X
```

This rounds exact midpoints upward and picks the coarsest denomination within
5%. Non-positive targets are validation failures, never publishable prices.
The future contract should retain the report's boundary KATs, especially
25c -> 2c and 2500c -> 125c buy-back, plus denomination inputs 950 and 1050.

## 4. Required artifact and audits

The proposed artifact contains the schema/model versions, snapshot commit,
versioned constants and digest, stream rows, per-tier gross/deductions/net,
derived targets, audit receipts and KAT receipts. Keys are sorted; values are
integers or canonical `numerator/denominator` strings; no float or unordered
engine serializer enters the digest.

WP44 should extend the shipped trader audits with:

1. complete positive-payout coverage for every ordinary mob drop;
2. exact buy-back cap conformance;
3. strict no-spread checks after the same-race discount;
4. strict craft/cook anti-loop checks;
5. an equality budget for reversible nine-unit storage pack/unpack pairs;
6. verbatim service-fee table checks without faction discounts; and
7. time-to-buy and trader-substitution checks against the measured tier axis.

The independent reviewer reruns the pure ledger generator, requires a
byte-identical artifact digest, verifies all rounding KATs, loads the registry
and confirms clean audits, checks service tables verbatim, and confirms that
modeled future behavior is never presented as shipped.

## 5. Snapshot findings to recheck in WP44

- **Medium:** the design requires crafted output vendor value to be strictly
  below priced inputs, but the shipped audit rejected only `output > inputs`.
  Iron Lump and Iron Bar were both priced at 3c, so equality passed. WP44 owns
  tightening the audit and repricing the pair.
- **Low:** a trader comment still cited a retired “1-6c” §8.1 band. The cited
  section no longer contains that band; separate current payouts elsewhere
  already reach 7c.
- **Low, snapshot-only:** the Task B snapshot omitted
  `docs/process/agent-model-policy.md`; the current repository contains it, so
  future review uses the live file.

Expected missing WP8/WP10/WP22/WP31 behaviors and missing final reference
prices were correctly treated as dependency work, not implementation defects.

## 6. Fable provenance

The byte-identical full Task B report is preserved as
[`wp44-fable-task-b-report.md`](wp44-fable-task-b-report.md). Its SHA-256 is
`1846a73d315926b970e3053d520495f0b05d8083437c8ac56f8956679fb6e8be`;
JSONL `68535a2e5eef01f5492a8d1613e766f565d5983d0553efba794d2ed6291ebabc`;
prompt `70b092c769f396474500ba3dc12ec30d7b638522cd03ded9943397f66100bb2f`.
It ran as `claude-fable-5` through Claude Code 2.1.228, exited zero with empty
stderr and used read/search tools only. CLI-version and help captures hash to
`6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`
and `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
