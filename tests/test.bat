@ECHO off
REM This suite requires https://github.com/inkarkat/runVimTests to run

set TEST_SOURCES=--pure --runtime bundle\vim-easygrep\autoload\EasyGrep.vim --runtime bundle\vim-easygrep\plugin\EasyGrep.vim

if %1.==clean. goto Clean
if %1.==run. goto Run
if %1.==runall. goto RunAll

echo "usage: test.bat clean|run|runall"
goto End


:Clean
echo Cleaning
del /Q *.out 2> nul
del /Q *.msgout 2> nul
goto End

:Run
shift
echo Running %1 %2 %3 %4 %5 %6 %7 %8 %9
../../runVimTests/bin/runVimTests.cmd %TEST_SOURCES% %1 %2 %3 %4 %5 %6 %7 %8 %9
goto End

:RunAll
echo Running all
../../runVimTests/bin/runVimTests.cmd %TEST_SOURCES% vimgrep.suite
goto End

:End
