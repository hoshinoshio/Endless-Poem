@echo off
set "STAR_MAP_GODOT=%USERPROFILE%\Godot_v4.7.2-stable_win64.exe\Godot.exe"
if not exist "%STAR_MAP_GODOT%" (
  echo Godot executable was not found: "%STAR_MAP_GODOT%"
  pause
  exit /b 1
)
start "" "%STAR_MAP_GODOT%" --path "%~dp0..\.." "res://scenes/previews/cosmic_star_map.tscn"
