@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "SCRIPT=%ROOT%scripts\seed_firestore.py"
set "GOOGLE_SERVICES_JSON=%ROOT%communityshare_app\android\app\google-services.json"
set "SERVICE_ACCOUNT=%ROOT%communityshare_app\serviceAccountKey.json"

if not exist "%SCRIPT%" (
  echo Missing script: %SCRIPT%
  exit /b 1
)

if not exist "%GOOGLE_SERVICES_JSON%" (
  echo Missing Firebase config: %GOOGLE_SERVICES_JSON%
  exit /b 1
)

if not exist "%SERVICE_ACCOUNT%" (
  echo Missing service account JSON: %SERVICE_ACCOUNT%
  echo Download the Firebase Admin SDK service account key and place it there.
  exit /b 1
)

python "%SCRIPT%" --service-account "%SERVICE_ACCOUNT%" --google-services-json "%GOOGLE_SERVICES_JSON%"
set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%
