# Qwen / Alibaba Bailian

Capability review: 2026-09-08. No suitable quota/balance query contract has been verified for the
intended DashScope or Coding Plan API-key credentials. The provider is not registered. This is a
scoped finding, not a claim that Alibaba Cloud has no billing APIs. Last live verified: —.

## Distinct products and credentials

| Surface | Current evidence | Waterline conclusion |
|---|---|---|
| Qwen Code OAuth | The official authentication guide says the free OAuth tier ended on 2026-04-15. Cached legacy tokens are not a current supported setup. | Do not display a historical daily allowance or refresh a retired OAuth token to manufacture support. |
| Model Studio standard API key | General model inference and its trial/paid usage are distinct from Coding Plan. | An inference key does not establish permission for Alibaba Cloud account billing APIs. RPM/TPM is not remaining subscription quota. |
| Coding Plan | Dedicated key and regional coding endpoint; usage is shown in its console. | No verified query path/response for remaining quota with this key was established in this review. Never call inference to test allowance. |
| Token Plan | Official overview describes a separate credits subscription, dedicated key/base URL and seat/usage management. | Do not apply Coding Plan periods or denominators. A query/auth/response contract still needs verification. |
| Alibaba Cloud Expenses and Costs | `QueryAccountBalance` exists; official API overview requires cloud AccessKey/RAM permissions. | Cloud account balance is a separate identity/credential/metric scope, not a substitute for a Coding Plan quota or model balance. |

## Credential discovery boundary

Tier-2 discovery remains off by default and unimplemented here. Earlier planning suggested
`DASHSCOPE_API_KEY` and `~/.bailian/config.json` without a verified file schema; the latter must not be
scanned as an established source on that basis.

The current Qwen Code guide documents `~/.qwen/settings.json`, `modelProviders`, `env`, selected auth
and model configuration; it also documents `BAILIAN_CODING_PLAN_API_KEY` with a dedicated regional
base URL. Qwen Code can use third-party and custom providers, so its presence alone is not a Qwen
billing identity. Future opt-in discovery must attribute the selected configuration to the actual
provider/region and never send a key to an arbitrary custom base URL.

## UI and network behaviour

Until a supported contract is established, no query adapter or host allowlist is registered and no
credentials are requested for this capability. Future opt-in discovery can list a known source with
`Quota lookup unavailable` and its documented console action, without a numeric metric, progress bar,
refresh promise or inferred plan limit. That discovery/UI flow remains unfinished; documentation
review alone does not implement it.

Do not collect a cloud AccessKey merely to make this API-key-only quota feature appear supported.
A cloud billing integration requires its own explicit identity, least-privilege credential contract,
regional endpoint, signature implementation, mapped units and acceptance evidence.

## Primary evidence inspected

- [Qwen Code authentication](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/):
  discontinued OAuth and distinct ModelStudio/third-party/custom provider configuration.
- [Official repository authentication guide](https://github.com/QwenLM/qwen-code/blob/main/docs/users/configuration/auth.md):
  current settings path, dedicated Coding Plan key and region selection. Moving documentation;
  checked 2026-09-07, not a pinned implementation schema.
- [Coding Plan FAQ](https://www.alibabacloud.com/help/en/model-studio/coding-plan-faq):
  separation from general API billing, plan-specific key/base URL and console usage.
- [Token Plan overview](https://www.alibabacloud.com/help/en/model-studio/token-plan-overview):
  a separate credits product; not evidence of a key-compatible quota query endpoint.
- [QueryAccountBalance](https://www.alibabacloud.com/help/en/user-center/developer-reference/api-bssopenapi-2017-12-14-queryaccountbalance)
  and [Expenses and Costs API overview](https://www.alibabacloud.com/help/en/user-center/developer-reference/api-bssopenapi-2017-12-14-overview):
  real cloud-account balance API and AccessKey/RAM authentication boundary.

Searches for Coding Plan quota queries, Qwen Code usage endpoints and Alibaba account balances did
not establish a suitable current contract for the intended keys. This bounded review does not exclude
undocumented console APIs or future vendor changes. Re-review on new endpoint/schema evidence;
legacy quota amounts and unverified config paths must not become implementation defaults.

Settings availability follow-up (2026-09-08): the Sources list now explicitly labels
Qwen/Bailian quota lookup as not yet supported. It does not request a key, create an
account or display numeric data. Config discovery and a usable quota-query contract
remain unimplemented; this label is not an integration claim. Native visual verification
of the new row remains pending macOS unlock.

## Console-query implementation evidence — 2026-09-08

Reviewed CodexBar commit `ca3ad7851e936f7d125958252af141c8b9996e0f`:
[regional routing](https://github.com/steipete/CodexBar/blob/ca3ad7851e936f7d125958252af141c8b9996e0f/app/Sources/CodexBarCore/Providers/Alibaba/AlibabaCodingPlanAPIRegion.swift),
[Coding Plan fetcher](https://github.com/steipete/CodexBar/blob/ca3ad7851e936f7d125958252af141c8b9996e0f/app/Sources/CodexBarCore/Providers/Alibaba/AlibabaCodingPlanUsageFetcher.swift),
and [Token Plan fetcher](https://github.com/steipete/CodexBar/blob/ca3ad7851e936f7d125958252af141c8b9996e0f/app/Sources/CodexBarCore/Providers/Alibaba/AlibabaTokenPlanUsageFetcher.swift).
This is community implementation evidence, not vendor documentation or Waterline live validation.

Coding Plan attempts POST `/data/api.json` on the selected console host with action
`zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2`, using either
API-key headers or a separate web-session flow. Its parser explicitly handles
API-key mode being unavailable. Candidate fields include `per5HourUsedQuota`,
`per5HourTotalQuota`, their reset timestamp, and weekly/billing-month equivalents.
This establishes a concrete candidate, not working authentication for either region.

Token Plan uses web cookies and separate personal usage/subscription/quota-config
gateway actions; it is not evidence of a subscription-key-only lookup.

Do not copy the reference's automatic international-to-China credential retry,
endpoint overrides, broad payload logging or fallback quota inference. Waterline
requires explicit regional identity, fixed authorized destinations and actual metrics.
No browser cookie store or user Qwen credential was read for this review. Next proof
needed: a permitted regional authentication method and a redacted real response tied
to the intended account/plan. The adapter remains unregistered pending that evidence.
