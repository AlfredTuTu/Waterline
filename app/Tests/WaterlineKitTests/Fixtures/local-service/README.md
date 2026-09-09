# Synthetic loopback TLS certificate

`localhost.der` is a generated public test certificate, not a provider certificate or credential.
Generated locally on 2026-09-07 with OpenSSL RSA 2048, SHA-256, localhost/127.0.0.1 SANs,
serverAuth EKU, CA:false and a one-year validity interval. The temporary private key was
deleted immediately and is not part of the repository. Tests evaluate at fixed dates,
so wall-clock expiration does not make the fixture nondeterministic.

SHA-256 fingerprint: 5542D85E13EECA1AC50E2619FEEED5F651C2A2FADBA91AE9E7734AAEBD4A901D.

`antigravity-cli-1.1.27.der` is the public, CLI-bundled localhost certificate observed
from the verified Google-signed CLI listener; it contains no account or private key.
Its exact DER SHA-256 is b1366941e98e584cad699a9aecfff2fdd3576c731d380cccbf31c4854c07657c.
OpenSSL `verify -check_ss_sig` verified its RSA-2048/SHA-256 self-signature. SANs include
localhost and 127.0.0.1. Validity is 2026-04-18T00:18:09Z through 2026-11-03T00:18:09Z.
It lacks serverAuth EKU; tests verify normal SSL rejection and narrowly scoped pin acceptance.

`antigravity-cli-2026-09-08.der` is the renewed public certificate from the same verified
Google-signed CLI. SHA256: f8bbabd57a2dff32992f205ede841f9ba8d95cdf45982e1d0e73aa5834e9cf94.
Validity: 2026-09-08T19:02:15Z through 2027-03-26T19:02:15Z; RSA-2048/SHA-256,
localhost and 127.0.0.1 SANs, no serverAuth EKU. It contains no private key or account data.
The regression runs both reviewed pins, altered DER, wrong host and invalid dates.
