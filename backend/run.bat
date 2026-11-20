@echo off
REM Windows дээр backend асаах
cd /d %~dp0
if not exist .venv (
  python -m venv .venv
  .venv\Scripts\pip install -r requirements.txt
)
echo API: http://localhost:8000/docs
echo Utasnaas handah bol "ipconfig" komandaar IPv4 hayagaa harj, http://IP:8000 gej oruulna.
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
