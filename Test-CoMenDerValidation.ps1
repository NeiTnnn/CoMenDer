<#
Run from your project: .\Test-CoMenDerValidation.ps1
Compare another downloaded model:
  .\Test-CoMenDerValidation.ps1 -Model 'qwen2.5-coder:1.5b'
Repeat the entire set:
  .\Test-CoMenDerValidation.ps1 -Repeat 3

Place alongside your existing CommandFix.ps1. Requires the candidate-selection
version (Get-FixSuggestion, Get-FixReadPath, Find-FixFiles).
Only curated original inputs run, in a new temporary folder for EACH case.
No model suggestions or candidate commands execute. Git operations stay local;
pip is only queried, never used to install packages. Missing Git/Python/pip cases
are SKIP, not PASS. CSV includes exact expected/actual results and errors.
This is a small fixed validation suite, not a general accuracy benchmark.
#>
[CmdletBinding()]
param(
    [string]$Model = 'qwen2.5-coder:3b',
    [ValidateRange(1, 10)][int]$Repeat = 1
)

$source = Join-Path $PSScriptRoot 'CommandFix.ps1'
if (!(Test-Path -LiteralPath $source)) { throw 'Place this script alongside CommandFix.ps1.' }
. $source
foreach ($name in @('Get-FixSuggestion', 'Get-FixReadPath', 'Find-FixFiles', 'Invoke-FixCommand')) {
    if (!(Get-Command $name -ErrorAction SilentlyContinue)) { throw "Updated core required: $name is missing." }
}
try { $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5 }
catch { throw 'Open local Ollama before running this suite.' }
if ($Model -notin @($tags.models | ForEach-Object { $_.name })) { throw "Download the model first: ollama pull $Model" }

# 10 command-name typos, 10 parameter typos, 10 file/candidate cases,
# 5 correct commands, 5 cases requiring explicit selection or abstention.
$cases = @(
    @{ Id='C01'; Group='Command'; Input='Get-Locaiton'; Expected=@('Get-Location') },
    @{ Id='C02'; Group='Command'; Input='Get-ChlidItem'; Expected=@('Get-ChildItem') },
    @{ Id='C03'; Group='Command'; Input='Get-Contnet .\notes.txt -TotalCount 2'; Expected=@('Get-Content .\notes.txt -TotalCount 2') },
    @{ Id='C04'; Group='Command'; Input='Test-Paht .\notes.txt'; Expected=@('Test-Path .\notes.txt') },
    @{ Id='C05'; Group='Command'; Input='New-Itme -ItemType Directory -Path .\new-folder'; Expected=@('New-Item -ItemType Directory -Path .\new-folder') },
    @{ Id='C06'; Group='Command'; Input='Copy-Itme .\notes.txt .\copy.txt'; Expected=@('Copy-Item .\notes.txt .\copy.txt') },
    @{ Id='C07'; Group='Command'; Input='Move-Itme .\move-source.txt .\moved.txt'; Expected=@('Move-Item .\move-source.txt .\moved.txt') },
    @{ Id='C08'; Group='Command'; Input='Rename-Itme .\rename-source.txt renamed.txt'; Expected=@('Rename-Item .\rename-source.txt renamed.txt') },
    @{ Id='C09'; Group='Command'; Need='Git'; Input='git statsu'; Expected=@('git status') },
    @{ Id='C10'; Group='Command'; Need='Git'; Input='git lg'; Expected=@('git log') },

    @{ Id='P01'; Group='Parameter'; Input='Get-Content .\notes.txt -TotalCont 2'; Expected=@('Get-Content .\notes.txt -TotalCount 2') },
    @{ Id='P02'; Group='Parameter'; Input='Get-Content -LiteralPaht .\notes.txt -TotalCount 2'; Expected=@('Get-Content -LiteralPath .\notes.txt -TotalCount 2') },
    @{ Id='P03'; Group='Parameter'; Input='Get-ChildItem -Paht .'; Expected=@('Get-ChildItem -Path .') },
    @{ Id='P04'; Group='Parameter'; Input='Get-ChildItem -Recusre'; Expected=@('Get-ChildItem -Recurse') },
    @{ Id='P05'; Group='Parameter'; Input='New-Item -ItemTypo Directory -Path .\new-folder'; Expected=@('New-Item -ItemType Directory -Path .\new-folder') },
    @{ Id='P06'; Group='Parameter'; Input='Copy-Item .\notes.txt -Destinaton .\copy.txt'; Expected=@('Copy-Item .\notes.txt -Destination .\copy.txt') },
    @{ Id='P07'; Group='Parameter'; Input='Move-Item .\move-source.txt -Destinaton .\moved.txt'; Expected=@('Move-Item .\move-source.txt -Destination .\moved.txt') },
    @{ Id='P08'; Group='Parameter'; Input='Rename-Item .\rename-source.txt -NewNmae renamed.txt'; Expected=@('Rename-Item .\rename-source.txt -NewName renamed.txt') },
    @{ Id='P09'; Group='Parameter'; Need='Python'; Input='python --versoin'; Expected=@('python --version') },
    @{ Id='P10'; Group='Parameter'; Need='Pip'; Input='pip --versoin'; Expected=@('pip --version') },

    @{ Id='F01'; Group='Files'; Input='Get-Content .\ntoes.txt -TotalCount 2'; File='notes.txt'; Suffix=' -TotalCount 2' },
    @{ Id='F02'; Group='Files'; Input='Get-Content .\note.txt'; File='notes.txt'; Suffix='' },
    @{ Id='F03'; Group='Files'; Input='Get-Content .\notes.tx'; File='notes.txt'; Suffix='' },
    @{ Id='F04'; Group='Files'; Input='Get-Content ".\sample ntoes.txt" -TotalCount 2'; File='sample notes.txt'; Suffix=' -TotalCount 2' },
    @{ Id='F05'; Group='Files'; Input="Get-Content '.\sample note.txt'"; File='sample notes.txt'; Suffix='' },
    @{ Id='F06'; Group='Files'; Input='Get-Content -LiteralPath .\meting.txt'; File='meeting.txt'; Suffix='' },
    @{ Id='F07'; Group='Files'; Input='Get-Content .\report-2026.tx -TotalCount 1'; File='report-2026.txt'; Suffix=' -TotalCount 1' },
    @{ Id='F08'; Group='Files'; Input='Get-Content .\settings.jsno'; File='settings.json'; Suffix='' },
    @{ Id='F09'; Group='Files'; Input='Get-Content .\data03.txt'; AnyFiles=@('data01.txt','data02.txt'); Suffix='' },
    @{ Id='F10'; Group='Files'; Input='Get-Content .\missing-folder\notes.txt -TotalCount 2'; File='notes.txt'; Suffix=' -TotalCount 2' },

    @{ Id='O01'; Group='Correct'; Input='Get-Location'; Success=$true },
    @{ Id='O02'; Group='Correct'; Input='Get-ChildItem'; Success=$true },
    @{ Id='O03'; Group='Correct'; Input='Get-Content .\notes.txt -TotalCount 2'; Success=$true },
    @{ Id='O04'; Group='Correct'; Need='Git'; Input='git status'; Success=$true },
    @{ Id='O05'; Group='Correct'; Need='Python'; Input='python --version'; Success=$true },

    @{ Id='N01'; Group='NoGuess'; Input='Get-Content .\unavailable_document_92847.txt'; SelectionOnly=$true },
    @{ Id='N02'; Group='NoGuess'; Input='Get-CoMenDerNonexistentThing92847'; Expected=@('') },
    @{ Id='N03'; Group='NoGuess'; Input='Get-Content .\notes.txt -TotalCount banana'; Expected=@('') },
    @{ Id='N04'; Group='NoGuess'; Need='Python'; Input='python .\unavailable_script_92847.py'; Expected=@('') },
    @{ Id='N05'; Group='NoGuess'; Need='Pip'; Input='pip show comender_missing_package_92847'; Expected=@('') }
)

function Test-CoMenDerDependency {
    param([string]$Name)
    if (!$Name) { return $true }
    $exe = switch ($Name) { 'Git' { 'git' }; 'Python' { 'python' }; 'Pip' { 'pip' } }
    if (!(Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue)) { return $false }
    try {
        $null = & $exe --version 2>&1
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

function Get-CoMenDerExpectedText {
    param($Case)
    if ($Case.Success) { return 'Execute successfully, without calling the model' }
    if ($Case.File) { return 'Selection required; first candidate=' + $Case.File + '; arguments preserved' }
    if ($Case.AnyFiles) { return 'Selection required; both data01.txt and data02.txt listed' }
    if ($Case.SelectionOnly) { return 'Current-folder candidates only; no correction before selection' }
    if ($Case.Expected.Count -eq 1 -and !$Case.Expected[0]) { return 'No suggested command; do not invent intent' }
    $Case.Expected -join ' OR '
}

# Compare parsed tokens rather than whitespace. Accept quoting a literal path,
# but do not fold variable expressions, aliases, added flags or extra commands.
function Get-CoMenDerCommandSignature {
    param([string]$Text)
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { return '!invalid!' }
    $parts = @($tokens | Where-Object { $_.Kind -notin @('EndOfInput','NewLine','Comment') } | ForEach-Object {
        if ($_.Kind -eq 'StringLiteral' -or ($_.Kind -eq 'StringExpandable' -and $_.Text -notmatch '[$`]')) { 'literal:' + $_.Value.ToLowerInvariant() }
        elseif ($_.Kind -eq 'Generic' -and $_.Text -notmatch '[$`]' ) { 'literal:' + $_.Text.ToLowerInvariant() }
        else { $_.Kind.ToString() + ':' + $_.Text.ToLowerInvariant() }
    })
    $parts -join '|'
}

$dependencies = @{ Git=(Test-CoMenDerDependency Git); Python=(Test-CoMenDerDependency Python); Pip=(Test-CoMenDerDependency Pip) }
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('CoMenDer-Validation-' + [guid]::NewGuid().ToString('N'))
$oldModel = $env:COMMAND_FIX_MODEL
$rows = New-Object 'System.Collections.Generic.List[object]'
$stopRequested = $false
$null = New-Item -ItemType Directory -Path $root
try {
    $env:COMMAND_FIX_MODEL = $Model
    for ($round=1; $round -le $Repeat -and !$stopRequested; $round++) {
        foreach ($case in $cases) {
            $expected = Get-CoMenDerExpectedText $case
            $status='FAIL'; $actual=''; $reason=''; $errorText=''; $modelAttempted=$false
            $stage='Setup'; $pushed=$false
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            Write-Host "`n[$round/$Repeat] $($case.Id) $($case.Group): $($case.Input)" -ForegroundColor Cyan
            try {
                if ($case.Need -and !$dependencies[$case.Need]) {
                    $status='SKIP'; $reason='Unavailable dependency: ' + $case.Need
                } else {
                    $folder = Join-Path $root ("r{0}-{1}" -f $round,$case.Id)
                    $null = New-Item -ItemType Directory -Path $folder
                    foreach ($name in @('notes.txt','sample notes.txt','meeting.txt','report-2026.txt','settings.json','data01.txt','data02.txt','move-source.txt','rename-source.txt')) {
                        Set-Content -LiteralPath (Join-Path $folder $name) -Value @('fixture line one','fixture line two') -Encoding UTF8
                    }
                    $null = New-Item -ItemType Directory -Path (Join-Path $folder 'child')
                    Set-Content -LiteralPath (Join-Path $folder 'child\unavailable_document_92847.txt') -Value 'Never search subdirectories.'
                    Push-Location -LiteralPath $folder
                    $pushed=$true
                    if ($case.Need -eq 'Git') {
                        $null = & git -c init.defaultBranch=main init --template= . 2>&1
                        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the temporary Git repository.' }
                        $hooks = Join-Path $folder '.empty-hooks'
                        $null = New-Item -ItemType Directory -Path $hooks
                        $null = & git add -- notes.txt 2>&1
                        if ($LASTEXITCODE -ne 0) { throw 'Could not stage the local Git fixture.' }
                        $null = & git -c user.name=CoMenDerTest -c user.email=comender-test@example.invalid -c commit.gpgsign=false -c "core.hooksPath=$hooks" commit -m 'Local validation fixture' 2>&1
                        if ($LASTEXITCODE -ne 0) { throw 'Could not create the local Git fixture commit.' }
                    }
                    $stage='Input'
                    $original = Invoke-FixCommand -Text $case.Input
                    if ($case.Success) {
                        $stage='Correct branch'
                        # Verify the actual fix branch does not try to request a repair.
                        $saved = (Get-Item Function:Get-FixSuggestion).ScriptBlock
                        try {
                            function Get-FixSuggestion { throw 'Unexpected model request for a correct command.' }
                            $messages = @(fix $case.Input 6>&1)
                            $unexpected = ($messages | Out-String) -match 'Suggestion unavailable|Unexpected model request'
                            if ($original.Success -and !$unexpected) { $status='PASS' }
                            $actual='Successful=' + $original.Success + '; unexpected repair=' + $unexpected
                        } finally { Set-Item Function:Get-FixSuggestion -Value $saved }
                    } else {
                        if ($original.Success) { throw 'Test input succeeded unexpectedly; not an error-repair case.' }
                        $stage='Suggestion'; $modelAttempted=$true
                        $suggestion = Get-FixSuggestion -Command $case.Input -Output $original.Output
                        $actual = $suggestion.Command; $reason=$suggestion.Reason
                        if ($suggestion.Cancelled) {
                            $status='CANCELLED'; $stopRequested=$true
                        } elseif ($case.File -or $case.AnyFiles -or $case.SelectionOnly) {
                            $modelAttempted=$false
                            $candidates=@($suggestion.Candidates)
                            $valid=$suggestion.RequiresSelection -and !$actual -and $candidates.Count -gt 0 -and $candidates.Count -le 3
                            foreach ($candidate in $candidates) {
                                $valid=$valid -and (Test-Path -LiteralPath $candidate.FullName -PathType Leaf) -and
                                    (Split-Path -Path $candidate.FullName -Parent) -eq $folder
                            }
                            if ($case.File) {
                                $valid=$valid -and $candidates[0].Name -eq $case.File
                                $parsedPath=Get-FixReadPath -Text $candidates[0].Command
                                $valid=$valid -and $parsedPath -eq (Join-Path $folder $case.File)
                                if ($case.Suffix) { $valid=$valid -and $candidates[0].Command.EndsWith($case.Suffix) }
                            }
                            if ($case.AnyFiles) {
                                foreach ($required in $case.AnyFiles) { $valid=$valid -and $required -in @($candidates | ForEach-Object { $_.Name }) }
                            }
                            if ($valid) { $status='PASS' }
                            $actual='Selection required=' + $suggestion.RequiresSelection + '; candidates=' + (($candidates | ForEach-Object { $_.Name }) -join ', ')
                        } else {
                            foreach ($answer in $case.Expected) {
                                if ((Get-CoMenDerCommandSignature $actual) -eq (Get-CoMenDerCommandSignature $answer)) { $status='PASS'; break }
                            }
                        }
                    }
                }
            } catch {
                $errorText=$_.Exception.Message
                if ($stage -in @('Setup','Input')) { $status='ERROR' }
                elseif ($errorText -match 'connection|connect|refused|exceeded|逾時|連線|連接') { $status='ERROR' }
                # Invalid model JSON / repeated failed command remain FAIL.
            } finally {
                $watch.Stop()
                if ($pushed) { Pop-Location }
            }
            $rows.Add([pscustomobject]@{
                Round=$round; Id=$case.Id; Group=$case.Group; Status=$status; Input=$case.Input
                Expected=$expected; Actual=$actual; Reason=$reason; Error=$errorText
                ModelRequestAttempted=$modelAttempted; Seconds=[math]::Round($watch.Elapsed.TotalSeconds,2); Model=$Model
            })
            $color=if ($status -eq 'PASS') { 'Green' } elseif ($status -eq 'SKIP') { 'DarkGray' } else { 'Yellow' }
            Write-Host "$status $($case.Id)" -ForegroundColor $color
            if ($status -ne 'PASS') {
                Write-Host "  Expected: $expected"
                Write-Host "  Actual: $actual"
                if ($reason) { Write-Host "  Reason: $reason" }
                if ($errorText) { Write-Host "  Error: $errorText" }
            }
            if ($stopRequested) { break }
        }
    }
} finally {
    $env:COMMAND_FIX_MODEL=$oldModel
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

$safeModel=$Model -replace '[^a-zA-Z0-9_.-]','_'
$report=Join-Path $PSScriptRoot ("CoMenDer-validation-{0}-{1}.csv" -f $safeModel,(Get-Date -Format 'yyyyMMdd-HHmmss'))
$rows | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8
Write-Host "`nResults by category" -ForegroundColor Cyan
$summary=@($rows | Group-Object Group | ForEach-Object {
    $items=$_.Group
    [pscustomobject]@{
        Group=$_.Name
        PASS=@($items | Where-Object Status -eq 'PASS').Count
        FAIL=@($items | Where-Object Status -eq 'FAIL').Count
        ERROR=@($items | Where-Object Status -eq 'ERROR').Count
        SKIP=@($items | Where-Object Status -eq 'SKIP').Count
        CANCELLED=@($items | Where-Object Status -eq 'CANCELLED').Count
    }
})
$summary | Format-Table -AutoSize
$passed=@($rows | Where-Object Status -eq 'PASS').Count
$failed=@($rows | Where-Object Status -eq 'FAIL').Count
Write-Host "PASS: $passed; FAIL: $failed; evaluated cases (PASS+FAIL): $($passed+$failed)"
Write-Host "Recorded: $($rows.Count) / $($cases.Count * $Repeat); SKIP/ERROR/CANCELLED do not count as passes."
Write-Host "CSV: $report"
Write-Host 'Elapsed times include original command and context/search work, not pure model inference.'
Write-Host 'No suggested commands or file selections were executed.'
