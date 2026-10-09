<#
CoMenDer: a local command-repair demo for Windows PowerShell 5.1 / PowerShell 7.
Launch from PowerShell: .\Start-CoMenDer.ps1
This is a dedicated command loop, not a hook into every existing PowerShell tab.
Supports simple cmdlets/external tools, directory changes and confirmed repairs.
Arbitrary variables/functions defined in a command do not persist across commands.
#>
[CmdletBinding()]
param(
    [string]$Model = 'qwen2.5-coder:3b',
    [string]$WorkingDirectory = ''
)

$core = Join-Path $PSScriptRoot 'CommandFix.ps1'
if (!(Test-Path -LiteralPath $core)) { throw 'CommandFix.ps1 is missing. Extract the complete ZIP first.' }
. $core
$savedModel = $env:COMMAND_FIX_MODEL
$startingLocation = Get-Location
$env:COMMAND_FIX_MODEL = $Model
if (!$WorkingDirectory) { $WorkingDirectory = Join-Path $PSScriptRoot 'demo' }

function Show-CoMenDerStatus {
    Write-Host "`nLocal model: $env:COMMAND_FIX_MODEL" -ForegroundColor Cyan
    try {
        $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3
        if ($env:COMMAND_FIX_MODEL -in @($tags.models | ForEach-Object { $_.name })) {
            Write-Host 'Ollama: ready. Inference stays on this computer.' -ForegroundColor Green
        } else {
            Write-Host "Model not downloaded. Run in another PowerShell: ollama pull $env:COMMAND_FIX_MODEL" -ForegroundColor Yellow
        }
    } catch {
        Write-Host 'Ollama is unavailable. Open Ollama to enable command repair.' -ForegroundColor Yellow
    }
    Write-Host ('Directory: ' + (Get-Location).Path)
    Write-Host 'Search: current folder only | 2s deadline | 5000 files | 3 candidates'
    Write-Host 'Model request: 30s timeout | Corrections always require confirmation'
}

function Show-CoMenDerHelp {
    Write-Host @'

Enter a command normally. CoMenDer runs it, then helps if it fails.
  /demo           Pick a built-in example (switches to the demo folder)
  /status         Check local model and current folder
  /models         List downloaded Ollama models
  /model NAME     Select a downloaded model
  /help           Show this help
  /clear          Clear the screen
  /exit           Return to ordinary PowerShell

Examples: Get-ChildItem | cd .. | Get-Content .\notes.txt
The original command executes immediately. Review every proposed correction.
This demo captures output, so avoid interactive tools or continuous output.
Use another normal PowerShell tab for installations and interactive programs.
'@ -ForegroundColor Gray
}

function Select-CoMenDerDemo {
    $examples = @(
        @{ Name = 'Command typo'; Command = 'Get-ChlidItem' },
        @{ Name = 'Filename typo'; Command = 'Get-Content .\ntoes.txt -TotalCount 2' },
        @{ Name = 'Parameter typo'; Command = 'Get-Content .\notes.txt -TotalCont 2' },
        @{ Name = 'Missing file: choose a candidate'; Command = 'Get-Content .\unavailable_document_92847.txt -TotalCount 2' },
        @{ Name = 'Correct command: no model call'; Command = 'Get-Content .\notes.txt -TotalCount 2' }
    )
    Write-Host "`nDemo cases" -ForegroundColor Cyan
    for ($i = 0; $i -lt $examples.Count; $i++) {
        Write-Host ('[{0}] {1}  > {2}' -f ($i + 1), $examples[$i].Name, $examples[$i].Command)
    }
    $choice = Read-Host 'Choose 1-5, or Enter to cancel'
    $index = 0
    if (![int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $examples.Count) { return }
    Set-Location -LiteralPath (Join-Path $PSScriptRoot 'demo') -ErrorAction Stop
    $examples[$index - 1].Command
}

try {
    Set-Location -LiteralPath $WorkingDirectory -ErrorAction Stop
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '  CoMenDer  |  Local AI Command Repair' -ForegroundColor White
    Write-Host '  Type. Repair. Confirm.' -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor Cyan
    Show-CoMenDerStatus
    Write-Host "`nStart with /demo, or enter a PowerShell command. /help shows options." -ForegroundColor White
    while ($true) {
        Write-Host ''
        Write-Host ('PS ' + (Get-Location).Path) -ForegroundColor DarkGray
        $line = Read-Host 'CoMenDer >'
        if ($null -eq $line) { break }
        $line = $line.Trim()
        if (!$line) { continue }
        if ($line -in @('/exit', 'exit')) { break }
        if ($line -eq '/help') { Show-CoMenDerHelp; continue }
        if ($line -eq '/clear') { Clear-Host; continue }
        if ($line -eq '/status') { Show-CoMenDerStatus; continue }
        if ($line -eq '/models') {
            try {
                $tags = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3
                $tags.models | Select-Object name, size | Format-Table -AutoSize | Out-Host
            } catch { Write-Host 'Open Ollama first.' -ForegroundColor Yellow }
            continue
        }
        if ($line -match '^/model\s+(.+)$') {
            $env:COMMAND_FIX_MODEL = $Matches[1].Trim()
            Show-CoMenDerStatus
            continue
        }
        if ($line -eq '/demo') {
            $line = Select-CoMenDerDemo
            if (!$line) { continue }
            Write-Host ('> ' + $line) -ForegroundColor White
        } elseif ($line.StartsWith('/')) {
            Write-Host 'Unknown shortcut. Try /help.' -ForegroundColor Yellow
            continue
        }
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try { fix $line }
        catch { Write-Host ('Stopped: ' + $_.Exception.Message) -ForegroundColor Yellow }
        $timer.Stop()
        Write-Host ('Completed in {0:N1}s (including confirmation time).' -f $timer.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    }
} finally {
    $env:COMMAND_FIX_MODEL = $savedModel
    Set-Location -LiteralPath $startingLocation.Path
    Write-Host 'CoMenDer closed. Back to PowerShell.' -ForegroundColor Cyan
}
