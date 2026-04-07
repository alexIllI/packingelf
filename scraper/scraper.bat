@echo off
REM PackingElf Scraper — convenience wrapper
REM Usage (from the scraper\ directory):
REM   scraper.bat scrape --order PG02491384 --manual-login
REM   scraper.bat scrape --order PG02491384 --account "子午計畫"
REM   scraper.bat account add --username "子午計畫"
REM   scraper.bat account list
"%~dp0.venv\Scripts\python.exe" -m src %*
