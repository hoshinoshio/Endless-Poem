$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$candidates = @((Join-Path $gameRoot 'Godot.exe'), (Join-Path $env:USERPROFILE 'Godot\Godot.exe'), (Join-Path $env:USERPROFILE 'Godot_v4.7.2-stable_win64.exe\Godot.exe'), 'C:\Program Files\Godot\Godot.exe')
$engine = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $engine) { $command = Get-Command godot.exe -ErrorAction SilentlyContinue; if ($command) { $engine = $command.Source } }
if (-not $engine) { throw 'Godot executable unavailable.' }
Start-Process -FilePath $engine -ArgumentList @('--path', ('"' + $gameRoot + '"'), 'res://scenes/previews/pixel_motion_preview.tscn') -WorkingDirectory $gameRoot -WindowStyle Hidden
