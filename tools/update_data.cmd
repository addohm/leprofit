@echo off
rem Refresh leProfit's built-in data from Forever's game data and what leProfit recorded in your
rem game: double-click it, or run it from a terminal. It runs tools\update_data.py, which asks
rem before each change. Needs Python 3 (python.org) and git.
setlocal
set "PY="
where py >nul 2>&1 && set "PY=py -3"
if not defined PY where python >nul 2>&1 && set "PY=python"
if not defined PY (
  echo Python 3 isn't installed. Get it from https://www.python.org/downloads/ and run this again.
  pause
  exit /b 1
)
rem All on one line: if the update pulls a new copy of this file, cmd doesn't read on into it.
%PY% "%~dp0update_data.py" & pause & exit /b
