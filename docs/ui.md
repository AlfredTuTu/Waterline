# Notch UI

Read alongside `Presentation/NotchGeometry.swift` and the `WaterlineApp` target. Everything that can be
derived from a `Snapshot` without AppKit is computed in `WaterlineKit/Presentation` and tested there.

## Window

- `NSPanel`, `[.borderless, .nonactivatingPanel]`, level above the menu bar, collection behaviour
  `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, transparent, no shadow, not
  movable. Content is an `NSHostingView`.
- Geometry comes from `NotchGeometry.compute(screenFrame:safeAreaTop:auxiliaryTopLeftWidth:auxiliaryTopRightWidth:)`:
  - housing present → `.notch`: the collapsed frame spans the housing plus `sideWidth` (132 pt) on each
    side, height = `safeAreaInsets.top`, hugging the top edge;
  - no housing (external display, older Mac) → `.floating`: a 264×32 capsule 8 pt below the top edge.
- One panel, on the built-in display when it has a housing, otherwise on the main display.
- The expanded panel hangs down from the housing's bottom edge; nothing grows sideways — there is no
  room beside the menu bar items.

## States

```
collapsed          ● ● ●  ▓▓▓▓▓ housing ▓▓▓▓▓  ◔ 82%
                   dots, one per account         the single headline metric

expanded           ┌──────────────────────────────────────────┐
                   │ Claude Code · Max                        │
                   │ 5h ▓▓▓▓▓▓▓░░░ 68%   resets in 1h 12m     │
                   │ 7d ▓▓▓░░░░░░░ 31%   resets in 4d 6h      │
                   ├──────────────────────────────────────────┤
                   │ Kimi Code · via OpenCode Go              │
                   │ 5h ▓░░░░░░░░░  3%   resets in 4h 15m     │
                   ├──────────────────────────────────────────┤
                   │ DeepSeek                                 │
                   │ ¥465.46   today ≈ ¥3.2   ≈ 145 days      │
                   ├──────────────────────────────────────────┤
                   │ Cursor                    2 min ago      │   greyed: stale
                   │ monthly ▓▓▓▓░░░░░░ 41%                   │
                   ├──────────────────────────────────────────┤
                   │ Qwen                    not supported    │
                   ├──────────────────────────────────────────┤
                   │ ↻ 2 min ago                  Refresh  ⚙  │
                   └──────────────────────────────────────────┘

activity (v0.4)    ┌──────────────────────────┐
                   │ ● Claude Code            │   auto-expands for 3 s on an alert
                   │   5h window at 92%       │
                   └──────────────────────────┘
```

### Collapsed

- Left: one dot per account, colour = health (below). Dots keep account order.
- Right: exactly one metric. Windows first: the highest `usedFraction` across all window accounts, as a
  percent with a small arc. If no window account exists: the balance with the fewest estimated days
  left, as an amount. A window always wins over a balance because rate limiting stops work; a low
  balance only warns.
- Height never exceeds `safeAreaInsets.top`; the menu bar stays clickable around it.

### Expanded

- One row per **account**, never per vendor. A row is one of:
  - `WindowRow` — plan name if the provider returned one; one bar per window with percent and
    "resets in …"; the worst window first.
  - `BalanceRow` — amount and currency as returned; "today ≈" and "≈ N days" only when two or more
    history readings exist (v0.2), rendered as estimates.
  - `UnsupportedRow` — the vendor name and the reason from `Usage.unsupported`.
- Gateway routes (v0.2) show the gateway's quota with the subtitle "via <gateway>".
- `stale`: the row keeps its numbers in the secondary colour and shows the reading's age on the right.
- `unavailable`: no numbers; the reason in words ("needs connect", "signed out", "endpoint changed",
  "offline").
- Footer: last refresh age, Refresh, Settings.

## Colour and type

| Condition | Colour |
|---|---|
| window `usedFraction` < 0.70, balance above its threshold | green |
| 0.70 ≤ fraction < 0.90 | orange |
| fraction ≥ 0.90, balance below its threshold | red |
| stale, unavailable, unsupported | grey |

Values from the provider use the primary text colour. Estimates use the secondary colour and start with
`≈`. Monospaced digits everywhere numbers align. Rounded system font, 12 pt in the collapsed bar,
13 pt in rows.

## Interactions

| Trigger | Behaviour |
|---|---|
| hover the collapsed panel | expand after 150 ms; collapse 300 ms after the pointer leaves |
| click the collapsed panel | pin expanded; click again to collapse |
| double-click a row | open the provider's console in the browser (top-up and upgrades happen there, not in the app) |
| menu bar item | Refresh, Settings (v0.3), Quit |
| window ≥ threshold or balance below threshold (v0.4) | activity state for 3 s, once per account per hour, plus a system notification |
| screen configuration change | recompute geometry; move the panel |

## Copy

Short, no implementation words. "resets in 1h 12m", "needs connect", "offline" — not "OAuth token
expired" or "HTTP 401". Localised zh-Hans and en (v0.3).
