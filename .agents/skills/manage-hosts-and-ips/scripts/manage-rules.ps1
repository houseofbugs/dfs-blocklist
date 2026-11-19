[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("block", "allow", "rewrite", "remove", "check", "list")]
    [string]$Action,

    [string]$Target,
    [string]$Ip,
    [string]$Client,
    [string]$Comment,
    [switch]$CheckLive,
    [switch]$Push
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$files = @{
    block     = Join-Path $repoRoot "custom-block.txt"
    allow     = Join-Path $repoRoot "custom-allow.txt"
    rewrite   = Join-Path $repoRoot "custom-rewrites.txt"
    exclusion = Join-Path $repoRoot "exclusions.txt"
}

foreach ($entry in $files.GetEnumerator()) {
    if (-not (Test-Path $entry.Value)) {
        throw "Expected rule file not found: $($entry.Value)"
    }
}

function Normalize-Target {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $clean = $Value.Trim()
    $clean = $clean -replace '^@@', ''
    $clean = $clean -replace '^\|\|', ''
    $clean = $clean -replace '^https?://', ''
    $clean = $clean -replace '/.*$', ''
    $clean = $clean -replace '\^.*$', ''
    return $clean.Trim().ToLowerInvariant()
}

function Test-LineMatchesTarget {
    param(
        [string]$Line,
        [string]$NormalizedTarget,
        [string]$ClientFilter = ""
    )

    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith("!") -or $trimmed.StartsWith("#")) { return $false }

    $esc = [regex]::Escape($NormalizedTarget)
    $matchesTarget = (
        ($trimmed -match "^(@@)?\|\|$esc\^($|\$)") -or
        ($trimmed -match "^((0\.0\.0\.0|127\.0\.0\.1)\s+)?$esc(\s|$)")
    )
    if (-not $matchesTarget) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($ClientFilter)) {
        $escClient = [regex]::Escape($ClientFilter.Trim())
        return ($trimmed -match "(^|,|\$)client=$escClient(,|$)")
    }

    return $true
}

function Write-Utf8NoBom {
    param(
        [string]$FilePath,
        [string[]]$Lines
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = if ($null -eq $Lines -or $Lines.Count -eq 0) { "" } else { ($Lines -join "`r`n") + "`r`n" }
    [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)
}

function Remove-TargetFromFile {
    param(
        [string]$FilePath,
        [string]$NormalizedTarget,
        [string]$ClientFilter = ""
    )

    $lines = Get-Content -Path $FilePath -Encoding UTF8
    if ($null -eq $lines) { $lines = @() }

    $kept = New-Object System.Collections.Generic.List[string]
    $removed = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if (Test-LineMatchesTarget -Line $line -NormalizedTarget $NormalizedTarget -ClientFilter $ClientFilter) {
            $removed.Add($line)
        } else {
            $kept.Add($line)
        }
    }

    if ($removed.Count -gt 0) {
        Write-Utf8NoBom -FilePath $FilePath -Lines $kept.ToArray()
    }

    return $removed.ToArray()
}

function Add-RuleToFile {
    param(
        [string]$FilePath,
        [string]$RuleLine,
        [string]$Note = ""
    )

    $existing = Get-Content -Path $FilePath -Encoding UTF8
    if ($null -eq $existing) { $existing = @() }

    $toAppend = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Note)) {
        $toAppend.Add("! $Note")
    }
    $toAppend.Add($RuleLine)

    $updated = @($existing) + $toAppend.ToArray()
    Write-Utf8NoBom -FilePath $FilePath -Lines $updated
}

function Get-ActiveRules {
    param([string]$FilePath)
    $lines = Get-Content -Path $FilePath -Encoding UTF8
    if ($null -eq $lines) { return @() }
    return @($lines | Where-Object {
        $t = $_.Trim()
        -not [string]::IsNullOrWhiteSpace($t) -and -not $t.StartsWith("!") -and -not $t.StartsWith("#")
    })
}

if ($Action -eq "list") {
    foreach ($key in @("rewrite", "allow", "block", "exclusion")) {
        $path = $files[$key]
        $active = Get-ActiveRules -FilePath $path
        Write-Output "=== $(Split-Path $path -Leaf) ($($active.Count) active) ==="
        if ($active.Count -eq 0) {
            Write-Output "  (none)"
        } else {
            foreach ($r in $active) {
                Write-Output "  $r"
            }
        }
    }
    exit 0
}

$cleanTarget = Normalize-Target -Value $Target
if ([string]::IsNullOrWhiteSpace($cleanTarget)) {
    throw "-Target is required for action '$Action'."
}

if ($Action -eq "check") {
    Write-Output "Checking local custom files for '$cleanTarget':"
    $foundLocal = $false
    foreach ($key in @("rewrite", "allow", "block", "exclusion")) {
        $path = $files[$key]
        $matches = @(Get-ActiveRules -FilePath $path | Where-Object {
            Test-LineMatchesTarget -Line $_ -NormalizedTarget $cleanTarget
        })
        if ($matches.Count -gt 0) {
            $foundLocal = $true
            Write-Output "  [$(Split-Path $path -Leaf)]"
            foreach ($m in $matches) { Write-Output "    $m" }
        }
    }
    if (-not $foundLocal) {
        Write-Output "  No custom rules found locally for '$cleanTarget'."
    }

    if ($CheckLive) {
        $liveUrl = "https://raw.githubusercontent.com/houseofbugs/adguard-unified-blocklist/dist/blocklist.txt"
        Write-Output "Checking live compiled list ($liveUrl)..."
        $content = (Invoke-WebRequest -Uri $liveUrl -UseBasicParsing -TimeoutSec 30).Content
        $liveLines = $content -split "\r?\n"

        # Check exact domain/IP plus parent domains (since ||parent.com^ blocks sub.parent.com)
        $candidates = New-Object System.Collections.Generic.List[string]
        $candidates.Add($cleanTarget)
        if ($cleanTarget -notmatch '^(\d{1,3}\.){3}\d{1,3}$' -and $cleanTarget -notmatch ':') {
            $parts = $cleanTarget.Split('.')
            for ($i = 1; $i -lt ($parts.Length - 1); $i++) {
                $candidates.Add(($parts[$i..($parts.Length - 1)] -join '.'))
            }
        }

        $liveMatches = New-Object System.Collections.Generic.List[string]
        foreach ($cand in $candidates) {
            $escCand = [regex]::Escape($cand)
            $hits = $liveLines | Where-Object { $_ -match "^(@@)?\|\|$escCand\^($|\$)" }
            foreach ($h in $hits) {
                if (-not $liveMatches.Contains($h)) {
                    $liveMatches.Add($h)
                }
            }
        }

        if ($liveMatches.Count -eq 0) {
            Write-Output "  Live list: NO matching rules found for '$cleanTarget' (or its parent domains)."
        } else {
            Write-Output "  Live list matching rules ($($liveMatches.Count)):"
            foreach ($m in $liveMatches) { Write-Output "    $m" }
        }
    }
    exit 0
}

$changed = $false
$clientFilter = if ([string]::IsNullOrWhiteSpace($Client)) { "" } else { $Client.Trim() }

switch ($Action) {
    "block" {
        $remAllow = Remove-TargetFromFile -FilePath $files.allow -NormalizedTarget $cleanTarget -ClientFilter $clientFilter
        $remExcl  = Remove-TargetFromFile -FilePath $files.exclusion -NormalizedTarget $cleanTarget
        $remBlock = Remove-TargetFromFile -FilePath $files.block -NormalizedTarget $cleanTarget -ClientFilter $clientFilter

        $rule = "||$cleanTarget^"
        if (-not [string]::IsNullOrWhiteSpace($clientFilter)) {
            $rule += "`$client=$clientFilter"
        }
        Add-RuleToFile -FilePath $files.block -RuleLine $rule -Note $Comment
        $changed = $true

        Write-Output "Blocked '$cleanTarget' -> $rule (in custom-block.txt)"
        if ($remAllow.Count -gt 0) { Write-Output "  Removed from custom-allow.txt: $($remAllow -join ', ')" }
        if ($remExcl.Count -gt 0)  { Write-Output "  Removed from exclusions.txt: $($remExcl -join ', ')" }
        if ($remBlock.Count -gt 0) { Write-Output "  Replaced in custom-block.txt: $($remBlock -join ', ')" }
    }

    "allow" {
        $remBlock = Remove-TargetFromFile -FilePath $files.block -NormalizedTarget $cleanTarget -ClientFilter $clientFilter
        $remAllow = Remove-TargetFromFile -FilePath $files.allow -NormalizedTarget $cleanTarget -ClientFilter $clientFilter
        $remExcl  = Remove-TargetFromFile -FilePath $files.exclusion -NormalizedTarget $cleanTarget

        $allowRule = "@@||$cleanTarget^`$important"
        if (-not [string]::IsNullOrWhiteSpace($clientFilter)) {
            $allowRule += ",client=$clientFilter"
        }
        Add-RuleToFile -FilePath $files.allow -RuleLine $allowRule -Note $Comment

        # Strip from upstream sources at compile time only when global (not client-scoped)
        if ([string]::IsNullOrWhiteSpace($clientFilter)) {
            Add-RuleToFile -FilePath $files.exclusion -RuleLine "||$cleanTarget^" -Note $Comment
        }
        $changed = $true

        Write-Output "Allowed '$cleanTarget' -> $allowRule (in custom-allow.txt)"
        if ([string]::IsNullOrWhiteSpace($clientFilter)) {
            Write-Output "  Also added '||$cleanTarget^' to exclusions.txt to strip upstream block rules."
        }
        if ($remBlock.Count -gt 0) { Write-Output "  Removed from custom-block.txt: $($remBlock -join ', ')" }
        if ($remAllow.Count -gt 0) { Write-Output "  Replaced in custom-allow.txt: $($remAllow -join ', ')" }
        if ($remExcl.Count -gt 0)  { Write-Output "  Replaced in exclusions.txt: $($remExcl -join ', ')" }
    }

    "rewrite" {
        if ([string]::IsNullOrWhiteSpace($Ip)) {
            throw "-Ip is required when using -Action rewrite."
        }
        $cleanIp = $Ip.Trim()
        $remRewrite = Remove-TargetFromFile -FilePath $files.rewrite -NormalizedTarget $cleanTarget -ClientFilter $clientFilter

        $rule = "||$cleanTarget^`$dnsrewrite=$cleanIp"
        if (-not [string]::IsNullOrWhiteSpace($clientFilter)) {
            $rule += ",client=$clientFilter"
        }
        Add-RuleToFile -FilePath $files.rewrite -RuleLine $rule -Note $Comment
        $changed = $true

        Write-Output "Set DNS rewrite '$cleanTarget' -> $rule (in custom-rewrites.txt)"
        if ($remRewrite.Count -gt 0) { Write-Output "  Replaced existing rewrite(s): $($remRewrite -join ', ')" }
    }

    "remove" {
        $totalRemoved = 0
        foreach ($key in @("block", "allow", "rewrite", "exclusion")) {
            $path = $files[$key]
            $cf = if ($key -eq "exclusion") { "" } else { $clientFilter }
            $rem = Remove-TargetFromFile -FilePath $path -NormalizedTarget $cleanTarget -ClientFilter $cf
            if ($rem.Count -gt 0) {
                $changed = $true
                $totalRemoved += $rem.Count
                Write-Output "Removed from $(Split-Path $path -Leaf): $($rem -join ', ')"
            }
        }
        if ($totalRemoved -eq 0) {
            Write-Output "No rules matching '$cleanTarget' were found in any custom file."
        }
    }
}

if ($Push -and $changed) {
    Push-Location $repoRoot
    try {
        $ErrorActionPreference = "Continue"
        git add custom-block.txt custom-allow.txt custom-rewrites.txt exclusions.txt
        if ($LASTEXITCODE -ne 0) { throw "git add failed with exit code $LASTEXITCODE" }

        $status = git status --porcelain -- custom-block.txt custom-allow.txt custom-rewrites.txt exclusions.txt
        if ([string]::IsNullOrWhiteSpace(($status -join ""))) {
            Write-Output "No git diff to commit."
            exit 0
        }

        git commit -m "chore(rules): $Action $cleanTarget"
        if ($LASTEXITCODE -ne 0) { throw "git commit failed with exit code $LASTEXITCODE" }

        git push
        if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }
        Write-Output "Committed and pushed rule change to origin/main."
    } finally {
        Pop-Location
    }
}
