param([int]$TimeoutSeconds = 180)
# Runs every tests/*.gd headless and prints one PASS/FAIL line per test.
$gameRoot = Split-Path -Parent $PSScriptRoot
$failed = @()
Get-ChildItem -LiteralPath (Join-Path $gameRoot 'tests') -Filter '*.gd' | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    # Tests that refuse the headless display server need a real window.
    $render = Select-String -LiteralPath $_.FullName -Pattern 'DisplayServer.get_name\(\) == "headless"' -Quiet
    $output = & (Join-Path $PSScriptRoot 'run_godot.ps1') -Script ("res://tests/" + $_.Name) -LogName ("test_" + $name) -TimeoutSeconds $TimeoutSeconds -Render:$render
    $code = $LASTEXITCODE
    $failLines = $output | Where-Object { $_ -match '^FAIL|SCRIPT ERROR|^ERROR:|GODOT_TIMEOUT' }
    if ($code -ne 0 -or $failLines) {
        $failed += $name
        Write-Output "FAIL $name (exit $code)"
        $failLines | Select-Object -First 8 | ForEach-Object { Write-Output "    $_" }
    } else {
        Write-Output "PASS $name"
    }
}
Write-Output ("{0} failed" -f $failed.Count)
if ($failed.Count -gt 0) { exit 1 }
