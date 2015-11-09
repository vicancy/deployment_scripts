@ECHO OFF

SETLOCAL
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

IF NOT DEFINED BRANCH_ROOT SET BRANCH_ROOT=%~dp0..

SET ARGC=1
FOR %%X IN (%*) DO (
    SET /A ARGC+=1
)

IF NOT "%ARGC%" == "5" (
    ECHO Usage: "%~f0" ^<drop folder^> ^<website name^> ^<deploy user name^> ^<deploy password^> 1>&2
    SET ERRORLEVEL=-1
    GOTO EXIT
)

ECHO EXECUTING "%~f0" %1 %2 %3 %4

SET GIT_EXE=git.exe

WHERE %GIT_EXE%
IF NOT '%ERRORLEVEL%'=='0' (
    SET GIT_EXE="C:/Program Files (x86)/Git/cmd/git.exe"
    IF EXIST !GIT_EXE! (
        SET ERRORLEVEL=0
    ) ELSE (
        ECHO Unable to find git.exe in PATH or !GIT_EXE!
        SET ERRORLEVEL=-1
        GOTO EXIT
    )
)

SET DEPLOYMENT_ROOT=%1

SET WEBSITE_NAME=%2
SET USERNAME=%3
SET PASSWORD=%4

SET GIT_FOLDER_NAME=GIT_%WEBSITE_NAME%
SET GIT_ROOT=%DEPLOYMENT_ROOT%/%GIT_FOLDER_NAME%
SET BIT_ROOT=%DEPLOYMENT_ROOT%/%WEBSITE_NAME%
SET GIT_REPOSITORY_NAME=https://%USERNAME%:%PASSWORD%@%WEBSITE_NAME%.scm.azurewebsites.net:443/%WEBSITE_NAME%.git

ECHO INIT GIT REPOSITORY %WEBSITE_NAME% IN %BIT_ROOT% UNDER %GIT_ROOT%

FOR /F "delims=" %%X IN ('%GIT_EXE% describe --abbrev^=10') DO (
    SET DEPLOYMENT_VERSION=%%X
)

FOR /F "delims=" %%X IN ('%GIT_EXE% --no-pager show -s --format^=[%%ai]%%ae:%%s') DO (
    SET DEPLOYMENT_DETAIL=%%X
)

IF EXIST "%GIT_ROOT%\.git" (
    ECHO Deploy from %BIT_ROOT% to %GIT_ROOT%
) ELSE (
    PUSHD "%DEPLOYMENT_ROOT%"
    %GIT_EXE% clone %GIT_REPOSITORY_NAME% %GIT_ROOT%
    IF NOT '!ERRORLEVEL!'=='0' (
        GOTO EXIT
    )
    REM git add folder/ to fake git submodule incase %GIT_ROOT% is inside a GIT repository already
    %GIT_EXE% add %GIT_ROOT%/ >NUL 2>&1

    POPD
)

PUSHD "%GIT_ROOT%"
IF NOT '%ERRORLEVEL%'=='0' (
    GOTO EXIT
)
%GIT_EXE% reset . >NUL 2>&1
%GIT_EXE% checkout . >NUL 2>&1
%GIT_EXE% pull
FOR /F %%X IN ('DIR /A /AD /B') DO (
    IF NOT "%%X" == ".git" (
        DEL /F /S /Q "%%X" > NUL
        RMDIR /S /Q "%%X"
    )
)
FOR /F %%X IN ('DIR /A /A-D /B') DO (
    DEL /A "%%X"
)

robocopy.exe "%BIT_ROOT%" "%GIT_ROOT%" /S
ECHO {> "%GIT_ROOT%\version.js"
ECHO   "version": "%DEPLOYMENT_VERSION%",>> "%GIT_ROOT%\version.js"
ECHO   "detail": "%DEPLOYMENT_DETAIL%">> "%GIT_ROOT%\version.js"
ECHO }>> "%GIT_ROOT%\version.js"
%GIT_EXE% add . --all --force
%GIT_EXE% config user.name %USERNAME%
%GIT_EXE% config user.email %USERNAME%@microsoft.com
%GIT_EXE% commit -m "Deploy %DEPLOYMENT_VERSION%"
%GIT_EXE% push origin master

IF NOT '%ERRORLEVEL%'=='0' (
    GOTO EXIT
)

POPD

:EXIT
EXIT /B %ERRORLEVEL%