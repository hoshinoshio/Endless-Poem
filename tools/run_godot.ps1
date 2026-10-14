param(
    [string]$Script = '',
    [switch]$Import,
    [switch]$Render,
    [string]$LogName = 'godot_check',
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$engineCandidates = @(
    (Join-Path $gameRoot 'Godot.exe'),
    (Join-Path $env:USERPROFILE 'Godot\Godot.exe'),
    (Join-Path $env:USERPROFILE 'Godot_v4.7.2-stable_win64.exe\Godot.exe'),
    'C:\Program Files\Godot\Godot.exe'
)
$godotPath = $engineCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $godotPath) {
    $engineCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($engineCommand) { $godotPath = $engineCommand.Source }
}
if (-not $godotPath) {
    throw 'Godot executable unavailable. Open project.godot with Godot or put Godot.exe beside it.'
}
$logRoot = Join-Path $gameRoot 'logs'
[void][System.IO.Directory]::CreateDirectory($logRoot)
$safeLogName = $LogName -replace '[^a-zA-Z0-9_-]', '_'
$outPath = Join-Path $logRoot ($safeLogName + '_stdout.log')
$errPath = Join-Path $logRoot ($safeLogName + '_stderr.log')
$gameArguments = @('--path', ('"' + $gameRoot + '"'))
if (-not $Render) { $gameArguments += '--headless' }
if ($Import) {
    $gameArguments += '--import'
} elseif ($Script) {
    $gameArguments += @('--script', ('"' + $Script + '"'))
} else {
    $gameArguments += @('--quit-after', '60')
}
if ($Render) { $gameArguments += @('--resolution', '1440x900', '--position', '120,60') }
$windowStyle = 'Hidden'
$gameProcess = Start-Process -FilePath $godotPath -ArgumentList $gameArguments -WorkingDirectory $gameRoot -WindowStyle $windowStyle -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
if (-not $gameProcess.WaitForExit($TimeoutSeconds * 1000)) {
    $gameProcess.Kill()
    $gameProcess.WaitForExit()
    Write-Output "GODOT_TIMEOUT_SECONDS=$TimeoutSeconds"
    Get-Content -LiteralPath $outPath -Tail 60 -ErrorAction SilentlyContinue
    Get-Content -LiteralPath $errPath -Tail 30 -ErrorAction SilentlyContinue
    exit 124
}
$gameProcess.Refresh()
Write-Output "GODOT_EXIT_CODE=$($gameProcess.ExitCode)"
Get-Content -LiteralPath $outPath -Tail 100 -ErrorAction SilentlyContinue
Get-Content -LiteralPath $errPath -Tail 50 -ErrorAction SilentlyContinue
Write-Output "STDOUT_LOG=$outPath"
Write-Output "STDERR_LOG=$errPath"
$runtimeErrors = Select-String -LiteralPath $errPath -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet -ErrorAction SilentlyContinue
if ($runtimeErrors -and $gameProcess.ExitCode -eq 0) { exit 1 }
exit $gameProcess.ExitCode
