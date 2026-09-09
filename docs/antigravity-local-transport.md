# Antigravity local transport implementation boundary

Status: implementation in progress, not registered support. The quota-only live HTTPS probe
is recorded in `build/verification/antigravity-structured-live.json`; the official CLI TUI
comparison is in `antigravity-cli-usage-live.json`.

## Account and process ownership

Use a dedicated local-service dependency, not the ordinary remote provider HTTP client.
Keep the latter's HTTPS/443/redirect/allowlisted-host behavior unchanged. Local requests
may target only a loopback listener owned by a verified same-user Antigravity CLI process.
Match executable identity and process start time as well as PID; do not use a port number,
process name substring or another monitoring app's token store as account identity.
Revalidate ownership before and after a request, discarding responses if the process or
socket owner changed. Never enumerate or log command-line arguments containing CSRF tokens.

Discovery must establish the actual signed-in account through the local identity endpoint.
Quota buckets belong to that account, not the CLI PID or working directory. Restarting a
CLI must not create a new account or discard its preferences/history. An identity change
must never overwrite the former account's reading.

## TLS and requests

The observed CLI listener uses a self-signed certificate with localhost/127.0.0.1 SANs.
A narrowly scoped connection may trust that exact certificate only after process/socket
ownership is established, while still checking hostname, validity and signature. No global
trust changes, arbitrary loopback trust, blanket certificate-acceptance delegate, redirects,
proxy inheritance, cookies, remote OAuth tokens or external credential reads are permitted.
Re-check identity after response delivery; a publicly bundled certificate alone does not
prove ownership. Do not reuse a session for a newly owned socket or changed process.

Only fixed reviewed status/identity paths may be called. RetrieveUserQuotaSummary uses
POST with `forceRefresh: true`, Content-Type application/json and Connect-Protocol-Version 1.
The observed CLI path needed no CSRF; this does not apply to IDE language-server endpoints.
Bound request time and response size, disable caching, preserve server failures and retry
limits, and never fall back to an inference request to test quota availability.

## Lifecycle and UI

Source opt-in is explicit. First implement reading an already-running verified CLI. When
it is closed or signed out, show an actionable connection reason and retain previous data
with its original age. Do not claim automatic background availability without a managed
session lifecycle. A future user-initiated managed session needs bounded startup, explicit
process ownership, no automatic browser/login prompts, and deterministic stop/cancel cleanup.
Do not silently launch a provider CLI during ordinary background refresh.

## Verification still required

- Positive and negative process identity, UID, PID reuse, listener replacement and expiry cases.
- Exact-certificate trust with hostname/signature/expiry rejection; redirects and proxy isolation.
- Account identity mapping across restart, logout and account change.
- Partial quota decoding, duplicate bucket IDs, missing fractions and future cadence values.
- Refresh scheduling, cancellation, account disable/removal and app-exit cleanup.
- Native connect -> progress -> real quota -> close/reopen/reconnect, compared with CLI usage.

A pure parser or a successful standalone probe does not complete these flows.

Implementation checkpoint: `Host/LocalProcessIdentity.swift` now reads UID, executable
path and process start seconds/microseconds through libproc, without command-line arguments.
Its revalidation rejects wrong executables, wrong UIDs and mismatched start times. Two
offline tests exercise only the test process and invalid PIDs. Socket ownership, TLS and
account transport remain to be wired; this helper alone grants no endpoint access.

Listener checkpoint: LocalServiceListener uses libproc file-descriptor/socket metadata
to identify same-user IPv4 127.0.0.1 TCP listeners. It retains process identity, descriptor,
port, socket generation and kernel socket identity. Tests bind only temporary test-owned
sockets and verify acceptance of loopback, rejection of wildcard listeners, mismatched
generation and a closed descriptor. No process arguments, external sockets, provider
requests or Keychain entries are read by the tests. TLS/account transport remains pending.

Native TLS checkpoint (2026-09-07): LocalTLSCertificate passes synthetic valid-date,
expired/not-yet-valid, invalid-DER and non-loopback-host tests. AntigravityLocalClient
uses an ephemeral proxy/cookie/cache-free URLSession, fixed read-only paths, a 1 MiB
body limit, timeout, redirect rejection and before/after listener checks. The full gate
passes 270 tests. It remains unregistered.

The compiled native live probe FAILED: Apple's SSL trust evaluation reports
ServerAuthEKU=false for the actual bundled CLI certificate. The equivalent Python
explicit-anchor probe succeeded; that does not prove native acceptance. Do not relax
SSL evaluation globally. A proposed narrowly process-bound no-EKU certificate profile
requires explicit exact-leaf/SAN/date/self-signature checks and native connection tests;
BasicX509 alone is not sufficient proof. The temporary CLI was exited normally.

One real Claude Code CLI consultation was attempted but returned a session-limit error,
not advice. Independent SDK review is recorded under the historical review checkpoint; the temporary consultation drafts have been removed.

Native compatibility verification (2026-09-08): the installed CLI passes the code
requirement `anchor apple generic and identifier "cli" and certificate leaf[subject.OU]
= "EQHXZ8M8AV"`. The client now checks that dynamic code identity in addition to UID,
path, start time and socket ownership. Normal SSL validation remains the first path.
Only the exact reviewed public DER certificate (fingerprint recorded in the fixture
README) may use the absent-EKU compatibility profile, within its fixed reviewed validity
interval. Its exact pin fixes the previously reviewed SAN and self-signature; altered or
renewed bytes do not inherit this exception. BasicX509 is not used as a generic fallback.
No system trust or ordinary remote-provider policy changes were made.

The compiled Swift client obtained four real quota windows with no parsing failures and
successfully queried GetUserStatus, returning a userStatus object with an email field.
Only field names/types were logged, not identity values. Evidence:
`build/verification/antigravity-swift-client-live.txt`, exit 0. The temporary CLI exited
normally. Tests cover explicit scope requirement, pin alteration, invalid hosts/dates and
rejection of an unsigned test process. Full gate: 271 tests. Account discovery/persistence,
provider registration and end-to-end native refresh are still pending.

Request-budget correction: native local requests now acquire the same engine-owned
four-slot request budget used by remote provider queries. The local transport still
validates its own fixed loopback endpoint; it does not send through the remote URL
allowlist client. Waiting operations honor cancellation before doing IO, and cancelled
service probes do not continue to alternate listeners. Mixed local/remote contention
and queued cancellation are covered by offline tests. Full gate: 282 tests.
