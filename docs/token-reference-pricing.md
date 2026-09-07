# Dated API-equivalent reference

Implemented reference: `openai-gpt-6-astra-standard-2026-09-07`, USD, reviewed 2026-09-07.
This is a Standard API Token-only equivalent, not actual spend, subscription value guaranteed by a provider, or historical invoice pricing. Actual service tiers, discounts, taxes and tool fees are outside this reference.

Primary rates: https://developers.openai.com/api/docs/models/gpt-6-astra

| Per million tokens | USD |
|---|---:|
| Ordinary input | 10 |
| Cached input reads | 1 |
| Cache writes | 12.5 |
| Output (including reasoning) | 50 |

Above 272,000 input tokens per request, multiply input/cache rates by 2 and output by 1.5. The threshold is not applied to a whole log's cumulative input. The page separately documents Batch/Flex and Fast pricing; these are not used in this explicitly Standard scenario.

Count mapping: https://github.com/openai/codex/blob/main/codex-rs/codex-api/src/sse/responses.rs
The primary mapping/test retains input, cached reads and cache writes from Responses usage details; reasoning remains inside output. Ordinary input is input minus cached reads and writes. Inconsistent subdivisions remain unpriced.

Eligibility requires exact provider/model match, a single-response-compatible delta, and explicit cache-write fields in the logged cumulative and last usage. This establishes log-field evidence, not a server billing receipt. Unknown models/providers and missing provenance remain unpriced. The UI shows priced/total records and labels partial values as a priced portion.

Token ledger version 2 adds optional pricing eligibility. Version 1 loads with eligibility unknown; reimport can upgrade this metadata when all original observations still match. Unknown later versions are preserved and rejected. No computed monetary value is written into raw observations; the immutable quote ID/date/rates define the displayed reference. Future rates require a new dated quote, not silently changing this one.

## Expanded base-price catalog, same review date

Current catalog ID: `openai-base-standard-2026-09-07-v2`. Astra's prior quoted rates are unchanged. The [official pricing table](https://developers.openai.com/api/docs/pricing) explicitly gives short/long input, cache-read, cache-write and output rates:

| Model | Short input / read / write / output, USD per million | Long input / read / write / output |
|---|---|---|
| GPT-5.6 Sol | 4 / 0.4 / 5 / 20 | 8 / 0.8 / 10 / 30 |
| GPT-5.6 Terra | 2 / 0.2 / 2.5 / 12 | 4 / 0.4 / 5 / 18 |
| GPT-5.6 Luna | 0.2 / 0.02 / 0.25 / 1.2 | 0.4 / 0.04 / 0.5 / 1.8 |

Individual official model pages confirm the per-request >272K boundary. The base reference excludes regional processing uplift (10% where applicable), Fast/Batch/Flex adjustments, tool fees, discounts and taxes. Sol's promotional price is frozen as the 2026-09-07 reference, not a promise of future pricing. Exact model IDs only; unverified snapshot/alias names stay unpriced. Positive totals below one cent display < USD 0.01 rather than a misleading rounded zero.
