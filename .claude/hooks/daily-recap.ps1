# SessionStart hook: 날짜가 바뀐 뒤 처음 Claude Code를 켜면 이전 작업일의 대화·커밋을 요약해 보여준다.
# 수동 테스트: powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/daily-recap.ps1 -Today 2026-10-13 -Force
param(
    [string]$Today,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

function Write-HookOutput([string]$systemMessage, [string]$context) {
    $obj = @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $context } }
    if ($systemMessage) { $obj.systemMessage = $systemMessage }
    $json = $obj | ConvertTo-Json -Depth 5 -Compress
    # 비ASCII 문자를 \uXXXX로 이스케이프해 콘솔 인코딩 문제를 피한다
    $json = [regex]::Replace($json, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    [Console]::Out.Write($json)
}

function Shorten([string]$s, [int]$max) {
    $s = ($s -replace '\s+', ' ').Trim()
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '…' }
    return $s
}

$proj = $env:CLAUDE_PROJECT_DIR
if (-not $proj) { $proj = Split-Path (Split-Path $PSScriptRoot) }
$logDir = Join-Path $proj '.claude\daily-logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$stateFile = Join-Path $logDir '.last-date'

if (-not $Today) { $Today = (Get-Date).ToString('yyyy-MM-dd') }
$last = ''
if (Test-Path $stateFile) { $last = (Get-Content $stateFile -Raw).Trim() }
if ($last -eq $Today -and -not $Force) { exit 0 }
# 요약용으로 띄우는 claude -p 가 이 훅을 다시 실행해도 바로 빠져나가도록 먼저 기록한다
Set-Content -Path $stateFile -Value $Today -Encoding ASCII

# --- 대화 기록 수집 ---
$transcriptDir = Join-Path $env:USERPROFILE ('.claude\projects\' + ($proj -replace '[^A-Za-z0-9]', '-'))
$entries = New-Object System.Collections.Generic.List[object]
if (Test-Path $transcriptDir) {
    $files = Get-ChildItem $transcriptDir -Filter *.jsonl -File
    if ($last) { $files = $files | Where-Object { $_.LastWriteTime.ToString('yyyy-MM-dd') -ge $last } }
    foreach ($f in $files) {
        foreach ($line in [IO.File]::ReadLines($f.FullName, [Text.Encoding]::UTF8)) {
            if ($line -notmatch '"type":"(user|assistant)"') { continue }
            try { $o = $line | ConvertFrom-Json } catch { continue }
            if ($o.isSidechain -or -not $o.timestamp -or -not $o.message) { continue }
            $time = [DateTimeOffset]::Parse($o.timestamp).ToLocalTime()
            $date = $time.ToString('yyyy-MM-dd')
            if ($date -ge $Today) { continue }
            if ($last -and $date -lt $last) { continue }

            $content = $o.message.content
            if ($o.type -eq 'user') {
                if ($content -isnot [string] -or $content.TrimStart().StartsWith('<')) { continue }
                $text = Shorten $content 500
                $role = '사용자'
            } else {
                $texts = @($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text })
                if (-not $texts) { continue }
                $text = Shorten ($texts -join ' ') 300
                $role = 'Claude'
            }
            $entries.Add([pscustomobject]@{ Date = $date; Time = $time; Role = $role; Text = $text })
        }
    }
}

# 마지막 기록이 없으면(첫 실행) 가장 최근 작업일 하루만 요약
$dates = @($entries | ForEach-Object { $_.Date } | Sort-Object -Unique)
if (-not $last -and $dates.Count -gt 1) {
    $dates = @($dates[-1])
}

# git 커밋도 함께 확인 (대화 없이 커밋만 있는 날도 포함)
$gitByDate = @{}
$gitDates = @()
$since = if ($last) { $last } elseif ($dates) { $dates[0] } else { (Get-Date $Today).AddDays(-1).ToString('yyyy-MM-dd') }
$gitLines = & git -C $proj log --since="$since 00:00" --until="$Today 00:00" --date=format:'%Y-%m-%d' --pretty='%ad|%h %s' 2>$null
foreach ($g in @($gitLines)) {
    if (-not $g) { continue }
    $d, $msg = $g -split '\|', 2
    if (-not $gitByDate[$d]) { $gitByDate[$d] = New-Object System.Collections.Generic.List[string] }
    $gitByDate[$d].Add($msg)
    $gitDates += $d
}
$dates = @(($dates + $gitDates) | Where-Object { $_ } | Sort-Object -Unique)
if (-not $dates) { exit 0 }

# --- 원본 로그 작성 ---
$raw = New-Object System.Text.StringBuilder
foreach ($d in $dates) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $d 작업 기록")
    if ($gitByDate[$d]) {
        [void]$sb.AppendLine("`n## 커밋")
        foreach ($c in $gitByDate[$d]) { [void]$sb.AppendLine("- $c") }
    }
    $dayEntries = @($entries | Where-Object { $_.Date -eq $d } | Sort-Object Time)
    if ($dayEntries) {
        [void]$sb.AppendLine("`n## 대화")
        foreach ($e in $dayEntries) { [void]$sb.AppendLine("- [$($e.Time.ToString('HH:mm'))] $($e.Role): $($e.Text)") }
    }
    [IO.File]::WriteAllText((Join-Path $logDir "$d.raw.md"), $sb.ToString(), (New-Object Text.UTF8Encoding $false))
    [void]$raw.AppendLine($sb.ToString())
}
$rawText = $raw.ToString()
if ($rawText.Length -gt 40000) { $rawText = '…(앞부분 생략)' + $rawText.Substring($rawText.Length - 40000) }
$dateLabel = $dates -join ', '

# --- claude -p 로 요약 생성 ---
$prompt = @"
아래는 웹페이지 프로젝트에서 진행한 Claude Code 대화 기록과 git 커밋이다. 날짜별로 한국어로 간결하게 요약해줘.
아래 기록에 있는 내용만 근거로 쓰고, 추측은 하지 마. 요약 외의 설명은 붙이지 마.
형식(마크다운, 날짜당 15줄 이내):
### YYYY-MM-DD
- **한 일**: ...
- **결정 사항**: ...
- **남은 일 / 다음 할 일**: ...

$rawText
"@

$summary = $null
try {
    $out = $prompt | & claude -p --model haiku --no-session-persistence '--tools=' 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) { $summary = (@($out) -join "`n").Trim() }
} catch { }

if ($summary) {
    foreach ($d in $dates) {
        [IO.File]::WriteAllText((Join-Path $logDir "$d.md"), $summary, (New-Object Text.UTF8Encoding $false))
    }
    $msg = "📅 지난 작업 요약 ($dateLabel)`n`n$summary`n`n(원본 기록: .claude/daily-logs/)"
    $ctx = "이전 작업일($dateLabel) 요약입니다. 사용자가 이어서 작업할 때 참고하세요.`n`n$summary"
    Write-HookOutput $msg $ctx
} else {
    $ctx = "이전 작업일($dateLabel)의 작업 기록입니다. 이번 세션의 첫 응답 맨 앞에서 날짜별로 '한 일 / 결정 사항 / 남은 일'을 한국어로 짧게 요약해 사용자에게 보여주고, 그 요약을 .claude/daily-logs/<날짜>.md 에 저장하세요.`n`n$rawText"
    Write-HookOutput "📅 지난 작업 기록($dateLabel)을 불러왔습니다. 첫 메시지를 보내면 요약해 드립니다." $ctx
}
exit 0
