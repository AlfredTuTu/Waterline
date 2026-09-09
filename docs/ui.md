# Notch UI

Target behaviour, not a claim that the current placeholder implements it. Pure selection, health,
ordering, formatting and geometry belong in `WaterlineKit/Presentation`; native interactions in the app.
Data sources and freshness follow the provider contracts.

## Current owner direction — 2026-09-06

Use [Agent Island](https://agent-island.dev/zh/) as a visual reference, not a product clone. The owner
has more providers/accounts: use a black notch-connected surface, generous percent typography and
segmented meters, with a compact footer. Header and body share one continuous black outer contour; never stack an independently rounded capsule above a rectangular card. Expanded content uses a single full-width surface, with a straight top edge against the display and rounded bottom corners. Floating mode has rounded top and bottom corners. Overview shows all configured accounts in two columns with scrolling and no count cap; paused accounts remain visible with their state.
Account positions follow saved manual order, or configuration order before the first reorder. Health changes and daily selection do not move rows; labels and enablement are saved by the engine and exposed in Settings. Each summary shows at most two primary windows; additional
buckets stay discoverable via the account detail action. Manage accounts opens the scrollable, provider-filtered Settings view. Multiple identities of a provider get a stable-order local ordinal until a safe user label exists.

Hover opens an overview without focus; clicking the header brings keyboard focus without pinning. Leaving the island or switching to another app closes an unpinned panel. Only the explicit footer pin button keeps it open. Account title/more-windows
opens details in that panel with Back. Settings will use a native settings window. Row actions never
toggle the outer panel. The header, Collapse island menu item or Escape collapses a pinned panel. Preserve
keyboard access from the menu bar. Verify hover transit and accidental menu-bar activation natively.
The current iteration implements the surfaces but has not passed the complete interaction matrix.
The September 7 owner revision removes the earlier shoulder connector entirely. Header hit-testing spans the visible expanded width; the physical camera housing remains blank. Complete native interaction-matrix verification remains outstanding.
The panel owns one persistent SwiftUI hosting view. Account-count changes update its observable
layout and native frame; resizing does not replace the view tree. Details and provider filters
remain selected during resizing, while removing the selected account or last filtered provider
clears that invalid selection. Closing and reopening starts at Overview.

## Window

- One borderless `NSPanel` above the menu bar with an `NSHostingView`; transparent, no shadow, not
  draggable. It joins Spaces and full-screen apps without appearing in the normal window cycle.
- With a housing: collapsed height equals `safeAreaInsets.top`; side areas start at 132 pt each.
  Keep content outside the physical housing. Only visible content is interactive; do not intercept
  clicks in the menu bar outside those areas. Validate side-area fit on the actual display.
- Without a housing: use a 264×32 pt floating capsule, 8 pt below the screen's top edge. The notch
  height constraint does not apply when `safeAreaInsets.top` is zero.
- Prefer the built-in display with a housing, otherwise the main display. Recompute on display/scale
  changes; keep exactly one panel and clamp it to the chosen screen.
- Expanded dimensions use the selected display stored in `NotchGeometry`, never the panel's old
  `screen` during a move. Preserve the collapsed top/centre anchor and an 8 pt bottom/side margin.
- Expand downwards from the collapsed panel's bottom edge, centred on it. Start at 640 pt wide,
  clamped to the screen with an 8 pt margin. The expanded surface is wider across its full height, including its visible top header; it may temporarily cover adjacent menu-bar content while open. Collapsing restores the narrow footprint.
  Limit height to the smaller of 600 pt or the available screen height below that edge minus 8 pt;
  scroll account content and keep the footer visible.

## Collapsed

`Dashboard.headlineSelection` selects both the headline and its source account in one operation.
Valid components in partial responses can supply a number; partial-state details remain in the expanded view.
The header and open account content re-evaluate once per second so reset boundaries and cached
observations can age out during backoff; old
numbers leave the headline and old observations mute health. Unsupported, pending, paused and no
connected account states remain distinct.

A passed reset reads Awaiting update, greys the retained meter and cannot trigger an alert. Other
current windows or balances still supply the headline. These clock-driven updates do not write
snapshots or issue network requests themselves; the engine's eligibility rules schedule requests.

Balances share the same observation-age check across headline, ordering, health, history estimates
and alerts. A new account response does not make an old component current. Retained old balances
are grey and show their observation time; a fresh low-balance confirmation can still trigger an alert.

- Left: the 18pt brand logo of the agent whose account supplies the right-hand quota or balance.
  Align its frame 18pt from the left black edge and the metric frame 18pt from the right black edge.
  Use equal-width wings around the physical housing at both collapsed and expanded widths.
  The tooltip and accessibility label include the provider and optional account nickname. Do not show
  unrelated account dots or an account-count overflow here. A status-only headline uses Waterline’s
  water-wave symbol. A temporary usage alert uses the triggering account’s provider logo. Every account
  remains accessible in the expanded list.
- Right: one headline. First choose the highest **fresh, usable** window fraction. Otherwise choose
  a fresh balance by health: critical, then OK, then no configured threshold. For ties, use stable
  account ID for equal quota fractions; balance ties use provider name then account ID, and currency
  code order for multiple equally ranked balances on one account.
  Never compare raw currency amounts or depend on a history estimate to select the headline.
- Default balance thresholds: 50 CNY and 10 USD. Other currencies have no threshold until configured;
  their amount can be displayed, but do not infer safety or convert currency.
- A fresh component of a partial account can supply a headline. The brand logo identifies the provider;
  it is not a health indicator. Stale numbers remain in expanded rows and never compete with fresh headline data.
- No accounts and no discovery errors: `Connect accounts`. Discovery with no readings: `Checking…`. Only stale readings:
  `Updated <age> ago`, using the newest retained observation. Only failures: `Needs attention`.
  Only unsupported accounts: `Not supported`. Fresh data with no eligible fraction/balance: `Details`.
  If states are mixed with no eligible metric, prefer `Needs attention` when any source failed,
  otherwise the stale label, `Checking…`, then `Not supported`.

Illustration only; these are not live account readings:

```text
collapsed          Agent logo  [ housing ]  82% used

expanded           ┌─────────────────────────────────────────┐
                   │ Account A · Plan name                    │
                   │ 5h  ▓▓▓▓▓▓▓░░░ 68%  resets in 1h 12m    │
                   │ 7d  ▓▓▓░░░░░░░ 31%  resets in 4d 6h     │
                   ├─────────────────────────────────────────┤
                   │ Account B                               │
                   │ ¥465.46  ≈ ¥3.2/day  ≈ 145 days          │
                   ├─────────────────────────────────────────┤
                   │ Account C                 Updated 2m ago│
                   │ monthly 41%                             │
                   ├─────────────────────────────────────────┤
                   │ Last attempt 2m ago   Refresh  Unpin    │
                   └─────────────────────────────────────────┘
```

## Expanded accounts

Compact secondary quotas include an explicit Awaiting update label when not current. Overview uses
the shared freshness predicate before comparing fractions, so an expired high value does not replace
a current primary metric. Partial status is a short header label in overview; detailed explanatory
copy remains in the detail view. Overview spacing is tighter and plan badges stay on one line to
avoid pushing the second row behind the footer.

Overview selects up to two primary metrics by fresh numeric fraction descending, with stale and
unquantified metrics following; equal values retain source order. Additional provider groups remain
in details. Explanatory notes alone do not indicate partial data. Amounts are shown even when no
denominator exists, with locale-aware digits and the reported unit; no cap is invented.

Account cards use two columns only at widths of at least 600 pt. Within those side-by-side cards,
headers align at the top. Overview shows the first selected quota as a full meter, the second as a
compact value row, and balances as compact rows when a quota is present. Balance-only cards keep a
large amount. Details retains the full metric grid. This prevents nested narrow meters and keeps
the common four-account mixed-kind overview within its viewport. Long account names truncate with
their full text available to accessibility/help rather than widening or wrapping the header.

One header per stable account, with the provider name, a safe distinguishing account label when
needed, and plan only when reported. Use a local ordinal if no safe label exists; never use a secret
or its fingerprint. Quota and balance are sections of that same row when both exist.

| Component/state | Presentation |
|---|---|
| Quota | Label, available count/unit or percent; bar only for a valid fraction; reset countdown only when supplied. Fresh fractions sort descending, then metrics without fractions by stable metric ID. Stale components follow fresh ones with age. |
| Balance | Amount and explicit currency; one line per currency. Balance estimates are outside the current product scope. |
| Partial | Show valid components normally; failed retained components greyed with individual age/reason. Missing components show a reason where needed, no fabricated value. |
| Stale | Keep the last reading, secondary colour and observation age. Passed reset time reads `Awaiting update`, never a negative countdown or a local zero reset. |
| Unavailable | Reason only, such as `Needs connect`, `Signed out`, `Access needed`, `Offline`, `Usage unavailable`. Offer a relevant recovery action. |
| Pending | `Checking…`; no zero, empty progress bar or simulated percentage. |
| Unsupported | Provider/account and a concise capability reason. No implication that retrying will enable it. |
| Gateway (v0.2) | Gateway identity with `via <gateway>`; show only its own verified metrics. Unknown gateways show `Usage unavailable`. |

Account order remains stable as values and health update. Native dragging in Settings saves
the user-defined order. New identities append and removed identities disappear.

Show discovery errors as source-level messages even if no account could be identified. Zero discovered
accounts with no errors shows a short explanation, `Check again` and connection guidance; if a source
failed, show the reason rather than saying no accounts exist. Basic guidance and Connect are required
in v0.1; the complete onboarding and Settings window remain v0.3. Until manual entry has a UI, the
connection guidance can describe the implemented CLI flow.

Footer: last refresh **attempt** age (`Not refreshed yet` before the first attempt), Refresh,
Unpin/Close and Settings when implemented. Refresh age
must not imply that all readings succeeded; each stale component has its own observation age. Do not
show a disabled Settings placeholder. Repeated Refresh coalesces; during server backoff show when the
next request is allowed.

## Health, type and accessibility

| Condition | Health / colour |
|---|---|
| Fresh fraction < 0.70 | OK / green |
| 0.70 ≤ fresh fraction < 0.90 | warning / orange |
| Fresh fraction ≥ 0.90 | critical / red |
| Fresh balance > its configured threshold | OK / green |
| Fresh balance ≤ its configured threshold | critical / red |
| No threshold, stale, pending, unavailable, unsupported | muted / grey |

For multiple fresh metrics use the highest severity. If any displayed component is stale or a
requested component failed, keep a fresh warning/critical signal; otherwise mute the health indicator and expose
`Partial data` to accessibility and detail. Never colour an incomplete account reassuring green.
Threshold equality is intentional. Settings may change thresholds later; require positive balance
thresholds and `0 < windowWarning < windowCritical ≤ 1`.

Reported and deterministically derived values use primary text; estimates use secondary text and
start with `≈`. Monospaced digits, rounded system font, starting at 12 pt collapsed and 13 pt expanded.
Use locale-aware amounts and dates; disambiguate currency symbols. Test en_US and zh_CN formatting
before full localisation. Long names truncate with an accessible full label; numbers and controls must
not overlap. VoiceOver describes account, metric, state and age; status must be understandable without
colour. Honour Reduce Motion and support keyboard navigation.

## Interactions

Balance estimates must not span a switch to posted credit for the same account/currency. When
available-balance readings resume, wait for a new qualifying 24-hour segment before showing an estimate.

The application bundle icon uses `app/Resources/AppIcon.png`: two unequal, offset blue water-ripple strokes on a dark rounded
tile. Bundle scripts generate 16–1024 pixel ICNS representations and declare `CFBundleIconFile`.
The menu-bar label and empty-island fallback use a matching native two-stroke template image;
macOS supplies its monochrome appearance. `LSUIElement` accessory behavior is unchanged.
The production source and provenance are `app/Resources/AppIcon.png` and `app/Resources/AppIcon.md`.
Exploratory drafts have been retired; shipping assets are retained in `Resources`.

| Trigger | Behaviour |
|---|---|
| Hover collapsed | Keep the idle size unchanged. Only clicking opens details; an expanded panel collapses 350 ms after leaving. Menu tracking temporarily defers collapse. |
| Click collapsed/header | Toggle full overview with keyboard focus. Row controls do not toggle the panel. |
| Footer pin | Select the single daily account; choosing another replaces the selection. This never holds the panel open. |
| Close or Escape | Collapse. Escape applies only while the panel has keyboard focus; no global key interception. |
| Menu bar `Show accounts` | Open without pinning, with keyboard access to controls; Tab navigates and Return/Space activates the focused control. Hover alone never steals focus. |
| Connect | Announce the scoped Keychain read before allowing interaction; cancellation leaves the row available for a later retry. |
| Account console action | Explicit `Open console` action; double-click on a non-control row area is a shortcut. Open the documented console URL without credentials or private URL parameters. |
| Menu bar | Show accounts, Refresh, Settings when implemented, Quit. |
| Screen change | Recompute frame and move the existing panel; do not create duplicates. |
| Threshold crossing (v0.4) | A fresh metric newly crosses its threshold: show activity for 3 s and notify, at most once per account per hour. Respect notification settings; stale data cannot trigger alerts. |

The native panel must support focus when explicitly opened without activating on hover. Verify in
Mission Control, full-screen apps, with VoiceOver and keyboard-only use on supported macOS versions.
Escape cancellation is handled by the native panel responder chain, so it works while the footer
menu is closed. Earlier native verification covered the former sticky-pin mode; current verification covers automatic collapse, account selection and detail dismissal and reopening at Overview.
Optional hooks and notification permissions require an explicit user action before enabling them.

## Copy

Accounts includes Optional sources → Read DEEPSEEK_API_KEY, initially off. The copy explains inherited
environment scope and the fixed provider destination. Check source is an explicit scoped reconnect;
its progress and errors are visible. A missing/removed source has a neutral no-account message,
with manual entry as the alternative. Account enablement stays distinct from source consent, and
paused source rows explain how to resume. This control has offline flow coverage; native interaction
and real DeepSeek balance verification remain open.

Usage notifications carry only the local opaque account ID as their navigation target. A click opens
that account's details with keyboard focus without pinning; repeated clicks create fresh navigation events. A click
received before the panel exists is retained until its handler is ready. Account loading has a visible
waiting state; an unavailable target falls back to the list with a short message, without creating an
account. Closing the panel clears the route so ordinary hover starts from overview again.

Partial-data details name the affected quota/currency and show the safe error message. Diagnostic
details are collapsed by default and contain only the component identifier and schema field path;
raw transport errors, headers and response bodies are not displayed. Partial rate limits show the
next allowed refresh time. Meter segment count adapts to width so full-width details retain thin
ticks. Accounts without balances do not reserve an empty history view.

Unsupported readings show a visible Not supported label and the capability reason in the account
card, with no numeric placeholder. The ordinary Reconnect menu item is omitted for that capability
state. Small reset and last-check captions use explicit lighter foregrounds on the black surface;
full accessibility and contrast acceptance remains separate from visual inspection.

The first Settings presentation shows a connection guide covering saved tool logins, Keychain prompts,
manual keys/regions, provider destinations and paused/missing-data behavior. It lists actual registered
descriptors and does not offer unavailable discovery features. Continue saves the app-local guide
completion preference, dismisses the guide and selects Accounts. General includes Connection guide
to reopen it. The guide itself requests no credentials or OS permissions. Completing it is not a claim
that an account has connected; the existing Accounts actions perform and report those operations.

General settings offers Follow system, 简体中文 and English. The choice is saved immediately and applies
on the next application launch, as the explanatory text states. It only changes Waterline's standard
per-app AppleLanguages preference; Follow system removes that override. Do not change global macOS
language or pretend that bundle-cached strings switch fully during the current session.

Native static copy is stored in `app/Resources/en.lproj/Localizable.strings` and
`app/Resources/zh-Hans.lproj/Localizable.strings`, copied into the signed app's main Resources directory.
Coverage is 202 paired keys for menus, common settings, account/key controls, dynamic account/usage
summaries, notification templates, history estimates and common system/validation errors. Some source
labels and diagnostics and full accessibility text remain unfinished. Provider names and reported labels remain source data. Resource loading has
been checked in a native bundle probe; full SwiftUI layout in both languages is not yet verified.

General settings also contains Usage notifications, initially off. Permission is requested only when
the user turns it on. It shows progress, refusal and storage/delivery errors. Notification clicks open
the account panel without pinning; a submitted alert briefly replaces the collapsed headline for 3 s without
expanding or collapsing the island. First readings, old observations and threshold-setting changes
do not create retrospective alerts. Native OS permission/banner/foreground/click checks remain pending.

General settings contains Launch at login. Its switch reflects system registration (including a
pending request); adjacent text distinguishes enabled, not registered, approval required and app
not found. Pending approval offers Open Login Items Settings. Changes show progress and failures,
then re-read system status; returning from System Settings re-reads it too. This is an immediate
system preference, separate from the Display & refresh Save button.

Main UI uses short, plain language. Diagnostics can name redacted technical causes and field paths;
never show keys, cookies, raw responses or authentication headers. Localise the full UI in zh-Hans and
en from v0.3; do not expose API status codes as the primary explanation.

## Owner refinement — 2026-09-07

The owner prefers two columns with provider identity colours on icons and healthy quota meters. Warning, critical and stale colours retain their semantic priority. Use textual region labels from each adapter's manual-region contract when available, alongside the reported currency code; do not infer endpoint or currency from the provider name. The footer Waterline menu explicitly separates Collapse island from Quit Waterline, supplementing the menu-bar exit. The unified silhouette and separate native history/Token windows are implemented. Native checks cover selected interactions and rendered states; the full OS/display/accessibility matrix remains open. The current application icon uses two unequal water-ripple lines; packaging checks do not establish small-size visual acceptance.

## Balance history window

The owner requested removal of the visible Synthetic verification data banner from native windows,
the account panel and menus. Verification provenance stays in the isolated data/results and separate
app identity; removing this presentation label never makes fixture data real provider evidence.

Standalone record windows explicitly use AppKit's fullScreenPrimary role through a small window
attachment, compatible with the macOS 14 deployment target. The notch NSPanel is excluded. Native
Token-window enter/exit has been checked on the current macOS; the balance-window full-screen path,
repeated cycles and older macOS runtime behavior remain to be verified.

The Waterline footer menu and menu-bar menu open one native Balance history window. Opening it from the island closes the island. Choose an account and 7/30/90 days; values come from the engine journal, including after relaunch. Accounts retain region labels and unnamed duplicates have stable local ordinals. Separate currencies and available/posted-credit series; no cross-currency total or inferred spend. Empty or failed history stays explicit. Charts show the selected interval and raw tables the latest 100 observations. Token-derived API reference valuation is implemented in the separate Token records window. Long-term quota-window history remains unimplemented.

Long-history charts draw a first/minimum/maximum/last envelope for each horizontal pixel (up to 4 samples per pixel), leaving persisted records and the raw observation list unchanged. Gap markers are computed before sampling, so an omitted gap never becomes a connecting line. Currency and posted/available-balance series remain separate in both the detail and history views.

History storage retry is shared between Settings and the history window, shows progress and disables duplicate retries. Successful recovery clears the history-specific error. An unreadable/incompatible journal displays History unavailable rather than No balance history; the original journal is preserved and the reason is distinguished from disk-access failure.

## Local Token records

The footer/menu-bar Token records action opens a native window and closes the island. Import Codex log uses the system file chooser for one file. Show progress and Cancel, then added-record count or a scoped error; Retry repeats the failed load/import rather than merely dismissing its message. Closing the window cancels its pending import. View 7/30/90/all records and the latest 100 details. Input includes cache; cached input is explicitly labelled as a subset. Data is not attached to a provider account or presented as an actual bill. Eligible records may show the separately labelled reference API value described below. Source selection is manual; no background log scan is enabled.

The Token window now shows a dated Standard API reference for eligible exact-model GPT-6 Astra and GPT-5.6 Sol/Terra/Luna records, with source link, currency, and priced/total record count. Partial matches are labelled as the priced portion; no matched price yields an em dash, not zero. Account assignment and actual billing remain absent. See token-reference-pricing.md.

A collapsed island cannot become the key window. User-initiated history/settings window actions activate the app so ordinary controls and system file dialogs receive keyboard input; hover alone does not activate it. Token import accepts a selected item because JSONL may lack a system type declaration, then applies regular-file, size, syntax and provenance validation before import.

### Daily account selection (2026-09-07)

The idle island shows the selected provider logo on the left and remaining quota percentage
on the right (reported balances retain their currency). It reserves the camera housing plus 68 pt on each side (136 pt floating).
Hover does not enlarge the island; clicking opens the overview. Leaving
for 350 ms closes either state; menu tracking defers closure until the menu ends.
Pin selects one daily account, persisted as ordered `notchAccountIDs`; it does
not keep the panel expanded. Automatic chooses one enabled account. The idle header uses each selected account's shortest available primary usage window. Removing an
account prunes the selection; an empty explicit selection stays empty until the user chooses an account or Automatic.

The daily headline keeps its shortest primary cadence at reset boundaries: when that
window has expired, show Awaiting update until a fresh response arrives, rather than
switching the unlabelled percentage to a weekly or additional-model window.

An explicitly selected daily account stays first in the complete scrollable overview. Its paused state remains visible
so it can be managed. Other rows keep their interaction-frozen order. With existing
accounts but no daily selection, the compact control says Choose an account rather than
claiming that accounts need connecting.

## Owner ordering controls — 2026-09-08

Settings → Accounts → Account display order uses native drag-and-drop rows, with
accessibility move actions. Dropping saves the complete account order. There is no
automatic sorting control: overview positions do not change with health, usage or
daily selection. Without a saved order, configuration order is used. New accounts
append and removed accounts are pruned. All accounts remain visible, including paused
accounts. Monochrome provider marks use template rendering for light/dark contrast.

Quota details retain provider/model groups. Each group starts its own grid row and
sorts known cadence from shortest to longest, independently of utilization or freshness.
Thus paired 5h/7d windows stay left/right; a one-window group cannot shift the next
group's 5h window into the right column. Unknown cadences remain after known ones.

## Saved-key access recovery — 2026-09-08

A manual API account with keychainLocked offers Connect to authorize reading its
existing saved key, not Update key. The action calls the same account-specific
manual reconnect used by Settings and shows Connecting while that operation runs.
Missing/rejected manual credentials still direct users to key management.

Account ordering also exposes named accessibility move actions on grouped rows.
With the list focused and an account selected, Option-Up/Down uses the same saved
manual order; ordinary arrow keys remain available for selection navigation.

An empty account list with no source failure shows no green health indicator.
Source failures retain the warning indicator and active refresh retains progress.

## Owner simplification — 2026-09-08

This replaces earlier refresh/threshold/notification/hook settings requirements.
Settings has General, Accounts and Privacy only. Account rows never show credential
paths or observation times, including in a diagnostic disclosure. Actionable errors
and connection progress remain visible. No refresh interval or quota/balance alert
threshold form, usage-notification switch, or Claude-session-activity switch remains.
Refresh is automatic at 60 seconds, subject to provider backoff and authentication.
Only a failed upgrade cleanup may show a temporary Retry cleanup action; there is
no session listener or activity banner. The quota/balance data and reset boundaries
remain the core UI. Existing manual refresh remains an explicit retry affordance.

## Native subscriptions only — 2026-09-08

The owner removed API-account functionality from the current product pending future
work. Overview, Settings, ordering, source controls, connection guide, privacy destinations
and normal CLI account views show only Claude Code, ChatGPT, Grok, Cursor and Antigravity.
Multiple accounts of these supported providers remain allowed. Manual-key add/update,
API-source toggles, Qwen placeholder and API balance-history menu/window are absent.
Native token records remain separate. API metadata/history/keys are retained locally,
not erased or re-enabled, and no API adapter is registered for background fetching.

## Menu-only preferences (2026-09-08 owner revision)

The menu header is Waterline without a version suffix. Launch at login and language
selection live directly in the menu bar menu; there is no Settings scene. Account
connection and ordering remain an on-demand utility window, including the first-launch
connection guide. Permanent provider links and the notch settings gear are removed.
This supersedes earlier separate General/Accounts/Privacy settings tabs. Release build 11d3c6e1 was installed and the five-account panel, connection utility,
and order sheet were inspected natively. Menu language and login-toggle runtime
validation remain pending.

When there is no explicit notch selection, choose the first enabled account in
the saved display order (or stored account order when unset). Quota changes never
reorder this fallback selection. Explicit single-account selection still wins.

The collapsed headline uses explicit reset and freshness-boundary updates instead
of a one-second periodic timeline. New snapshots and language selection still
invalidate it immediately. The expanded panel retains countdown updates. CPU
acceptance must be remeasured on the installed Release; this change is not proof
that the previous 1.57% mean CPU failure is resolved.

Owner revision: rate limits retry silently in the background. Do not display
rate-limit explanations, retry timestamps or countdowns in quota cards, including
partial rate limits. Retain the existing per-metric earlier-reading marker and
show actionable authentication failures. Backoff and data freshness remain enforced.

Owner revision: remove Token records from the native app, including its menu
entries, import window and retired UI verification route. Existing stored records
and the independent kit/CLI data facilities are preserved; this feature is deferred.

Owner revision: remove account action menus (reconnect, pause, rename, remove)
from both the quota cards and connection utility. Retain ordering, daily account
selection, and conditional connection recovery when authentication is unavailable.

The overview supports native drag-and-drop directly on account cards. Dropping
one card on another moves it to that position in row-major display order and
saves through the existing engine account-order command. Only payloads from this
view session are accepted. The target has a provider-colored outline; dragging
does not dismiss the island while a mouse button is held. Native verification
of this interaction is pending; unit ordering tests do not prove pointer behavior.

First-launch connection revision: the visible connection guide automatically
connects the five registered native providers once loaded, skipping already
connected or explicitly disabled sources. There is no connect-selected button
or provider selection step. Required OS authorization remains user-confirmed.
The guide does not rerun on ordinary subsequent launches; conditional recovery
remains available. This supersedes the earlier first-use connect button.

The owner subsequently removed the entire connection guide. First launch runs
one automatic connection attempt for each enabled native provider directly from
the app lifecycle, without a guide window. Persist the attempt before starting
so denial or interruption does not cause prompts on every launch. Existing guide
flags migrate as an already-attempted installation. Only OS authorization and
conditional account recovery remain visible.

Owner revision: omit the entire overview heading row (Overview, account count,
Manage accounts). Put Account display order in the island footer Waterline menu,
opening the existing native ordering utility directly. Card drag-and-drop remains.

Owner revision: remove launch-at-login entirely, including its menu item. On
upgrade unregister only Waterline's own existing SMAppService.mainApp registration.
Do not leave a hidden enabled login item; report an actual cleanup failure.
