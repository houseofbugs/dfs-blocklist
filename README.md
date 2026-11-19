# DFS Unified Blocklist

Unified, auto-updating DNS and firewall blocklists built for **AdGuard Home** and **UniFi Dream Machine / Cloud Gateway (UDM / UDM-Pro / UDM-SE / UCG)** deployments.

Every **12 hours** (`0 */12 * * *` UTC) and on every push to `main`, [GitHub Actions](.github/workflows/compile.yml) automatically fetches upstream threat & ad feeds, deduplicates them, applies your custom blocks/allows/rewrites, and publishes ready-to-use files to the `dist` branch—completely hands-off.

---

## Live Blocklist URLs

| Platform | List Name | URL | Notes |
| --- | --- | --- | --- |
| **AdGuard Home** | Unified Blocklist (Full) | `https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/blocklist.txt` | Adblock syntax (`\|\|domain^`, `$dnsrewrite`, `$important`), ~750k+ rules |
| **UniFi UDM / UCG** | External Domain List (Lite) | `https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-domains.txt` | Plain domains (1/line), high-confidence malware/phishing + custom blocks, capped at **9,500** for UDM limits |
| **UniFi UDM / UCG** | External IP/CIDR List (Lite) | `https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-ips.txt` | Plain IPv4 & CIDRs (1/line), Spamhaus DROP + HaGeZi TIF + custom IPs, capped at **9,500** for UDM limits |
| **Appliances / Full** | Plain Domains (Full) | `https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-domains-full.txt` | Uncapped plain-domain list extracted from the full compiled list |
| **Appliances / Full** | Plain IPs/CIDRs (Full) | `https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-ips-full.txt` | Uncapped plain IP/CIDR threat intelligence list |

---

## Setup: AdGuard Home

1. Open your AdGuard Home web dashboard.
2. Go to **Filters** -> **DNS blocklists**.
3. Click **Add blocklist** -> **Add a custom list**.
4. Enter a name (e.g., `DFS Unified Blocklist`) and paste:
   ```text
   https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/blocklist.txt
   ```
5. Click **Save**. AdGuard Home downloads the list immediately and auto-updates on its configured filter update interval (default: every 24 hours; customizable under **Settings** -> **General settings** -> **Filters update interval**).

---

## Setup: UniFi UDM / UDM-Pro / UDM-SE / UCG Gateways

UniFi gateways running **UniFi Network 11.0+ / UniFi OS 6.0+** support **External Network Lists** that auto-update from a URL, paired with UniFi's built-in **Ad Blocking**.

> **Why separate UDM URLs?** UniFi External Lists require plain one-entry-per-line text (no Adblock `||` or `^` syntax) and enforce ~10,000-entry `ipset`/provisioning limits per list. Using `udm-domains.txt` and `udm-ips.txt` keeps your gateways fast and prevents provisioning errors.

### 1. Enable Native UniFi Ad Blocking (Ads & Trackers)
1. In the UniFi Network dashboard, go to **Settings** -> **CyberSecure** -> **Content Filter** *(or **Security** -> **Traffic & Firewall** on older layouts)*.
2. Enable **Ad Blocking** on your client LAN/VLAN networks (using UniFi's built-in ad database).
3. *(Optional)* Enable **DNS Shield** / Encrypted DNS so client devices cannot easily bypass gateway DNS filtering.

### 2. Add the DFS Threat Domain & IP External Lists
1. Go to **Settings** -> **Profiles** *(or **CyberSecure** / **Objects**)* -> **External Network Lists** (Create New).
2. Create the **Domain Threat List**:
   - **Name:** `DFS Threat Domains`
   - **Type:** Domain List
   - **URL:**
     ```text
     https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-domains.txt
     ```
   - **Auto-Update Interval:** `24 hours`
   - Click **Save**.
3. Create the **IP/CIDR Threat List**:
   - **Name:** `DFS Threat IPs`
   - **Type:** IP Address / Subnet List
   - **URL:**
     ```text
     https://raw.githubusercontent.com/houseofbugs/dfs-blocklist/dist/udm-ips.txt
     ```
   - **Auto-Update Interval:** `24 hours`
   - Click **Save**.

### 3. Attach Both Lists to Blocking Rules
1. Go to **Settings** -> **Security** -> **Traffic & Firewall Rules** *(or **Policy Engine**)* -> **Create Entry**.
2. **Block Threat Domains:**
   - **Action:** `Block`
   - **Source:** Your internal networks/VLANs (e.g., `All Internal Networks`)
   - **Destination:** Select the **`DFS Threat Domains`** External List
   - Save the rule.
3. **Block Threat IPs (Inbound & Outbound):**
   - **Action:** `Block`
   - **Direction / Zone:** Internal -> External (and optionally External -> Internal)
   - **Destination (and/or Source):** Select the **`DFS Threat IPs`** External List
   - Save the rule.

*(For clients who want the full 750k+ ad/malware ruleset plus custom DNS rewrites, run AdGuard Home on a local VM/LXC/Raspberry Pi and point UniFi DHCP DNS to that AdGuard Home instance using `blocklist.txt`.)*

---

## Managing Global Overrides (Both AdGuard Home & UDM/UCG)

Changes pushed to `main` automatically recompile **all** output files (`blocklist.txt`, `udm-domains.txt`, `udm-ips.txt`, and `-full` variants) within ~1 minute:

- **Allow / whitelist a domain or IP globally (false positives):**
  Add `@@||example.com^$important` to [`custom-allow.txt`](custom-allow.txt) and `||example.com^` to [`exclusions.txt`](exclusions.txt). Allowed domains/IPs are stripped from both AdGuard Home and UDM lists.
- **Block an additional domain, IP, or CIDR globally:**
  Add `||bad-domain.com^`, `||203.0.113.45^`, or `||203.0.113.0/24^` to [`custom-block.txt`](custom-block.txt). Custom blocks are prioritized at the top of `udm-domains.txt` / `udm-ips.txt` so they are never truncated by the 9,500-entry cap.
- **Map or change a hostname's IP address (AdGuard Home DNS rewrite):**
  Add `||host.example.com^$dnsrewrite=192.168.1.50` to [`custom-rewrites.txt`](custom-rewrites.txt) (optionally scoped with `,client=192.168.1.0/24`). *(Applies to AdGuard Home `blocklist.txt`; on UDM use UniFi's local DNS Record settings.)*
- **Quick CLI helper & Antigravity skills:**
  Workspace skills in [`.agents/skills/`](.agents/skills/manage-hosts-and-ips/SKILL.md) include [`manage-rules.ps1`](.agents/skills/manage-hosts-and-ips/scripts/manage-rules.ps1) to add, remove, change, check, and push rules:
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action block -Target "bad-domain.com" -Push
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action allow -Target "legit-site.com" -Push
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\manage-hosts-and-ips\scripts\manage-rules.ps1" -Action rewrite -Target "nas.internal.local" -Ip "10.0.10.25" -Push
  ```

---

## Included Upstream Feeds

### AdGuard Home (`blocklist.txt` & `udm-domains-full.txt`)
| Category | Feed Name | Source |
| --- | --- | --- |
| Custom Overrides | DFS Custom DNS Rewrites | [`custom-rewrites.txt`](custom-rewrites.txt) |
| Custom Overrides | DFS Custom Blocklist | [`custom-block.txt`](custom-block.txt) |
| Custom Overrides | DFS Custom Allowlist | [`custom-allow.txt`](custom-allow.txt) |
| Ads & Trackers | AdGuard DNS Filter | `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt` |
| Ads & Trackers | HaGeZi Multi PRO | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt` |
| Ads & Trackers | OISD Big | `https://big.oisd.nl` |
| Threat Intelligence | HaGeZi Threat Intelligence Feeds (Medium) | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.medium.txt` |
| Malware | Abuse.ch URLHaus Malicious Domains | `https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh-online.txt` |
| Phishing | Phishing URL Blocklist (PhishTank, OpenPhish, PhishStats) | `https://malware-filter.gitlab.io/malware-filter/phishing-filter-agh.txt` |
| Phishing | Phishing Army Extended | `https://phishing.army/download/phishing_army_blocklist_extended.txt` |
| Malware | DandelionSprout Anti-Malware | `https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuardHome.txt` |

### UniFi UDM / UCG High-Confidence Feeds (`udm-domains.txt` & `udm-ips.txt`)
| Target File | Feed Name | Source |
| --- | --- | --- |
| `udm-domains.txt` | DFS Custom Domains + URLHaus + DandelionSprout + Phishing Filter (capped at 9,500) | Above malware & phishing sources |
| `udm-ips.txt` | DFS Custom IPs/CIDRs + Spamhaus DROP + HaGeZi TIF IPs (capped at 9,500) | `https://www.spamhaus.org/drop/drop.txt` & `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/ips/tif.txt` |
