# Qwen / Alibaba Bailian

Kind: unsupported. Milestone: v0.3.

Bailian exposes no balance endpoint. The `bl` CLI's `quota` commands report RPM/TPM rate limits, not
money, and free-tier usage needs a browser OAuth session to the console — an API key alone cannot read it.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `DASHSCOPE_API_KEY`; `~/.bailian/config.json` | Discovery still runs so the account is listed. |

## Behaviour

`fetch` returns `Usage.unsupported(reason:)` with a one-line explanation; the row shows the account and
"not supported", never a number. Revisit when Bailian documents a billing endpoint.

Last verified: —
