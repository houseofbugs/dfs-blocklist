---
name: manage-upstream-feeds
description: >-
  Add, remove, update, or verify upstream public DNS blocklist feeds in
  configuration.json for the DFS Unified AdGuard Home blocklist. Use when the
  user wants to include a new public blocklist, remove an existing feed, swap
  feed tiers (e.g., HaGeZi Pro vs Normal, TIF Mini vs Medium), or troubleshoot a
  failing upstream source.
---

# Manage Upstream Public Feeds

All upstream feeds are configured in [`configuration.json`](../../../../configuration.json) and compiled twice daily (plus on every push to `main`) by [`.github/workflows/compile.yml`](../../../../.github/workflows/compile.yml).

## Constraints to Keep in Mind

1. **GitHub Raw File Limit (< 25 MB):** `raw.githubusercontent.com` refuses files or diffs cleanly when compiled artifacts get excessive, and AdGuard Home appliances with low RAM struggle with giant lists. Always check a feed's `Content-Length` before adding it (for example, HaGeZi full `tif.txt` is ~47 MB, whereas `tif.medium.txt` is ~8.8 MB).
2. **Parser Type (`type`):** Set `"type": "adblock"` for AdGuard/Adblock-syntax lists (`||domain.com^`), or `"type": "hosts"` for `/etc/hosts`-style lists (`0.0.0.0 domain.com`).
3. **Preserve IP Rules:** Keep `"ValidateAllowIp"` (never `"Validate"`) in `"transformations"` so IP-based block rules aren't discarded.

## Workflow: Add, Change, or Remove a Feed

### Step 1: Verify the Upstream Feed URL (Add / Change)

Before editing `configuration.json`, verify the feed returns HTTP 200 and inspect its size and first few lines to determine whether it is `adblock` or `hosts` format:

```powershell
$url = "https://example.com/blocklist.txt"
$head = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 15
Write-Output "Status=$($head.StatusCode), Bytes=$($head.Headers['Content-Length'])"
$sample = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15).Content -split "\r?\n" | Select-Object -First 20
$sample
```

- Lines like `||example.com^` -> `"type": "adblock"`
- Lines like `0.0.0.0 example.com` or `127.0.0.1 example.com` -> `"type": "hosts"`

### Step 2: Update `configuration.json` and `README.md`

1. Edit [`configuration.json`](../../../../configuration.json) under `"sources"` to add, update, or remove the feed object:
   ```json
   {
     "name": "Descriptive Feed Name",
     "source": "https://example.com/blocklist.txt",
     "type": "adblock"
   }
   ```
2. Keep the feed table in [`README.md`](../../../../README.md) in sync.

### Step 3: Commit, Push, and Verify the Build

```powershell
git add configuration.json README.md
git commit -m "chore(feeds): update upstream blocklist sources"
git push
```

Wait ~45–90 seconds and verify the GitHub Actions run succeeds:

```powershell
$runs = Invoke-RestMethod "https://api.github.com/repos/houseofbugs/adguard-unified-blocklist/actions/runs?per_page=1"
$runs.workflow_runs[0] | Select-Object status, conclusion, updated_at, html_url
```
