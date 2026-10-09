<#
Run: .\Test-CommandFix.ps1
Optional: .\Test-CommandFix.ps1 -Repeat 3
Place this script alongside the updated CommandFix.ps1.
Executes only the curated read-only inputs below in a private temporary folder.
Never executes model suggestions. No y/N prompts.
Writes a timestamped CSV beside this script. Each case runs once by default.
PASS means the suggestion matches an explicitly accepted answer, not proof of
universal correctness. Quote/alias variants outside the answer list can FAIL.
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 10)][int]$Repeat = 1,
    [string]$Model = 'qwen2.5-coder:3b'
)

$source = Join-Path $PSScriptRoot 'CommandFix.ps1'
if (!(Test-Path -LiteralPath $source)) { throw 'Place CommandFix.ps1 next to this test script.' }
. $source
if (!(Get-Command Get-FixSuggestion -ErrorAction SilentlyContinue)) {
    throw 'Download the updated CommandFix.ps1 first; Get-FixSuggestion is missing.'
}
try {
    $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10
} catch { throw 'Cannot connect to local Ollama. Open Ollama and try again.' }
if ($Model -notin @($tags.models | ForEach-Object { $_.name })) {
    throw "Model is not downloaded. Run: ollama pull $Model"
}

# Fixed fixtures make results independent of the user's current directory.
$cases = @(
    @{ Name = 'Command: listing'; Input = 'Get-ChlidItem'; Expected = @('Get-ChildItem') },
    @{ Name = 'Command: location'; Input = 'Get-Locaiton'; Expected = @('Get-Location') },
    @{ Name = 'Command with path'; Input = 'Test-Paht .\CommandFix.ps1'; Expected = @('Test-Path .\CommandFix.ps1') },
    @{ Name = 'Filename: candidate'; Input = 'Get-Content .\CommandFxi.ps1 -TotalCount 5'; Candidate = 'CommandFix.ps1'; Suffix = ' -TotalCount 5' },
    @{ Name = 'Parameter: TotalCount'; Input = 'Get-Content .\CommandFix.ps1 -TotalCont 5'; Expected = @('Get-Content .\CommandFix.ps1 -TotalCount 5') },
    @{ Name = 'Parameter: LiteralPath'; Input = 'Get-Content -LiteralPaht .\CommandFix.ps1 -TotalCount 5'; Expected = @('Get-Content -LiteralPath .\CommandFix.ps1 -TotalCount 5') },
    @{ Name = 'Path with spaces: candidate'; Input = 'Get-Content ".\sample ntoes.txt" -TotalCount 2'; Candidate = 'sample notes.txt'; Suffix = ' -TotalCount 2' },
    @{ Name = 'Missing file: selection required'; Input = 'Get-Content .\unavailable_document_92847.txt'; SelectionOnly = $true },
    @{ Name = 'Correct: reading'; Input = 'Get-Content .\CommandFix.ps1 -TotalCount 5'; Success = $true },
    @{ Name = 'Correct: exists'; Input = 'Test-Path .\CommandFix.ps1'; Success = $true }
)

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('CommandFix-Test-' + [guid]::NewGuid().ToString('N'))
$oldModel = $env:COMMAND_FIX_MODEL
$rows = New-Object 'System.Collections.Generic.List[object]'
$pushed = $false
try {
    $null = New-Item -ItemType Directory -Path $fixture -ErrorAction Stop
    Copy-Item -LiteralPath $source -Destination (Join-Path $fixture 'CommandFix.ps1') -ErrorAction Stop
    Set-Content -LiteralPath (Join-Path $fixture 'sample notes.txt') -Value @('line one', 'line two', 'line three') -Encoding UTF8
    $null = New-Item -ItemType Directory -Path (Join-Path $fixture 'child')
    Set-Content -LiteralPath (Join-Path $fixture 'child\unavailable_document_92847.txt') -Value 'Do not search subdirectories.'
    Push-Location -LiteralPath $fixture -ErrorAction Stop
    $pushed = $true
    $env:COMMAND_FIX_MODEL = $Model
    for ($round = 1; $round -le $Repeat; $round++) {
        foreach ($case in $cases) {
            Write-Host "`n[$round/$Repeat] $($case.Name)" -ForegroundColor Cyan
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $status = 'FAIL'; $actual = ''; $reason = ''; $errorText = ''
            $stage = 'Input'; $modelCalled = $false
            try {
                $original = Invoke-FixCommand -Text $case.Input
                if ($case.Success) {
                    # Exercise the actual fix success branch; any model call fails.
                    $stage = 'Success branch'
                    $savedFunction = (Get-Item Function:Get-FixSuggestion).ScriptBlock
                    try {
                        function Get-FixSuggestion { throw 'Unexpected model call on a correct command.' }
                        # fix handles errors internally, so inspect its host messages too.
                        $messages = @(fix $case.Input 6>&1)
                        $unexpected = ($messages | Out-String) -match 'Suggestion unavailable|Unexpected model call'
                        if ($original.Success -and !$unexpected) { $status = 'PASS' }
                        $actual = 'Successful execution; model not called'
                    } finally {
                        Set-Item Function:Get-FixSuggestion -Value $savedFunction
                    }
                } else {
                    if ($original.Success) { throw 'Input unexpectedly succeeded; no error to repair.' }
                    $stage = 'Suggestion'; $modelCalled = $true
                    $suggestion = Get-FixSuggestion -Command $case.Input -Output $original.Output
                    $actual = $suggestion.Command
                    $reason = $suggestion.Reason
                    $modelCalled = !$suggestion.RequiresSelection
                    if ($case.Candidate -or $case.SelectionOnly) {
                        $candidates = @($suggestion.Candidates)
                        $valid = $suggestion.RequiresSelection -and !$actual -and
                            $candidates.Count -gt 0 -and $candidates.Count -le 3
                        foreach ($candidate in $candidates) {
                            $valid = $valid -and (Test-Path -LiteralPath $candidate.FullName -PathType Leaf) -and
                                (Split-Path -Path $candidate.FullName -Parent) -eq $fixture
                        }
                        if ($case.Candidate) {
                            $valid = $valid -and $candidates[0].Name -eq $case.Candidate -and
                                $candidates[0].Command.EndsWith($case.Suffix)
                            $parsedPath = Get-FixReadPath -Text $candidates[0].Command
                            $valid = $valid -and $parsedPath -eq (Join-Path $fixture $case.Candidate)
                        }
                        if ($valid) { $status = 'PASS' }
                        $actual = 'Selection required: ' + (($candidates | ForEach-Object { $_.Name }) -join ', ')
                    } else {
                    # Ignore letter case and outer whitespace only; preserve arguments.
                    if ($actual.Trim() -in $case.Expected) { $status = 'PASS' }
                    }
                }
            } catch {
                $errorText = $_.Exception.Message
                if ($stage -eq 'Input') { $status = 'ERROR' }
            }
            $watch.Stop()
            $expected = if ($case.Success) { 'Success without model' } else { $case.Expected -join ' OR ' }
            if ($case.Candidate) { $expected = 'First candidate: ' + $case.Candidate + '; no execution before selection' }
            if ($case.SelectionOnly) { $expected = 'Current-folder candidates only; selection required, no automatic repair' }
            if (!$case.Success -and $case.Expected.Count -eq 1 -and !$case.Expected[0]) { $expected = '(no suggestion)' }
            $rows.Add([pscustomobject]@{
                Round = $round; Case = $case.Name; Status = $status; Input = $case.Input
                Expected = $expected; Actual = $actual; Reason = $reason; Error = $errorText
                ModelCalled = $modelCalled; Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 2); Model = $Model
            })
            $color = if ($status -eq 'PASS') { 'Green' } else { 'Yellow' }
            Write-Host "$status : $($case.Name)" -ForegroundColor $color
            if ($status -ne 'PASS') {
                Write-Host "  Expected: $expected"
                Write-Host "  Actual  : $actual"
                if ($errorText) { Write-Host "  Error   : $errorText" }
            }
        }
    }
    # Boundary tests for search limits; these do not call the model.
    $cap = Find-FixFiles -TargetName 'CommandFxi.ps1' -MaxFiles 1 -TimeoutSeconds 5
    $capStatus = if ($cap.Scanned -eq 1 -and $cap.Limited -and !$cap.Error) { 'PASS' } else { 'FAIL' }
    $rows.Add([pscustomobject]@{
        Round = 1; Case = 'Search: file cap'; Status = $capStatus; Input = 'MaxFiles=1'
        Expected = 'Scan at most one file, report incomplete'; Actual = "Scanned=$($cap.Scanned), Limited=$($cap.Limited)"
        Reason = ''; Error = $cap.Error; ModelCalled = $false; Seconds = 0; Model = $Model
    })
    $savedDistance = (Get-Item Function:Get-FixNameDistance).ScriptBlock
    $timeoutWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # The copied worker function deliberately stalls; the parent must stop waiting.
        function Get-FixNameDistance { param($Left, $Right) Start-Sleep -Seconds 5; return 0 }
        $timeoutResult = Find-FixFiles -TargetName 'anything.txt' -TimeoutSeconds 1
    } finally { Set-Item Function:Get-FixNameDistance -Value $savedDistance }
    $timeoutWatch.Stop()
    $timeoutStatus = if ($timeoutResult.TimedOut -and $timeoutWatch.Elapsed.TotalSeconds -lt 3) { 'PASS' } else { 'FAIL' }
    $rows.Add([pscustomobject]@{
        Round = 1; Case = 'Search: worker timeout'; Status = $timeoutStatus; Input = 'Stalled worker, TimeoutSeconds=1'
        Expected = 'Return timeout, do not wait for 5-second stall'; Actual = "TimedOut=$($timeoutResult.TimedOut)"
        Reason = ''; Error = ''; ModelCalled = $false; Seconds = [math]::Round($timeoutWatch.Elapsed.TotalSeconds, 2); Model = $Model
    })
} finally {
    $env:COMMAND_FIX_MODEL = $oldModel
    if ($pushed) { Pop-Location }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
$report = Join-Path $PSScriptRoot ('CommandFix-results-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')
$rows | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8
$passed = @($rows | Where-Object { $_.Status -eq 'PASS' }).Count
Write-Host "`nPassed: $passed / $($rows.Count)"
Write-Host "Report: $report"
Write-Host 'Suggestions were compared only; none were executed.'
# Return structured results for further analysis, without closing your terminal.
$rows | Format-Table Round, Case, Status, Seconds -AutoSize
