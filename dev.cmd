@echo off
rem Dev server launcher. Uses the bundled Node 16 runtime in .tools\node-v16.20.2-win-x64
rem Why: this project runs on Vue CLI 4 / webpack 4, which crashes on Node 17+
rem with "ERR_OSSL_EVP_UNSUPPORTED" (md4 hash removed by OpenSSL 3).
setlocal
cd /d "%~dp0"
set "PATH=%~dp0.tools\node-v16.20.2-win-x64;%PATH%"
node -v
call npm run dev %*
