@echo off
mode con: cols=160 lines=40
:: ============================
:: VARIABLES D'ENVIRONNEMENT
:: ============================
set "patch=C:\Program Files (x86)\Putty 0.79\Putty 0.79 x64\plink.exe"
set "key=C:\Data\Soft\Unraid\keys\tower.ppk"
set "patch2=/mnt/user/scripts/"

echo 1 720p Nvidia
echo 2 1080p Nvidia
echo.
echo 3 Audio FR
echo 4 Audio 192
echo 5 Audio 224
echo 6 Audio 384
echo 7 Audio 448
echo 8 Audio 640
echo.
echo 9 Voir 720p Nvidia
echo 10 Voir 1080p Nvidia
echo.
echo 11 Renommage des Films 
echo 0 Quitter
echo =====================================
set /p choix="Ton choix : "

if "%choix%"=="1" goto 720p
if "%choix%"=="2" goto 1080p
if "%choix%"=="3" goto audio_fr
if "%choix%"=="4" goto audio_192
if "%choix%"=="5" goto audio_224
if "%choix%"=="6" goto audio_384
if "%choix%"=="7" goto audio_448
if "%choix%"=="8" goto audio_640
if "%choix%"=="9" goto 720pt
if "%choix%"=="10" goto 1080pt
if "%choix%"=="11" goto ren1



if "%choix%"=="0" exit
goto :eof


:720p
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s 720p 'python3 %patch2%720p.py'"
pause
goto :eof

:1080p
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s 1080p 'python3 %patch2%1080p.py'"
pause
goto :eof

:audio_fr
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_fr 'python3 %patch2%encode_fr.py'"
pause
goto :eof

:audio_192
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_192 'python3 %patch2%audio_192.py'"
pause
goto :eof

:audio_224
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_224 'python3 %patch2%audio_224.py'"
pause
goto :eof

:audio_384
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_384 'python3 %patch2%audio_384.py'"
pause
goto :eof

:audio_448
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_448 'python3 %patch2%audio_448.py'"
pause
goto :eof

:audio_640
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s encode_640 'python3 %patch2%audio_640.py'"
pause

:720pt
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux attach -t 720p 'python3 %patch2%720p.py'"
pause
goto :eof

:1080pt
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
tmux attach -t 1080p"
pause
goto :eof

:ren1
"%patch%" -ssh -t -i "%key%" root@192.168.1.2 ^
 "tmux new -s ren1 'python3 %patch2%ren.py'"
pause
goto :eof

