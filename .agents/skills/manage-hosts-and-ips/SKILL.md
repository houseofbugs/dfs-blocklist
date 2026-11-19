---
name: manage-hosts-and-ips
description: >-
  Add, remove, change, block, allow (whitelist), or rewrite (map host to IP via
  $dnsrewrite) hosts, domains, and IP addresses in the DFS Unified Blocklist
  (AdGuard Home and UniFi UDM/UCG), or check whether a host/IP is currently blocked.
  Use whenever the user asks to block, unblock, allow, whitelist, add, remove, or
  change an IP or hostname for their AdGuard Home or UDM/UCG deployments.
---

# Manage Hosts, IPs, and DNS Rewrites

Use this skill to manage custom host rules, IP/CIDR blocks, global allowlists (false-positive overrides), and host-to-IP DNS rewrites (`$dnsrewrite`) across both **AdGuard Home** (`blocklist.txt`) and **UniFi UDM/UCG** (`udm-domains.txt`, `udm-ips.txt`) outputs backed by this repository.

All rule changes go into version-controlled files at the repository root and are automatically compiled into the `dist` branch by GitHub Actions:

- [`custom-block.txt`](../../../../custom-block.txt) — Block additional domains or IP/CIDR addresses (`||target^`, propagated to both `blocklist.txt` and `udm-domains.txt`/`udm-ips.txt`)
- [`custom-allow.txt`](../../../../custom-allow.txt) — Force-allow domains/IPs globally (`@@||target^$important`)
- [`custom-rewrites.txt`](../../../../custom-rewrites.txt) — Map or change a host's resolved IP in AdGuard Home (`||host^$dnsrewrite=IP`)
- [`exclusions.txt`](../../../../exclusions.txt) — Strip matching rules from upstream feeds during compilation (both AdGuard and UDM lists)

For syntax details and advanced modifiers (`$client`, `$dnstype`, IPv6, CIDR, regex), read [adguard-dns-syntax.md](./references/adguard-dns-syntax.md).

## Helper Script

Use [`scripts/manage-rules.ps1`](./scripts/manage-rules.ps1) for idempotent edits so conflicting rules across files are cleaned up automatically.

### 1. Block a Host, Domain, or IP

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action block -Target "bad-domain.com" -Comment "Phishing reported by client"
```

Block a raw IP address (preserved by `ValidateAllowIp`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action block -Target "203.0.113.45"
```

### 2. Allow / Unblock a Domain or IP (Fix False Positives)

Adds `@@||target^$important` to `custom-allow.txt` and `||target^` to `exclusions.txt` (removing any conflicting block rule):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action allow -Target "legit-vendor.com" -Comment "Required for client ERP"
```

### 3. Add or Change a Host-to-IP Mapping (DNS Rewrite)

Maps a hostname to an IPv4/IPv6 address (or replaces an existing IP for that host in `custom-rewrites.txt`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action rewrite -Target "nas.internal.local" -Ip "10.0.10.25"
```

Optionally scope a rewrite, block, or allow rule to a specific client IP or subnet with `-Client`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action rewrite -Target "printer.office.local" -Ip "192.168.50.10" -Client "192.168.50.0/24"
```

### 4. Remove a Host or IP from All Custom Lists

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action remove -Target "old-host.example.com"
```

### 5. Check or List Rules

List all active custom rules across all four files:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action list
```

Check whether a host/IP (or its parent domains) appears locally or in the live compiled `dist` lists (`blocklist.txt`, `udm-domains.txt`, `udm-ips.txt`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action check -Target "sub.example.com" -CheckLive
```

## Deploying & Verifying Changes

1. Pass `-Push` to `manage-rules.ps1` (or run `git add custom-*.txt exclusions.txt && git commit -m "..." && git push`) to push to `origin/main`.
2. Pushing to `main` triggers `.github/workflows/compile.yml` (~45–90 seconds).
3. Verify the latest workflow run succeeded and the live files updated:
   ```powershell
   $runs = Invoke-RestMethod "https://api.github.com/repos/houseofbugs/dfs-blocklist/actions/runs?per_page=1"
   $runs.workflow_runs[0] | Select-Object status, conclusion, updated_at, html_url
   ```
4. Once `conclusion` is `success`, remind the user that AdGuard Home and UniFi UDM/UCG External Lists auto-update on schedule (or they can trigger a manual update from their dashboard).
