param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$engineCandidates = @(
    (Join-Path $gameRoot 'Godot.exe'),
    (Join-Path $env:USERPROFILE 'Godot\Godot.exe'),
    (Join-Path $env:USERPROFILE 'Godot_v4.7.2-stable_win64.exe\Godot.exe'),
    'C:\Program Files\Godot\Godot.exe'
)
$enginePath = $engineCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $enginePath) {
    $engineCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($engineCommand) { $enginePath = $engineCommand.Source }
}
if (-not $enginePath) {
    throw '找不到 Godot 4.7 程序。请用 Godot 打开此目录中的 project.godot，或将 Godot.exe 放入本目录。'
}
if ($CheckOnly) {
    Write-Output "Godot: $enginePath"
    & $enginePath --version
    exit $LASTEXITCODE
}
$quotedGameRoot = '"' + $gameRoot + '"'
if (-not (Test-Path -LiteralPath (Join-Path $gameRoot '.godot\imported'))) {
    Write-Output '首次启动：正在导入项目资源。'
    $importProcess = Start-Process -FilePath $enginePath -ArgumentList @('--headless', '--path', $quotedGameRoot, '--import') -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru
    if (-not $importProcess.WaitForExit(120000)) {
        $importProcess.Kill()
        throw '资源导入超时。请在 Godot 工程管理器中打开 project.godot 查看导入信息。'
    }
    if ($importProcess.ExitCode -ne 0) { throw '资源导入失败，请在 Godot 中打开本工程检查。' }
}
# The user launched this entry point to play, so show the interactive game window.
Start-Process -FilePath $enginePath -ArgumentList @('--path', $quotedGameRoot) -WorkingDirectory $gameRoot -WindowStyle Normal | Out-Null
