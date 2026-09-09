# Decisions

Append-only history. ARCHITECTURE.md describes the current target and implementation status.
Later rows explicitly supersede earlier decisions; an old row is not a current rule or evidence of implementation.

| Date | Decision | Why |
|---|---|---|
| 2026-09-06 | MIT licence | Same family as the tools we read (CodexBar) so forks can carry the project on; keeps every dependency option open |
| 2026-09-06 | Own `NSPanel` for the notch window | ~200 lines of AppKit we fully control; no third-party UI dependency to track across macOS releases |
| 2026-09-06 | In-process engine, no daemon, no local server | A menu-bar app is already always on; a daemon doubles Keychain authorisation, signing and installation for no gain |
| 2026-09-06 | `snapshot.json` + CLI as the integration surface | Anything on the machine can read a file; no protocol to version |
| 2026-09-06 | Three targets: `WaterlineKit`, `WaterlineCLI`, `WaterlineApp` | Adapters are folders inside the kit; a separate module adds boilerplate, not isolation. UI-free presentation logic lives in the kit so it is testable |
| 2026-09-06 | Credential is the primary key, not the vendor | One vendor can be zero, one or several accounts on a machine (Kimi Code subscription vs Moonshot top-up); gateway routes belong to no local account |
| 2026-09-06 | Adapters report only what the API returned and throw otherwise; the engine owns freshness | Never a fabricated number on screen; stale vs unavailable is an engine concept |
| 2026-09-06 | GitHub Issues + milestones as the agent work queue | Same place as the code and PRs; `Closes #n` closes the loop; `gh issue list --json` is the agent's API |
| 2026-09-06 | CodexBar, boring.notch, open-vibe-island are references, never sources | Clean MIT provenance; the last two are GPL |
| 2026-09-06 | Zero third-party dependencies before v1.0 | Cursor's SQLite is read with the system `SQLite3`; TOML/JSON needs are narrow enough for Foundation |
| 2026-09-06 | Pure SwiftPM, no `.xcodeproj`; `Scripts/bundle-app.sh` makes the `.app` | Text files agents can edit and diff; CI needs only `make verify` |
| 2026-09-06 | Toolchain pinned to stable Xcode 26.6 / Swift 6.3, macOS 14 minimum | Matches the `macos-26` CI runner; the beta Xcode on the owner's machine is not the reference |
| 2026-09-06 | Stable local account IDs, reconciled by verified provider/region/billing identity; supersedes credential-as-primary-key | Token rotation must preserve history/settings, and locked sources must be representable before a secret can be read. Ambiguous identities stay separate. |
| 2026-09-06 | Reported and deterministic metrics are allowed; estimates are distinct and labelled; refines report-only rule | Percentages/countdowns need transparent calculation. Optional missing fields and independent failures must not erase valid data or create defaults. |
| 2026-09-06 | Fresh windows first for the headline, otherwise balance health and stable order; supersedes raw-balance and estimated-days ranking | Different currencies are incomparable without conversion, and the ordinary display must work without enough history for a forecast. |
| 2026-09-06 | Noninteractive background Keychain reads are allowed; prompts require Connect | Preserves seamless operation where permission exists while preventing surprise background dialogs. No copying another tool's credential database. |
| 2026-09-06 | HTTPS and account-region selection with redirects rejected by default; raw capture is an explicit exception | A host list alone does not define credential routing. Raw diagnostics need restricted handling while routine snapshots and logs remain secret-free. |
| 2026-09-06 | Account/metric freshness uses observation time, independent failures and bounded scheduling | Old local data must not appear fresh; failures must not block unrelated accounts, erase last readings or bypass server backoff. |
| 2026-09-06 | One engine/writer owns shared state; CLI refresh reports busy while the app runs | Prevents competing schedules and stale overwrites without adding IPC. Snapshot reads remain available. |
| 2026-09-06 | Snapshot schema is versioned before model evolution; supersedes the claim that a file needs no protocol version | Local consumers still need compatibility, and identity changes must preserve legacy records without guessed merges. |
| 2026-09-06 | Prefer system libraries, allow justified reviewed dependencies; supersedes zero dependencies before v1.0 | Evaluate concrete maintenance, licence and implementation cost instead of a version-based ban. No dependency is added by this decision. |
| 2026-09-06 | Direct owner requests may define local work; proportional tests and routine decisions replace automatic stops | Repository workflow supports the task; it should not require remote activity for a local review or new tests for a prose-only change. |
| 2026-09-06 | History stores unchanged observations; estimates need a 24-hour span within 7 days and reset on balance increases | Flat periods matter to net-decrease estimates. These are labelled heuristics and cannot measure hidden offsetting charges and deposits. |
| 2026-09-06 | Provider status separates planned, implemented and live verified; negative capability claims need evidence | Candidate notes and frozen fixtures do not establish current endpoint support. Preserve release gaps instead of fabricating verification. |
| 2026-09-06 | Reference Xcode 26.6 / Swift 6.3.x, explicit environment for direct commands; refines the toolchain pin claim | Local check found Xcode 26.6 (17F113), Swift 6.3.3. Make defaults a path; that does not pin every shell command or verify the remote installation. |
| 2026-09-06 | User-flow completion requires frontend, local engine, persistence and recovery together | Owner emphasised a complete frontend/backend loop; isolated views and successful backend tests cannot establish a usable product. |
| 2026-09-06 | Bounded Claude Code consultations, optional Antigravity comparison and Figma design work are authorised development aids | Owner requested cross-tool help for uncertain decisions while conserving quota. Use minimal context, inspect available limits, verify advice locally and investigate before declaring a blocker. |
| 2026-09-06 | Claude Code is the only external AI assistant for backend work; Antigravity is frontend-only | Owner clarified the tool boundary for research and problem solving. Frontend comparison remains optional and quota-conscious. |
| 2026-09-06 | A problem closes only after its correction and affected workflow are verified | Owner requires actual resolution of every problem. Advice, error suppression, mock results, disabled features and weakened acceptance cannot substitute for a demonstrated fix. |
| 2026-09-06 | Grok through Cursor CLI joins Claude Code as an authorised backend/frontend consultant; supersedes the Claude-only restriction | Owner explicitly added Cursor-hosted Grok. Select its verified model ID, conserve quota and validate advice; Antigravity remains frontend-only. |
| 2026-09-06 | Grok Bot is also an authorised consultant after its actual entry point is identified | Owner added Grok Bot separately from Cursor-hosted Grok. Do not conflate it with a similarly named local client; preserve quota controls and independent verification of advice. |
| 2026-09-06 | Correction: "Grok Bot" refers to Grok quota within Cursor; supersedes the preceding separate-Bot interpretation | Owner clarified that no additional bot or standalone Grok Build tool was intended. Use Cursor-hosted Grok and verify its reported allowance and applicable billing; a model listing is not quota evidence. |
| 2026-09-06 | Engine request generations and cancellation guard acceptance; ordinary overlapping refreshes share work | A reproduced late response overwrote newer usage. Superseding work gets a new generation; cancellation alone cannot prevent a cancellation-ignoring adapter from returning. |
| 2026-09-06 | Snapshot schema 1 carries source/storage diagnostics; notify subscribers even when persistence throws | Discovery failure must stay visible without hiding healthy sources; disk failure must preserve in-memory readings. Legacy bytes are backed up, and newer schemas are never overwritten. |
| 2026-09-06 | Advisory OS descriptor lock held by the engine until stop or destruction | Prevent simultaneous engine writers without IPC; read-only snapshot consumers remain independent. |
| 2026-09-06 | Adopt the owner's Agent Island visual reference, with Waterline-specific multi-account overview, all-account filtering and in-island details | The reference's fixed two-provider arrangement cannot scale to the requested provider set. Hover previews, header click pins, and account actions show details without collapsing the panel. |
| 2026-09-07 | Store account configuration and current preferences together in versioned configuration.json; supersedes UserDefaults for these business settings | Engine ownership and save-before-apply semantics make enablement, removal exclusions and settings recover together; CLI and app use the same writer lock. Preferences are projected into snapshot schema 2 for consumers. |
| 2026-09-07 | Preserve removed stable identities as local rediscovery exclusions until explicit Connect | Automatic discovery must not undo removal. Reconnecting a recognised identity reuses its local ID without touching external credentials. |
| 2026-09-07 | Keep operation progress separate from cached reading and save last refresh attempt independently | Pinning, renaming or publishing state must not make old usage appear newly fetched. |
| 2026-09-07 | Window definitions remain per-account, not per-provider or inferred from a plan name | Owner highlighted Plus 5-hour limits and different tiers of the same agent. Parse and display the reported duration for each account; test distinct plan/window combinations without inventing missing limits. |
| 2026-09-07 | One shared island silhouette replaces independent header/body backgrounds | The owner identified the visible capsule-to-rectangle seam as poor design. A shared contour removes the seam and uses curved shoulders when the content is wider than the header. |
| 2026-09-07 | Combine per-query LAContext with serialized legacy Keychain interaction policy, restoring the prior value | Native sampling showed LAContext-only reads blocking in SecItemCopyMatching_osx / SecKeychainItemCopyContent. The same noninteractive query returned keychainLocked in 0.2 seconds with legacy UI explicitly disabled. Deprecated legacy calls are retained deliberately; no warning suppression or credential-copy workaround. |
| 2026-09-07 | Snapshot schema 3 gives components stable IDs, their own observation timestamps and explicit errors; partial is a distinct account state | A new successful component must not re-date or erase a failed older component. Optional omission alone never restores an old value. |
| 2026-09-07 | CLI command execution is injectable and failed requested refreshes return exit code 2 while retaining valid output | Scripts need accurate failure status, and entry-point tests must run without network or real Keychain access. |
| 2026-09-07 | HTTP client owns and invalidates its ephemeral session on release | Prevent repeatedly created provider clients from leaving session resources alive after requests finish. |
| 2026-09-07 | Component retention matches exact IDs or declared parent scopes, never arbitrary string prefixes | Provider/model identifiers may share prefixes without belonging to the same group. Preserve the intended group without reviving unrelated observations. |
| 2026-09-07 | Connect refreshes only its selected provider | An explicit single-provider recovery action should not trigger unrelated account requests. |
| 2026-09-07 | Manual-key creation commits metadata before writing the app-owned secret; failed writes leave a recoverable row | A config failure must create no orphan secret. A Keychain failure is explicit and can be retried via Update key without inventing success. |
| 2026-09-07 | Manual removal keeps a cleanup marker until own-key deletion succeeds; retries on startup and in Privacy settings | Keychain failures must not silently leave credentials behind. External credentials remain read-only. Snapshot schema 4 exposes pending cleanup. |
| 2026-09-07 | CLI manual keys require bounded piped stdin; native entry uses SecureField | Prevent key arguments, terminal echo and oversized input. Account identity survives replacement, and multiple manual accounts never merge merely because both use a manual source. |
| 2026-09-07 | Engine-owned JSONL balance history with per-observation deduplication; queries expose only the requested account's recent records | UI delivery speed cannot determine which observations are stored. Unchanged values at different times matter to depletion estimates. |
| 2026-09-07 | History uses fractional Unix-second timestamps, separate from ISO-8601 snapshot presentation | Preserve distinct subsecond observations through journal restart without re-dating them. |
| 2026-09-07 | History persistence failure leaves current readings usable, queues writes in memory and produces a nonzero CLI status | A failed history write is not a failed provider query, but must not appear as a fully successful operation. |
| 2026-09-07 | Persist an explicit region for regional manual accounts; key replacement cannot change it | Moonshot documents independent CN/international keys and CNY/USD endpoint units. Region validation precedes storage and requests; no cross-region retry is permitted. |
| 2026-09-07 | A temporarily unreadable known source retains its last verified identity without using an old secret | Losing identity metadata during a Keychain lock created duplicates on recovery. Manual accounts are excluded from source-only matching because their own IDs distinguish entries. |
| 2026-09-07 | Persist usage-request scheduling in snapshot schema 5; toggling enablement cannot reset Retry-After | Restart and enable/disable loops were demonstrated to bypass server deadlines and authentication parking. |
| 2026-09-07 | Store a private full credential revision digest solely for change detection | Re-reading an unchanged credential must not unpark 401 requests; real rotation should recover without resetting account identity/history. Digest is not exported as a label or snapshot field. |
| 2026-09-07 | Sleep suspends work without releasing the engine writer lock; wake/network recovery uses the same eligibility rules | Avoid competing writers or late results during suspension, and prevent a burst of catch-up requests. Incomplete startup discovery is resumed explicitly. |
| 2026-09-07 | Manual replacement records its credential revision before querying the replacement key | Otherwise a rejected new key could look like another credential change after restart and bypass authentication parking. |
| 2026-09-07 | Preserve Kimi Code quota counts and derive fractions only with a positive denominator | Subscription/API quota units are not Moonshot balances or inferred token counts. Membership labels never select a hard-coded allowance table. |
| 2026-09-07 | History persistence retry is independent of Provider refresh | Authentication parking and Retry-After must not prevent already accepted observations from being saved after storage recovers. |
| 2026-09-07 | Explicit history retry can recover only an incomplete final line after backing up the original bytes | Interrupted appends should not hide all earlier valid history, but complete unknown schemas and interior corruption must never be silently discarded. |
| 2026-09-07 | xAI is a Management Key/Team ID posted-ledger surface, distinct from live available credit and consumer Grok | A signed USD-cent ledger value must not silently become an available-credit health signal or depletion forecast. Snapshot schema 6 and history carry the balance basis. |
| 2026-09-07 | Expanded island shoulders use monotonic curves with vertical end tangents | Avoid a pinched or upward-folding lip where multi-account content widens below the header; one shared silhouette remains responsible for the whole surface. |
| 2026-09-07 | ServiceManagement is authoritative for launch at login; register only from the explicit settings action | A persisted app Boolean cannot prove OS registration or approval. Read actual status after changes and on return from System Settings; never auto-enable at startup. |
| 2026-09-07 | Keep one hosting view per notch panel and update observable layout | The prior render method reconstructed the host and calculated dimensions only on panel events. Account-count changes now resize the same host without intentionally resetting detail/filter state. |
| 2026-09-07 | Compute expanded frames in NotchGeometry from the selected display | NSPanel.screen can still refer to the prior display while moving. Using it mixed coordinate systems and could produce an off-screen or negative-height panel on vertically arranged displays. |
| 2026-09-07 | Cursor uses an injected system-SQLite reader and independent quota/cap windows | Read one token without copying or mutating the tool database. Auto/API percentages are never averaged; on-demand spend is not prepaid balance, and Grok Bot is not a universal Grok model allowance. |
| 2026-09-07 | Separate Cursor reported quota percentages from monetary usage when both are returned | One live Pro response reported different total quota and USD used/limit ratios. Combining them in one metric implied a false denominator. |
| 2026-09-07 | Partial results respect the longest component Retry-After without authentication-parking successful metrics | A valid main response previously cleared optional-endpoint rate limits. The whole-account scheduler now conservatively defers the next request while preserving valid readings. |
| 2026-09-07 | SQLite prepare BUSY/LOCKED is a recoverable read failure | An exclusive Cursor database transaction reproduced the prior schema-change misclassification. Keep the bounded wait and retry path without copying or changing the database. |
| 2026-09-07 | Qwen capability status is scoped to the intended credential, not the vendor name | Primary docs distinguish retired OAuth, inference/plan keys and cloud billing AccessKey/RAM. A cloud account balance API is not evidence that a Coding Plan key can query its remaining quota. |
| 2026-09-07 | Overview favors usable quota fractions; multi-account cards stack their metrics | Monetary notes must not hide constrained quota pools or mute complete accounts. Used-only amounts remain visible, and nested grids no longer compress four meters across the island. |
| 2026-09-07 | The app owns a persisted notification ledger, separate from CLI usage refresh | Kit logic detects fresh metric crossings; system permission remains native. Persist attempts before submission to prevent crash/restart replay, with errors exposed and no guarantee of OS banner delivery. |
| 2026-09-07 | Package native localization catalogs in the main app bundle before signing | SwiftUI literal keys resolve through the app bundle. Shipping source catalogs without bundling them would leave installed builds untranslated; plist lint and packaged-byte checks supplement native language selection evidence. |
| 2026-09-07 | Language selection uses the per-app standard AppleLanguages preference at next launch | Native bundle localization is cached. Avoid mixed live-switch behavior and duplicate engine/native authority; the native probe also established that own-bundle suite initialization must use standard defaults. |
| 2026-09-07 | Development DMGs are explicitly named and kept separate from distribution acceptance | Image/signature integrity can be verified locally, but ad-hoc signing and a machine with Gatekeeper policy overrides cannot prove notarized clean-install behavior. |
| 2026-09-07 | Compare local Codex/Cursor login revisions before reconciling background discoveries | Long-lived sessions otherwise retained startup credentials. A five-minute local check restores rotated logins without interrupting unchanged in-flight work, reviving logged-out sources repeatedly or bypassing server deadlines. |
| 2026-09-07 | Bound HTTP concurrency once per engine, including discovery | Per-call task groups did not cap overlapping provider operations. One cancellation-aware queue limits the actual requests while retaining host-scoped clients. |
| 2026-09-07 | Compile the four-account fixture harness as a separately identified application | Prevent synthetic readings, state and credentials from mixing with the user's account data. Snapshot schema 7 records verification provenance; normal app arguments cannot activate the fixture dependencies. |
| 2026-09-07 | Freeze account ordering for pointer interaction and the panel's key-window lifetime | Keep keyboard descendants and menu targets stable while allowing values to refresh. Identity additions append, removals disappear, and priority sorting resumes when interaction ends. |
| 2026-09-07 | Keep development integrity checks separate from distribution trust checks | An ad-hoc image or locally overridden Gatekeeper acceptance cannot prove release readiness. Explicit identity signing enables runtime/timestamp options; a read-only distribution gate rejects missing prerequisites. |
| 2026-09-07 | Persist authentication parking separately from temporary source-read failures | A disappearing and returning file must not revive the same rejected credential. Scoped file recovery preserves the auth failure until an actual credential change or explicit reconnect. |

| 2026-09-07 | Provider identity colours in healthy meters, adapter-derived region labels, and explicit footer collapse/quit menu | Owner found the monochrome UI and exit discoverability inadequate; retain health-colour priority and original currency evidence. New geometry remains unverified. |

| 2026-09-07 | Replace the shoulder connector with a single full-width expanded silhouette | Owner rejected capsule/panel and wide-shoulder joins. Attach the top edge directly on notched displays; preserve rounded floating mode and camera clearance. Expanded header hit area follows the visible width. |

| 2026-09-07 | Opening does not implicitly pin the island | Owner reported persistent obstruction while working elsewhere. Mouse exit and loss of key status dismiss an unpinned panel; persistent display requires explicit footer pin. Preview hosts no longer open automatically. |

| 2026-09-07 | Expose retained balance observations in a native 7/30/90-day history window | Reuse engine-owned persisted records; preserve region, currency and balance basis. This is balance history, not token cost or billed spend, which require independent evidence. |

| 2026-09-07 | Pixel-envelope rendering for long balance histories | Preserve endpoints, extrema and pre-sampling gap boundaries; bound drawing complexity without discarding journal records or synthesizing continuity. |

| 2026-09-07 | Engine-owned, explicit local Token imports in a separate versioned ledger | Preserve source logs and existing samples, avoid duplicate totals, retain unknown account/pricing status, and prevent cancelled or obsolete operations from committing after writer ownership changes. |

| 2026-09-07 | Dated Standard API-equivalent valuation, separate from actual bills | Use exact supported model and verified log-field provenance; preserve raw counters and explicit partial coverage. Ledger v1 stays unpriced until reverified; v2 retains pricing eligibility. |

| 2026-09-07 | Restrict key status to expanded island; activate only explicit window actions | Native file-picker testing reproduced keyboard focus returning to the collapsed panel. The fixed scenario completed path entry/import/reimport/cancel/quit. JSONL selection uses content validation rather than an unreliable system type filter. |

| 2026-09-07 | Scope development restart to the current checkout's executable path | Name-wide termination could close an installed copy or another checkout. Wait for the selected process to exit before replacing its bundle; fail without rebuilding if it remains alive. |

| 2026-09-07 | Route hover dismissal and footer unpin through common collapse | Every dismissal clears the navigation request; explicit unpin also collapses immediately. Header and notification opens do not implicitly pin. |

| 2026-09-07 | Generate app-bundle ICNS from project-owned Waterline artwork before signing | Preserve generated-image provenance and all standard/Retina sizes without adding dependencies. The icon identifies the app bundle; menu-bar status remains a separate native control. |

| 2026-09-07 | Replace W-shaped icon with three parallel water-ripple lines | Owner requested simpler water纹 imagery; retain the first draft as provenance, use v2 in the current app bundle. |

| 2026-09-07 | Break balance estimates at same-currency posted-ledger observations | Filtering out posted values alone bridged incompatible periods and retained an old estimate after the reported basis changed. Require a fresh available-balance segment, while keeping simultaneous other currencies independent. |

| 2026-09-07 | Replace collapsed health dots with the selected agent's brand logo | Owner requested visible attribution of the displayed quota. Select value and account together, keep quota ties stable, and carry notification source identity. Bundle only pinned MIT-licensed static PNG assets from Lobe Icons 1.97.0 with provenance and license; no runtime dependency or network fetch. Review asset upgrades explicitly. |

| 2026-09-07 | Use symmetric 18pt header insets and remove the visible verification banner | Owner requested equal outer-edge spacing for logo/metric and removal of the orange explanation. Preserve fixture provenance internally and in evidence. |
| 2026-09-07 | Give record windows an explicit primary full-screen role | Secondary SwiftUI Window scenes default to associated windows. A narrow AppKit attachment supports the macOS 14 baseline and excludes the notch panel. Native Token enter/exit verified; broader full-screen matrix remains open. |

| 2026-09-07 | Daily notch pin selects up to two persisted accounts; idle logos, hover metrics, click overview replace sticky expanded pin. | Owner requested minimum daily footprint and explicit account selection. |

| 2026-09-07 | Explicit empty daily selection stays empty; only Automatic restores automatic selection. | Turning off the final account must not immediately turn it back on. |

| 2026-09-07 | Daily island shows one selected agent: logo left, remaining allowance right even while idle. Pin replaces the current selection. | Owner explicitly rejected the reference product’s two-agent daily layout. Legacy two-ID preferences display only the first ID until next selection. |

| 2026-09-07 | Hover does not enlarge the single-account island; click opens overview and leaving closes it. | Idle already shows the same metric, so hover enlargement adds no information. |

| 2026-09-07 | Adopt owner-selected logo A: two unequal offset cyan ripples. | Replaces three parallel waves after owner found a visually similar third-party mark. Source: design-previews/brand/waterline-logo-v3.png. |

| 2026-09-07 | Menu-bar and empty-island marks use native unequal double ripples matching logo A. | Replace the unrelated SF Symbols three-wave mark; template rendering adapts to menu-bar appearance. |

| 2026-09-07 | Daily selected-account headline retains shortest cadence through resets and waits for refreshed data. | A fresh weekly value must not silently replace the expired 5-hour value in the unlabelled compact percentage. |

| 2026-09-07 | Kimi Code manual accounts explicitly choose China or global endpoints; legacy nil region retains China. | Official current CLI source documents separate .com/.ai deployments; quota units are not regional currency balances. OAuth discovery remains separate unfinished work. |

| 2026-09-07 | Manual-account reconnect reads only the selected owned Keychain item and refreshes that account without rewriting its key. | Provider-wide reconnect could prompt for unrelated accounts; Settings previously exposed only key replacement for manual accounts. |

| 2026-09-07 | Production app checks for an older process with its bundle identifier before engine or panel startup; duplicate launches activate that instance and exit. | Native verification found duplicate UIs despite the snapshot writer lock. Verification builds retain their isolated launch behavior. |

| 2026-09-08 | Antigravity uses an opt-in signed local-service adapter with stable hashed account identity and no synthetic secret; config/snapshot advance to 2/10 with backups. | Complete local-provider engine flow while preserving remote credential boundaries and original account data. |

| 2026-09-08 | Dedicated local-service requests share the engine HTTP permit queue while retaining their own endpoint validation. | Local IPC must not bypass global concurrency or continue probing after cancellation. |

| 2026-09-08 | Owned-Keychain reads execute off the engine actor; lifecycle/generation checks reject late results. | Waiting for user authorization must not prevent engine state access or repopulate stopped operations. |

| 2026-09-08 | Generate Homebrew metadata only from a signed/stapled validated artifact, with actual architecture and SHA-256; no development cask is emitted. | Distribution metadata must match the installer and remain separate from publication/clean-install acceptance. |

| 2026-09-08 | Ship the CLI inside the app, sign it before the outer bundle, and expose it in generated Homebrew casks. | Installed users should not need a source checkout to access the second client; validator checks remain read-only for external artifacts. |

| 2026-09-08 | Add opted-in GLM personal-plan discovery from documented Claude settings; account source fallback includes region/team. Config/snapshot schemas advance to 3/11 with backups. | Domestic/international routes must not merge solely because they share a configuration file and token field. |

| 2026-09-08 | Development run refuses an already-running different Waterline bundle and verifies its own executable after launch. | The single-instance guard must not make an old installed build appear to be the freshly built checkout. |

| 2026-09-08 | Pin Sparkle 2.9.6 in the app target for signed native updates, ship its full license and embed/sign nested components. No feed/key is configured; missing release configuration keeps the updater uninitialized. | Reuse a maintained native installer instead of writing executable replacement logic; provider credentials never enter the updater. |

| 2026-09-08 | Optional Claude command hooks send only hashed session/kind/time over local distributed notifications. Native opt-in owns exact hook entries; disable stops reception before retryable cleanup. | Tool-session activity must not expose conversations, infer quota identity, or silently modify tool configuration at startup. |

| 2026-09-08 | Overview shows every configured account in two columns, including paused rows, with scrolling instead of a count cap. | The owner explicitly requested all accounts remain visible; prioritizing five integrations does not limit account visibility. |

| 2026-09-08 | Add an independent Grok/SuperGrok provider from the official CLI OIDC cache; keep xAI API billing and Cursor Grok Bot separate. Snapshot/config schemas advance to 12/4 with legacy backups. | The owner explicitly selected the independent consumer account among five priority integrations. |

| 2026-09-08 | Persist optional account display order separately from daily selection; sort detailed windows by cadence within independent model groups. Snapshot/config schemas advance to 13/5. | Owner requested configurable account positions and consistent 5h-left/7d-right pairs without hiding accounts or changing credentials. |

| 2026-09-08 | Preserve the verified Claude Code, ChatGPT, independent Grok, Cursor and Antigravity connection configuration while continuing other work. | The owner asked that these five stop being repeatedly reconfigured once working; display order remains independently user-controlled. |

| 2026-09-08 | Replace account-order arrow buttons with native drag-and-drop; remove automatic overview sorting and use configuration order when no explicit order exists. Render monochrome provider marks as adaptive templates. | Owner requested direct manipulation, stable account positions and visible icons in light settings. |

| 2026-09-08 | Remove Settings diagnostics, interval/threshold controls, usage notifications and Claude activity. Use automatic 60-second checks; retire owned hooks with retryable cleanup. | Owner explicitly rejected these extra features and the 300-second interval; preserve actual account data, identity, order and provider backoff. |

| 2026-09-08 | Follow the opted-in OpenCode DeepSeek credential instead of requiring a second key entry. Preserve one unambiguous existing account and retain its old owned key. | Owner prefers using credentials already saved by agents; automatic deletion of the old key was not authorized. |

| 2026-09-08 | Offer only the five native subscription providers; remove API-account UI and default adapters while retaining local records, keys and history. | Owner explicitly requested removing all API-related functionality for now and revisiting it later. This supersedes earlier API rollout requirements. |

| 2026-09-08 | Apply rate-limit fallback to manual refresh too, persisting the effective retry deadline; zero or missing Retry-After cannot bypass it. Partial rate limits wait at least 60 seconds. | Observed Claude rate limiting with Retry-After zero exposed immediate manual retries. Transport failures retain immediate manual retry; valid cached usage remains visible. |

| 2026-09-08 | Put launch-at-login and language controls directly in the menu; replace Settings tabs with an on-demand connection/order utility. Remove notch gear and provider links; show only Waterline in the menu header. | Owner requested eliminating the separate settings page and rarely used chrome while retaining necessary connection recovery. |

| 2026-09-08 | Preserve the failure count for consecutive partial rate limits; back off from 60 seconds to 30 minutes even when independent metrics succeed. | A successful quota component must not reset retry pressure on a persistently limited metadata component. Complete success resets the count. |

| 2026-09-08 | Remove Token records UI and its verification-only view route; preserve stored records. | Owner explicitly rejected the feature as not useful in the current app. Earlier Token window acceptance is superseded, not marked passed. |

| 2026-09-09 | Publish 0.1.0 as an explicitly unnotarized, ad-hoc-signed Release with manual updates and normal macOS Privacy & Security approval instructions. Keep the formal notarization gate separately. | Owner explicitly accepted this distribution model; lack of Developer ID no longer blocks this first Release. No trust-policy bypass is performed or claimed. |

| 2026-09-09 | Remove launch-at-login and unregister any prior Waterline-owned login item on upgrade. | Owner explicitly rejected this feature after testing it; removing the control must not leave automatic startup enabled. |

| 2026-09-09 | Consolidate 56 ignored design-preview files into a verified local ZIP and remove the loose draft directory. | Owner requested project refinement. Earlier design-previews references resolve inside build/archive/design-previews-2026-09-09.zip; this is not a release asset. |

| 2026-09-09 | Remove obsolete build caches, preview bundles, development DMGs, draft archives and duplicate historical documents. Retain current artifacts, selected evidence and account-state backups. | Owner explicitly requested removing all unnecessary files. Historical tracked content remains recoverable through Git. |

| 2026-09-09 | Honor explicit end-to-end merge/release authorization without requiring the owner to click merge personally. Preserve exact-head CI checks, platform review and data-protection boundaries. | Owner explicitly authorized PR #26 merge and requested removing redundant AGENTS.md permission restrictions after automatic review rejected the old owner-only rule. |
