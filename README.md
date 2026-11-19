# DFS Unified AdGuard Home Blocklist

A unified, auto-updating DNS blocklist compiled with [`@adguard/hostlist-compiler`](https://github.com/AdguardTeam/HostlistCompiler) to block ads, trackers, malware, phishing, and command-and-control (C2) traffic across multiple AdGuard Home deployments.

## Blocklist URL

Add this single URL to every AdGuard Home installation:

```text
https://raw.githubusercontent.com/houseofbugs/adguard-unified-blocklist/dist/blocklist.txt
```

## How to Add in AdGuard Home

1. Open your AdGuard Home web dashboard.
2. Go to **Filters** -> **DNS blocklists**.
3. Click **Add blocklist** -> **Add a custom list**.
4. Enter a name (e.g., `DFS Unified Blocklist`) and paste the URL above.
5. Click **Save**. AdGuard Home will fetch and apply the unified list immediately and keep it automatically updated on its configured filter update interval.

## Managing Global Overrides (All Clients)

Changes pushed to `main` automatically trigger the GitHub Actions compiler, updating `blocklist.txt` on the `dist` branch within ~1 minute:

- **Allow a blocked domain globally (false positives):**
  Add an allow rule to [`custom-allow.txt`](custom-allow.txt) using `@@||example.com^$important` (or add the domain/rule to [`exclusions.txt`](exclusions.txt) to strip it during compilation).
- **Block an additional domain globally:**
  Add a rule to [`custom-block.txt`](custom-block.txt) using `||bad-domain.com^`.
- **Automatic schedule:**
  The [GitHub Action workflow](.github/workflows/compile.yml) recompiles and deduplicates all upstream lists every **12 hours** (`0 */12 * * *`), force-pushing a single clean commit to the `dist` branch so repository history stays small.

## Included Upstream Feeds

| Category | Feed Name | Source |
| --- | --- | --- |
| Custom Overrides | DFS Custom Blocklist | [`custom-block.txt`](custom-block.txt) |
| Custom Overrides | DFS Custom Allowlist | [`custom-allow.txt`](custom-allow.txt) |
| Ads & Trackers | AdGuard DNS Filter | `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt` |
| Ads & Trackers | HaGeZi Multi PRO | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt` |
| Ads & Trackers | OISD Big | `https://big.oisd.nl` |
| Threat Intelligence | HaGeZi Threat Intelligence Feeds (Medium) | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.medium.txt` |
| Malware | Abuse.ch URLHaus Malicious Domains (AdGuard Home) | `https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh-online.txt` |
| Phishing | Phishing URL Blocklist (PhishTank, OpenPhish, PhishStats) | `https://malware-filter.gitlab.io/malware-filter/phishing-filter-agh.txt` |
| Phishing | Phishing Army Extended | `https://phishing.army/download/phishing_army_blocklist_extended.txt` |
| Malware | DandelionSprout Anti-Malware for AdGuard Home | `https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuardHome.txt` |
