# Grok / SuperGrok consumer subscription

Scope: independent Grok consumer account, not Cursor Grok Bot and not xAI developer
API billing. Initial integration targets the installed Grok Build 1.0.13 OIDC cache.

Source: `~/.grok/auth.json`, bounded to 1 MiB. Recognize the first-party namespace
`https://auth.x.ai::<client-id>` only when its issuer/client ID agree and its principal
is User. Other issuers are ignored; multiple first-party profiles currently report
ambiguity rather than choosing silently. The opaque local identity derives from the
user ID, not the token. Tokens remain in memory; Waterline does not rotate or overwrite
the CLI's credentials. An expired token requires renewal by the official client.

GET `https://cli-chat-proxy.grok.com/v1/billing?format=credits`, with Bearer token,
`X-XAI-Token-Auth: xai-grok-cli` and the same user's `x-userid`. Allowed host is exactly
`cli-chat-proxy.grok.com`. No custom base URL, browser-cookie fallback, purchases,
auto-topup or billing mutation is supported.

Map config.creditUsagePercent / 100 and currentPeriod's reported weekly/monthly type
and RFC3339 end timestamp. Unknown cadence/fraction stays unknown. For an explicitly
unified weekly/monthly window with valid start/end, omitted (not null) percentage uses
the official client's zero-value convention. Empty/legacy envelopes never default to
zero. Subscription tier is used only when reported; no plan or fixed allowance is
inferred from a login or model name. Paid balances and spending fields are not mapped
by this initial quota-only integration.

Primary implementation evidence, inspected 2026-09-08:
- Official repository commit `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`,
  `crates/codegen/xai-grok-shell/src/extensions/billing.rs`: consumer billing GET,
  headers, response and period types; tier is separately enriched from remote settings.
- Same commit, `crates/codegen/xai-grok-pager/src/app/effects/helpers.rs`,
  credit_balance_from_config: official percentage/zero convention.
- Installed CLI README: default proxy base is `https://cli-chat-proxy.grok.com/v1`.
- [Grok FAQ](https://docs.x.ai/grok/faq): shared subscription usage pool across Grok
  products, including Build; separate from developer API billing.

Live evidence: the user's official CLI displayed SuperGrok weekly usage and a reset
matching the direct successful billing response. The HTTP response supplied a unified
weekly period and omitted its zero percentage. This verifies the endpoint/source
scope; native Waterline discovery and refresh subsequently succeeded, and the Grok card was
reached in the complete scrolling overview. Its saved account also remained present
through the native account-order restart check. Other subscription tiers and expired
OAuth recovery are not yet live verified.
