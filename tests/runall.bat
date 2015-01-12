@ECHO off
REM This suite requires https://github.com/inkarkat/runVimTests to run

if %1.==clean. goto Clean
if %1.==run. goto Run

echo "usage: runall.bat clean|run"
goto End


:Clean
echo Cleaning
del /Q *.out 2> nul
del /Q *.msgout 2> nul
goto End

:Run
echo Running
../../runVimTests/bin/runVimTests.cmd --pure vimgrep.suite
goto End

:End
