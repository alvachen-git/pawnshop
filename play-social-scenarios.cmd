@echo off
echo 1. Military contact
echo 2. Closure order
echo 3. Special supply
echo 4. Ownership claim
echo 5. Good reputation
echo 6. Poor reputation
choice /C 123456 /N /M "Choose scenario [1-6]: "
set "socialStage=preparation"
if errorlevel 2 set "socialStage=closure"
if errorlevel 3 set "socialStage=supply"
if errorlevel 4 set "socialStage=claim"
if errorlevel 5 set "socialStage=respected"
if errorlevel 6 set "socialStage=disliked"
call "%~dp0play-social-relations.cmd" -Stage %socialStage%
