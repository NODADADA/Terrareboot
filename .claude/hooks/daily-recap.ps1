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

# 마지막 기록이 없으면(첫 실행) 지금까지의 모든 작업일을 날짜별로 요약
$dates = @($entries | ForEach-Object { $_.Date } | Sort-Object -Unique)

# git 커밋도 함께 확인 (대화 없이 커밋만 있는 날도 포함)
$gitByDate = @{}
$gitDates = @()
$gitArgs = @('-C', $proj, 'log', "--until=$Today 00:00", '--date=format:%Y-%m-%d', '--pretty=%ad|%h %s')
if ($last) { $gitArgs += "--since=$last 00:00" }
$gitLines = & git @gitArgs 2>$null
foreach ($g in @($gitLines)) {
    if (-not $g) { continue }
    $d, $msg = $g -split '\|', 2
    # 대화 기록이 없는 날도 상세 요약에 쓸 수 있도록 바뀐 파일을 붙인다
    $changed = @(& git -C $proj show --name-only --pretty=format: ($msg -split ' ', 2)[0] 2>$null | Where-Object { $_ })
    if ($changed) { $msg += " (파일: $(($changed | Select-Object -First 8) -join ', ')$(if ($changed.Count -gt 8) { ' 외' }))" }
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
    # 여러 날을 한 번에 요약할 때 특정 날짜가 통째로 잘리지 않도록 날짜마다 길이를 나눠 제한한다
    $dayText = $sb.ToString()
    $perDay = [Math]::Max(4000, [int](60000 / $dates.Count))
    if ($dayText.Length -gt $perDay) { $dayText = $dayText.Substring(0, $perDay) + "`n…(이하 생략)`n" }
    [void]$raw.AppendLine($dayText)
}
$rawText = $raw.ToString()
$dateLabel = $dates -join ', '

# 작업 제안의 근거: 이번에 요약하지 않는 이전 날짜 요약(최근 5일)과 최근 커밋
$prevSummaries = @(Get-ChildItem $logDir -Filter '????-??-??.md' -File |
    Where-Object { $dates -notcontains $_.BaseName } | Sort-Object Name | Select-Object -Last 5 |
    ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n`n"
if (-not $prevSummaries) { $prevSummaries = '(없음)' }
$recentCommits = @(& git -C $proj log -15 --date=short --pretty='%ad %h %s' 2>$null) -join "`n"
$pushState = '확인 불가'
$counts = & git -C $proj rev-list --left-right --count 'HEAD...@{u}' 2>$null
if ($LASTEXITCODE -eq 0 -and $counts -match '^(\d+)\s+(\d+)') {
    $pushState = if ($Matches[1] -eq '0') { '푸시 안 된 커밋 없음 (위 커밋은 모두 원격에 올라가 있음)' } else { "푸시 안 된 커밋 $($Matches[1])개" }
}

# --- claude -p 로 요약 생성 ---
$prompt = @"
아래는 게임 홍보 웹페이지 프로젝트에서 진행한 Claude Code 대화 기록과 git 커밋이다. 날짜별 요약과 오늘 작업 제안을 한국어로 써줘.
기록에 있는 내용만 근거로 쓰고, 추측은 하지 마. 요약과 제안 외의 설명은 붙이지 마.

규칙:
- 주요 작업은 중요도가 높은 순서로 날짜당 최대 3개만 쓴다.
  중요도: 새 기능·새 페이지·사이트 구조 변경 > 새 콘텐츠·이미지 적용처럼 사이트 인상을 바꾸는 작업 > 작업 환경·도구 설정 > 위치·크기·간격 같은 세부 조정.
- 세부 조정은 관련된 상위 작업에 묶거나 생략한다. 항목마다 결과 중심으로 한 줄로 쓰고, 커밋 해시·파일명·수치는 쓰지 않는다.
- 결정 사항은 이후 작업에도 계속 적용되는 원칙만 쓰고, 없으면 그 줄을 통째로 뺀다.
- 남은 일은 기록에 명시된 것만 쓰고, 없으면 그 줄을 통째로 뺀다.
- 마지막의 오늘 작업 제안은 1~3개를 우선순위 순으로 쓴다. 각 제안에 기록에서 찾은 근거(남은 일, 아직 비어 있는 부분, 최근 작업 흐름)를 붙이고, 근거 없는 일반론은 쓰지 않는다.

형식(마크다운):
### YYYY-MM-DD
**주요 작업**
1. ...
2. ...
**결정 사항**: ...
**남은 일**: ...

## 오늘 작업 제안
1. **할 일** - 근거

[이전 날짜 요약 (제안 참고용, 다시 요약하지 말 것)]
$prevSummaries

[최근 커밋 (제안 참고용)]
$recentCommits

[푸시 상태] $pushState

[요약할 기록]
$rawText
"@

$longPrompt = @"
아래는 게임 홍보 웹페이지 프로젝트에서 진행한 Claude Code 대화 기록과 git 커밋이다. 날짜별 상세 작업 일지를 한국어 일반 텍스트로 써줘.
기록에 있는 내용만 근거로 쓰고, 추측은 하지 마. 일지 외의 설명은 붙이지 마. 마크다운 기호(#, *, |, 백틱)는 쓰지 마.
작업 내용은 중요도가 높은 순서로 쓰고, 항목마다 무엇을 왜 했는지, 바뀐 파일, 관련 커밋 해시를 적는다. 내용이 없는 칸은 '- 없음'으로 쓴다.

형식(날짜마다 반복):
==================== YYYY-MM-DD ====================
[개요]
그날 작업을 2~3문장으로.

[작업 내용]
1. 작업 이름 (커밋 해시)
   - 무엇을, 왜 했는지
   - 바뀐 파일: ...

[결정 사항과 이유]
- ...

[문제와 해결]
- ...

[남은 일]
- ...

$rawText
"@

$runClaude = {
    param([string]$p)
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $OutputEncoding = [Text.Encoding]::UTF8
    $out = $p | & claude -p --model haiku --no-session-persistence '--tools=' 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) { (@($out) -join "`n").Trim() }
}

# 긴 버전은 백그라운드에서 동시에 생성해 시작 시간을 줄인다
$longJob = $null
try { $longJob = Start-Job -ScriptBlock $runClaude -ArgumentList $longPrompt } catch { }

$summary = $null
try { $summary = & $runClaude $prompt } catch { }

$longSaved = $false
if ($longJob) {
    try {
        $long = $null
        if (Wait-Job $longJob -Timeout 140) { $long = (@(Receive-Job $longJob) -join "`n").Trim() }
        Remove-Job $longJob -Force
        if ($long) {
            # 날짜별 .long.txt 로 저장한 뒤, 전체를 최신 날짜부터 하나의 txt로 합친다
            foreach ($part in [regex]::Split($long, '(?m)^(?==+ \d{4}-\d{2}-\d{2} =+)')) {
                if ($part -match '^=+ (\d{4}-\d{2}-\d{2}) =+') {
                    [IO.File]::WriteAllText((Join-Path $logDir "$($Matches[1]).long.txt"), $part.Trim() + "`r`n", (New-Object Text.UTF8Encoding $false))
                }
            }
            $all = @(Get-ChildItem $logDir -Filter '????-??-??.long.txt' -File | Sort-Object Name -Descending |
                ForEach-Object { [IO.File]::ReadAllText($_.FullName).Trim() })
            $header = "작업 요약 (상세)`r`n마지막 갱신: $((Get-Date).ToString('yyyy-MM-dd HH:mm'))`r`n"
            $body = ($header, ($all -join "`r`n`r`n")) -join "`r`n"
            [IO.File]::WriteAllText((Join-Path $logDir '작업요약_상세.txt'), ($body -replace "(?<!`r)`n", "`r`n"), (New-Object Text.UTF8Encoding $true))
            $longSaved = $true
        }
    } catch { }
}
$longNote = if ($longSaved) { '상세 버전: .claude/daily-logs/작업요약_상세.txt' } else { '원본 기록: .claude/daily-logs/' }

if ($summary) {
    # 오늘 작업 제안은 날짜별 파일에 넣지 않고 따로 저장
    $suggest = ''
    $byDate = $summary
    $m = [regex]::Match($summary, '(?m)^## 오늘 작업 제안')
    if ($m.Success) {
        $suggest = $summary.Substring($m.Index).Trim()
        $byDate = $summary.Substring(0, $m.Index)
        [IO.File]::WriteAllText((Join-Path $logDir "$Today.suggest.md"), $suggest, (New-Object Text.UTF8Encoding $false))
    }
    # "### YYYY-MM-DD" 단위로 나눠 날짜별 파일에 저장
    foreach ($part in [regex]::Split($byDate, '(?m)^(?=### \d{4}-\d{2}-\d{2})')) {
        if ($part -match '^### (\d{4}-\d{2}-\d{2})') {
            [IO.File]::WriteAllText((Join-Path $logDir "$($Matches[1]).md"), $part.Trim(), (New-Object Text.UTF8Encoding $false))
        }
    }
    $msg = "📅 지난 작업 요약 ($dateLabel)`n`n$summary`n`n($longNote)"
    $ctx = "이전 작업일($dateLabel) 요약과 오늘 작업 제안입니다. 사용자가 이어서 작업할 때 참고하세요.`n`n$summary"
    Write-HookOutput $msg $ctx
} else {
    $ctx = "이전 작업일($dateLabel)의 작업 기록입니다. 이번 세션의 첫 응답 맨 앞에서 날짜별로 중요한 작업 순서대로 최대 3개와 결정 사항·남은 일을 한국어로 짧게 요약하고, 그 아래에 근거를 붙인 '오늘 작업 제안' 1~3개를 보여주세요. 날짜별 요약은 .claude/daily-logs/<날짜>.md 에 저장하세요.`n`n$rawText"
    Write-HookOutput "📅 지난 작업 기록($dateLabel)을 불러왔습니다. 첫 메시지를 보내면 요약해 드립니다." $ctx
}
exit 0
