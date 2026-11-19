# AdGuard Home DNS Filtering Syntax Reference

Rules in `custom-block.txt`, `custom-allow.txt`, and `custom-rewrites.txt` follow AdGuard Home's DNS filtering syntax.

> **Important:** Full-line comments start with `!` at the start of a line. Never place `! comment` inline on the same line as a rule—AdGuard Home parses inline text as part of the rule pattern.

## 1. Domain & Host Rules

| Purpose | Syntax | Notes |
| --- | --- | --- |
| Block domain + subdomains | `\|\|example.com^` | Blocks `example.com` and `*.example.com` |
| Allow domain + subdomains | `@@\|\|example.com^$important` | Overrides any upstream blocklist rule |
| Block exact hostname only | `\|https://` not used; use `/^host\.example\.com$/` | Regex matches exact DNS query string |
| Wildcard pattern | `\|\|*telemetry*.example.com^` | Matches wildcard hostname labels |

## 2. IP Address Rules

Because `configuration.json` enables `ValidateAllowIp` and custom files are injected directly at the top of `blocklist.txt`, IP address rules are preserved:

| Purpose | Syntax | Notes |
| --- | --- | --- |
| Block IPv4 address | `\|\|203.0.113.45^` | Blocks queries resolving to or querying that IP |
| Block IPv6 address | `\|\|2001:db8::1^` | Blocks IPv6 literal |
| Allow IP address | `@@\|\|203.0.113.45^$important` | Overrides upstream IP blocks |

## 3. Host-to-IP Rewrites (`$dnsrewrite`)

Add these to `custom-rewrites.txt`:

| Purpose | Syntax |
| --- | --- |
| Point host to IPv4 | `\|\|nas.internal.local^$dnsrewrite=10.0.10.25` |
| Point host to IPv6 | `\|\|nas.internal.local^$dnsrewrite=fd00::25` |
| Explicit A record | `\|\|app.company.local^$dnsrewrite=NOERROR;A;192.168.1.50` |
| Explicit CNAME record | `\|\|alias.company.local^$dnsrewrite=NOERROR;CNAME;target.company.local` |
| Force NXDOMAIN / REFUSED | `\|\|blocked.company.local^$dnsrewrite=NXDOMAIN` or `REFUSED` |
| Client-scoped rewrite | `\|\|printer.local^$dnsrewrite=192.168.50.10,client=192.168.50.0/24` |

## 4. Common Modifiers

- `$important` — Gives the rule higher priority than standard block or allow rules.
- `$client=192.168.1.10` or `$client=192.168.1.0/24` — Restricts a rule to specific client IP(s) or CIDR subnet(s), separated by `|` (`client=10.0.0.0/8|192.168.1.5`).
- `$dnstype=AAAA` or `$dnstype=~A` — Matches or excludes specific DNS record types (e.g., `@@||example.com^$dnstype=AAAA` or `||example.com^$dnstype=HTTPS`).

## 5. `exclusions.txt` Patterns

`exclusions.txt` is passed to `@adguard/hostlist-compiler`'s `exclusions_sources` option to strip rules from upstream feeds *before* `blocklist.txt` is emitted:

- Plain substring: `||annoying-false-positive.com^`
- Regex pattern: `/^.*some-tld\^$/`
