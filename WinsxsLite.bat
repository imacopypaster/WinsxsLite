@echo OFF
setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set DIRCMD=
set home=%~dp0
path %home:~0,-1%;%PATH%

if "%1"=="ProgressWindow" (
	set z=%2
	title !z:_= !
	set InFile=1
	for /L %%a IN (1,0,2) DO for %%b IN ("%home%$Out!InFile!.txt") DO if EXIST %%b (
		set /A InFile=3-InFile
		del /F "%home%$Out!InFile!.txt" >NUL 2>&1
		timeout /NOBREAK /T 1 >NUL
		if %%~zb==0 (
			timeout /NOBREAK /T 5 >NUL
			exit
		) ELSE if EXIST %%b type %%b
		set z=%%~ab
		if "!z:~2,1!"=="-" timeout /NOBREAK /T 2 >NUL
	) ELSE timeout /NOBREAK /T 1 >NUL
)

title WinsxsLite v1.87

set WinsxsLite="%~f0"
set settings="%home%Config.txt"
set ToDo="%home%ToDo/.txt"
set Redo="%home%ToRedo.txt"
set ToSchedule="%home%ToSchedule.txt"
set important="%home%--IMPORTANT - SDs needed to restore security--.txt"
set unimportant="%home%--SDs that have been used to restore security--.txt"
set log="%home%Log.txt"
set DelMedia="%home%DelWinsxsSampleMedia.bat"
set P1Ext="%home%$Phase1Extensions.txt"
set ABuf="%home%$ABuf.txt"
set BBuf="%home%$BBuf.txt"
set buf="%home%$tmp.txt"

set root=%SYSTEMDRIVE%
set win=%SYSTEMROOT:~3%
set ProgFiles=%PROGRAMFILES:~3%

for /F "delims=." %%a IN ('ver') DO set z=%%a
set NoVista=
if %z:~-1% LSS 6 set NoVista=true
if "%1"=="AutoStart" (
	set AutoStarted=true
	echo.>>%log%
	echo ## %DATE% %TIME%: WinsxsLite auto started on computer startup.>>%log%
) ELSE (
	set AutoStarted=
	if "%1"=="AutoReboot" (
		call :SetStartup
		shutdown /R /T 0
		exit
	)
	call :ClearStartup
	if "%1"=="ClearAutoStart" exit
)
set z=0
for /F %%a IN ('fsutil') DO set /A z+=1
if %z% LSS 5 (
	echo WinsxsLite needs administrative privileges.
	echo Right click, and select 'Run as administrator'.
	echo.
	pause
	goto :EOF
)

call :Help NoShow
if NOT EXIST %settings% (
	echo :CONFIG VERSION=1.80>%settings%
	echo.>>%settings%
	echo :ROOT=%root%>>%settings%
	echo :WINDOWS DIR=%win%>>%settings%
	echo :PROGRAM FILES DIR=%ProgFiles%>>%settings%
	set valid=
	for /F "usebackq delims=" %%a IN (%WinsxsLite%) DO if DEFINED valid (
		if "%%a"==":DEFAULTCONFIGEND" (
			set valid=
		) ELSE echo%%a>>%settings%
	) ELSE if "%%a"==":DEFAULTCONFIGBEGIN" set valid=1
	echo Config file missing.
	if EXIST %settings% (
		echo Example configuration written to %settings%.
	) ELSE echo Couldn't write default config to %settings%.
	echo.
)
set LangCodenone=000
set LangKeep000=1
set LangNr=999
set version=0
set exclude= 
set reloc=
set RelocPaths= 
set state=
for /F "usebackq delims== tokens=1*" %%a IN (%settings%) DO (
	if /I "%%a"==":eof" goto SettingsDone
	if /I "%%a"==":config version" set version=%%b
	if /I "%%a"==":root" set root=%%~b
	if /I "%%a"==":windows dir" set win=%%~b
	if /I "%%a"==":program files dir" set ProgFiles=%%~b
	if /I "%%a"==":search for sample media in winsxs" set SearchSampleMedia=%%b
	if /I "%%a"==":phase 2 language priorities" set state=lp
	if /I "%%a"==":phase 1 excludes" set state=p1excl
	if /I "%%a"==":relocate folders" (
		set reloc=%%~b
		set state=rf
	)
	set z=%%~a
	if NOT "!z:~0,1!"==":" (
		if "!state!"=="p1excl" set exclude=!exclude! "%%~a"
		if "!state!"=="rf" set RelocPaths=!RelocPaths! "%%~a\"
		if "!state!"=="lp" (
			set LangCode%%a=!LangNr!
			if /I "%%b"=="keep" (
				set LangKeep!LangNr!=1
			) ELSE set LangKeep!LangNr!=
			set /A LangNr-=1
)	)	)
:SettingsDone
if %version:.=% LSS 180 (
	echo The config file is likely outdated.
	echo Delete it, and restart WinsxsLite to generate a new default config.
	echo.
)
set version=
set state=
set settings=
set LangNr=

for %%a IN ("%root%\") DO set root=%%~dpa
set root=%root:~0,-1%
set rootd=%root:~0,2%
if NOT EXIST %rootd% (
	echo No drive %rootd%
	echo.
	pause
	goto :EOF
)
if NOT EXIST %root% (
	echo No folder "%root%".
	echo.
	pause
	goto :EOF
)
set z=0
for /F %%a IN ('fsutil FSINFO NTFSINFO %rootd%') DO set /A z+=1
if %z% LSS 5 (
	echo The filesystem on drive %rootd% isn't NTFS.
	echo.
	pause
	goto :EOF
)
set offline=
if /I NOT %root%==%SYSTEMDRIVE% set offline=true

for %%a IN ("%root%\%win%\") DO set win=%%~dpa
set win=!win:%root%=!
set win=%win:~1,-1%
set ProgFiles86=
if DEFINED ProgFiles (
	for %%a IN ("%root%\%ProgFiles%\") DO set ProgFiles=%%~fa
	for %%a IN ("!ProgFiles:~0,-1! (x86)\") DO set ProgFiles86=%%~fa
	set ProgFiles="!ProgFiles:~0,-1!"
	set ProgFiles86="!ProgFiles86:~0,-1!"
	if NOT EXIST !ProgFiles86! set ProgFiles86=
	if NOT EXIST !ProgFiles! (
		echo No folder "!ProgFiles!".
		set ProgFiles=
)	)
for %%a IN ("%root%\%win%\winsxs\") DO set winsxs=%%~fa
if NOT EXIST "%winsxs%" (
	echo No folder "%winsxs:~0,-1%".
	pause
	goto :EOF
)
if NOT DEFINED reloc set reloc=%home:~0,3%
if %reloc::=%==%reloc% set reloc=%home:~0,3%%reloc%
for %%a IN ("%reloc%\") DO set z=%%~dpa
set reloc=%z:~0,-1%
set LinksDir=%rootd%\$\
set exclude=!exclude:$root$=%root%!
set exclude=!exclude:$win$=%root%\%win%!
set exclude=!exclude:$winsxs$=%winsxs:~0,-1%!
set exclude=!exclude:$system32$=%root%\%win%\System32!
set z=!RelocPaths:$root$=%root%!
set z=!z:$win$=%root%\%win%!
set z=!z:$winsxs$=%winsxs:~0,-1%!
set z=!z:$system32$=%root%\%win%\System32!
set RelocPaths=
for %%a IN (%z%) DO (
	set z=%%~dpa
	set RelocPaths=!RelocPaths! "!z:~0,-1!"
)

set ln=fail
if NOT DEFINED NoVista (
	set hlink=mklink /H
	ln.exe >NUL 2>&1
	if !ERRORLEVEL!==-8 (
		set count=0
		ln.exe -l %WinsxsLite%>%buf%
		for /F "usebackq delims=\: tokens=1" %%a IN (%buf%) DO if /I NOT "%%a"=="%home:~0,1%" (
			set /A count+=1
		) ELSE if !count!==1 set ln=
		if DEFINED ln echo Found wrong version of the ln.exe command.
	)
) ELSE set hlink=fsutil HARDLINK CREATE
set ReParse=
for /F "tokens=4*" %%a IN ('"dir /ADL "%root%\%win%" 2>NUL"') DO if /I "%%a"=="winsxs" set ReParse=%%b

set subinacl=fail
subinacl.exe >NUL 2>&1
if %ERRORLEVEL%==1 set subinacl=
set movefile=fail
movefile.exe >NUL 2>&1
if %ERRORLEVEL%==67 set movefile=
set pendmoves=fail
pendmoves.exe >NUL 2>&1
if %ERRORLEVEL%==0 set pendmoves=
set fcmp=fail
fcmp.exe >NUL 2>&1
if %ERRORLEVEL%==-1 set fcmp=
set md5file=fail
md5file.exe 2>NUL
if %ERRORLEVEL%==0 set md5file=
set stringconverter=fail
stringconverter.exe >NUL 2>&1
if %ERRORLEVEL%==0 set stringconverter=

if /I "%SearchSampleMedia%"=="yes" (
	echo Searching for sample media in winsxs...
	echo @echo OFF>%DelMedia%
	echo OFF >%buf%
	dir /B /AD-L "%winsxs%" >%ABuf%
	set size=
	set count=
	for /F "usebackq delims=" %%a IN (%ABuf%) DO (
		set z=%%a
		if NOT "!z:samples_=!"=="!z!" (
			for %%b IN (photo video music movie) DO set z=!z:_microsoft-windows-%%bsamples_=!
			if NOT "!z!"=="%%a" (
				cd /D %winsxs%%%a
				for %%b IN (*.ini *.jpg *.wmv *.wma *.dvr-ms) DO (
					set /A count+=1
					set /A "size+=(%%~zb+4095)/4096"
					echo del /F "%%~fb">>%DelMedia%
					echo +fil %%~fb>>%buf%
					echo /perm>>%buf%
					echo /pace=s-1-1-0 Type=0x0 Flags=0x0 AccessMask=0x1f01ff>>%buf%
	)	)	)	)
	if DEFINED count (
		echo pause>>%DelMedia%
		if NOT DEFINED subinacl subinacl.exe /nov /nos /pla %buf%
		set /A "z=(size*25+32)/64"
		set z=  !z!
		set z=!z:~0,-2!.!z:~-2!
		set z=!z:. =.0!
		set z=!z: .=0.!
		echo !z: =! MB in !count! files found. Created %DelMedia%.
	) ELSE (
		echo No media files found.
		del /F %DelMedia%
	)
	set size=
	echo.
	cd /D %home%
)
set SearchSampleMedia=
set DelMedia=

echo WinsxsLite v1.87 by Christian Bering Boegh.
if DEFINED offline goto Menu
set z=
for %%a IN (%RelocPaths%) DO (
	if EXIST "%%~a.$RenameMe" set z=1
	if EXIST %%a if EXIST "%%~a.$DeleteMe" set z=1
)
if NOT DEFINED z goto Menu
echo.
if DEFINED movefile (
	echo Missing movefile.exe command.
	pause
	goto :EOF
)
if DEFINED pendmoves (
	echo Missing pendmoves.exe command.
	pause
	goto :EOF
)
setlocal
echo.>>%log%
echo ## %DATE% %TIME%: Finalizing relocation of folders.>>%log%
call :ClearReg
set valid=1
for %%a IN (%RelocPaths%) DO (
	set z=
	if EXIST "%%~a.$RenameMe" set z=1
	if EXIST %%a if EXIST "%%~a.$DeleteMe" set z=1
	if DEFINED z (
		echo.
		echo Processing %%a.
		echo Processing %%a.>>%log%
		call :ActivateJunction %%a
)	)
attrib +r +s %important% >NUL
echo ## %DATE% %TIME%: Done.>>%log%
if NOT DEFINED valid (
	endlocal
	echo.
	echo Reboot to complete the folder relocation.
	echo Run WinsxsLite again afterwards.
	echo.
	pause
	goto :EOF
)
endlocal

:Menu
set choice=
if EXIST %important% (
	for /F "delims=" %%a IN ('attrib %important%') DO set z=%%a
	if NOT "!z:~3,1!!z:~5,1!"=="  " (
		echo.
		if DEFINED offline (
			echo Security needs to be restored in online mode.
			echo.
			pause
			goto :EOF
		)
		attrib -r -s %important% >NUL
		call :RestoreSDs Restoring security...
)	)
echo.
if EXIST %important% if NOT EXIST "%LinksDir%" (
	echo The program appears to have malfunctioned or been interrupted.
	echo If this is the case, it's important that the security
	echo descriptors are restored before continueing.
	set /P choice=Restore security - [Y]es/[L]ater ? 
	if /I "!choice!"=="Y" (
		if DEFINED subinacl (
			echo Missing subinacl.exe command.
			goto Menu
		)
		call :RestoreSDs Restoring security...
	)
	echo.
)
if EXIST %ToSchedule% (
	set count=
	for /F "usebackq delims=/" %%a IN (%ToSchedule%) DO (
		if EXIST "%LinksDir%%%a" set /A count+=1
	)
	if DEFINED count (
		echo !count! pending hardlinks in "%LinksDir:~0,-1%" - waiting for reboot.
		echo.
		if NOT DEFINED offline (
			set /P choice=Re[S]chedule activation,[C]ancel ^& delete,[A]uto start,[W]insxs size,           [H]elp or [Q]uit ? 
			for %%a IN (A W H Q) DO if /I "!choice!"=="%%a" goto Item%%a
			set error=
			if DEFINED movefile set error=movefile
			if DEFINED pendmoves set error=pendmoves
			if DEFINED error (
				echo Missing !error!.exe command.
				goto Menu
			)
			if /I "!choice!"=="C" (
				call :ClearLinksDir
				goto Menu
			)
			if /I "!choice!"=="S" (
				if DEFINED ln set error=ln
				if DEFINED fcmp set error=fcmp
				if DEFINED subinacl set error=subinacl
				if DEFINED stringconverter set error=stringconverter
				if DEFINED error (
					echo Missing !error!.exe command.
					goto Menu
				)
				setlocal
				echo Rethinking hardlink group creation from %ToSchedule%...
				set z=0
				for /F "usebackq delims=/" %%a IN (%ToSchedule%) DO if EXIST "%LinksDir%%%a" if %%a GTR !z! set z=%%a
				set /A z+=1000000
				cd /D %rootd%\
				echo 0/:/::>>%ToSchedule%
				echo OFF >%Redo%
				set count=!z:~0,-6!000000
				set sibling1=
				set siblings=1
				set z=0
				for /F "usebackq delims=/ tokens=2,3" %%a IN (%ToSchedule%) DO (
					if /I NOT "%%b"=="!sibling1!" (
						set target=!sibling1!
						for /L %%c IN (!z!,-1,!siblings!) DO if NOT "!sibling%%c:~-1!"=="/" set target=!sibling%%c!
						for /L %%c IN (!z!,-1,!siblings!) DO if "!sibling%%c:\%win%\winsxs\=!"=="!sibling%%c:/=!" set target=!sibling%%c!
						ln.exe -l "%rootd%!target!">%buf%
						for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO for /L %%c IN (1,1,!z!) DO if /I "!sibling%%c!"=="\%%e" set sibling%%c=
						for /L %%c IN (1,1,!z!) DO if DEFINED sibling%%c (
							set /A count+=1
							echo !count!/!sibling%%c!/!target!>>%Redo%
						)
						set z=0
						if EXIST "%rootd%%%b" (
							set sibling1=%%b
							set z=1
							ln.exe -l "%rootd%%%b">%buf%
							for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO if NOT "%%d"=="ERROR" (
								set source=%%d:\%%e
								if /I NOT "\%%e"=="%%b" if "!source:%LinksDir%=!"=="!source!" (
									set /A z+=1
									set sibling!z!=\%%e
						)	)	)
						set /A siblings=z+1
					)
					set /A z+=1
					set sibling!z!=%%a/
					if "%%~za"=="%%~zb" if EXIST "%rootd%%%a" (
						fcmp.exe /S "%rootd%%%a" "%rootd%%%b"
						if !ERRORLEVEL!==0 set sibling!z!=%%a
				)	)
				cd /D %home%
				echo OFF >%ABuf%
				for /F "usebackq delims=/ tokens=2,3" %%a IN (%Redo%) DO (
					echo %%~pa>>%ABuf%
					echo %%~pb>>%ABuf%
				)
				echo.>%BBuf%
				set z=
				for /F "delims=" %%a IN ('sort /L ""C"" %ABuf%') DO if /I NOT "%%a"=="!z!" if NOT "%%a"=="\" (
					echo +fil %rootd%%%a>>%BBuf%
					echo /dis=dacl>>%BBuf%
					set z=%%a
				)
				echo __cachefileonly__>%buf%
				subinacl.exe /nov /nos /offl=%buf% /pla %BBuf% >%ABuf%
				stringconverter.exe %ABuf% %ABuf% /ANSI /FORCEUNICODE
				echo +File>>%ABuf%
				echo.>%BBuf%
				set valid=1
				for /F "usebackq tokens=1*" %%a IN (%ABuf%) DO (
					if "%%a"=="/pace" for /F "tokens=1,7 delims== " %%c IN ("%%b") DO if /I "%%c%%d"=="s-1-1-00x1f01ff" set valid=1
					if "%%a"=="+File" (
						if NOT DEFINED valid (
							echo +fil !z!>>%BBuf%
							echo /dis=sddl>>%BBuf%
							echo /perm>>%BBuf%
							echo /pace=s-1-1-0 Type=0x0 Flags=0x0 AccessMask=0x1f01ff>>%BBuf%
						)
						set valid=
						set z=%%b
				)	)
				subinacl.exe /nov /nos /pla %BBuf% >%ABuf%
				stringconverter.exe %ABuf% %ABuf% /ANSI /FORCEUNICODE
				type %ABuf% >>%important%
				set /A count-=!count:~0,-6!000000
				echo !count! lines written to %Redo%.
				endlocal
				call :ClearLinksDir
				if DEFINED error goto Menu
				call :CreateHardlinks %Redo% SkipSD
				if DEFINED error goto Menu
				call :ActivateHardlinks %ToSchedule%
			)
		) ELSE (
			set /P choice=[W]insxs size,[H]elp or [Q]uit ? 
			for %%a IN (W H Q) DO if /I "!choice!"=="%%a" goto Item%%a
		)
		goto Menu
)	)
if EXIST "%LinksDir%" (
	set count=
	for /R "%LinksDir%" %%a IN (*) DO (
		del /F "%%a" >NUL 2>&1
		if EXIST "%%a" (
			set /A count+=1
			for /F "delims=" %%b IN ('attrib "%%a" /L') DO set z=%%b
			if "!z:~5,1!"=="R" (
				set z= +!z:~3,1! +!z:~4,1!
				set z=!z: + =!
				attrib -r!z! "%%a" /L >NUL
			)
			if NOT DEFINED movefile movefile.exe "%%a" "" >NUL
	)	)
	if DEFINED movefile if DEFINED count echo Missing movefile.exe command.
	if NOT DEFINED count (
		rd /S /Q "%LinksDir%" >NUL 2>&1
		if EXIST %important% (
			if DEFINED subinacl (
				echo Missing subinacl.exe command.
				pause
				goto :EOF
			)
			if DEFINED offline (
				echo Security needs to be restored in online mode.
				echo.
				pause
				goto :EOF
			)
			call :RestoreSDs Restoring security using merged security descriptors...
		)
		goto Menu
	)
	echo A reboot is necessary to complete the cleanup.
	echo Run WinsxsLite again afterwards.
	set /P choice=[A]uto start,[W]insxs size,[H]elp or [Q]uit ? 
	for %%a IN (A W H Q) DO if /I "!choice!"=="%%a" goto Item%%a
	goto Menu
)
set /P choice=Phase[1]/[2],[R]elocate folders,[A]uto start,[W]insxs size,[H]elp or [Q]uit ? 
for %%a IN (1 2 R A W H Q) DO if /I "!choice!"=="%%a" goto Item%%a
goto Menu
:ItemQ
goto :EOF
:ItemH
echo.
call :Help
goto Menu
:ItemW
echo.
call :WinsxsSize
goto Menu
:Item2
:Item1
echo.
if DEFINED ReParse (
	echo "%winsxs:~0,-1%" is a reparse point to !ReParse!
) ELSE call :Phase%choice% !ToDo:/=%choice%!
goto Menu
:ItemR
echo.
call :RelocFolders
goto Menu
:ItemA
if DEFINED NoVista (
	echo This function needs Vista to run.
) ELSE call :SetStartup
goto Menu

:EchoWindow
if NOT DEFINED OutFile if "%2"=="FORCE" (
	call :OpenWindow %3
) ELSE goto :EOF
set /A OutFile=3-OutFile
if NOT EXIST "%home%$Out%OutFile%.txt" (
	set /A OutFile=3-OutFile
	set BusyWindow="%home%$Out!OutFile!.txt"
)
set /A OutFile=3-OutFile
echo%~1>>"%home%$Out%OutFile%.txt"
if "%2"=="" attrib -a "%home%$Out%OutFile%.txt" >NUL
goto :EOF

:EchoError
if NOT %2==!ErrStr! (
	if NOT !ErrStr!=="" (
		if !entry1! LEQ 9999 (
			set entrya=   !entry1!
			set entrya=!entrya:~-4!
		) ELSE set entrya=!entry1!
		if NOT !entry1!==!entry2! (
			if !entry2! LEQ 9999 (
				set entryb=   !entry2!
				set entryb= -!entryb:~-4!
			) ELSE set entryb=-!entry2!
		) ELSE set entryb=
		call :EchoWindow " !entrya!!entryb!: !ErrStr:~1,-1!" FORCE ERRORS:
	)
	set entry1=%1
	set ErrStr=%2
)
if NOT %3==!ErrStrLog! (
	if NOT !ErrStrLog!=="" (
		if !entry1Log! LEQ 9999 (
			set entrya=   !entry1Log!
			set entrya=!entrya:~-4!
		) ELSE set entrya=!entry1Log!
		if NOT !entry1Log!==!entry2! (
			if !entry2! LEQ 9999 (
				set entryb=   !entry2!
				set entryb= -!entryb:~-4!
			) ELSE set entryb=-!entry2!
		) ELSE set entryb=
		echo !entrya!!entryb!: !ErrStrLog:~1,-1!>>%log%
	)
	set entry1Log=%1
	set ErrStrLog=%3
)
set entry2=%1
set Echoed=true
goto :EOF

:OpenWindow
if DEFINED NoVista goto :EOF
if DEFINED OutFile goto :EOF
del /F "%home%$Out1.txt" >NUL 2>&1
echo.>"%home%$Out2.txt"
start "" /HIGH "%COMSPEC%" /C %WinsxsLite% ProgressWindow %1
set OutFile=1
set BusyWindow="%home%$Out2.txt"
goto :EOF

:CloseWindow
if DEFINED NoVista goto :EOF
if NOT DEFINED OutFile goto :EOF
for %%Z IN (1 1 1 1) DO (
	if NOT EXIST %BusyWindow% (
		echo OFF >%BusyWindow%
		set OutFile=
		set BusyWindow=
		goto :EOF
	)
	choice /N /T 1 /D Y>NUL
)
if "%1"=="ECHO" (
	if EXIST %BusyWindow% type %BusyWindow%
	if EXIST "%home%$Out%OutFile%.txt" type "%home%$Out%OutFile%.txt"
)
echo OFF >"%home%$Out1.txt"
echo OFF >"%home%$Out2.txt"
set OutFile=
set BusyWindow=
goto :EOF

:Apply
if EXIST %1 (
	attrib -s -h -r %1 >NUL
	for /F "delims=" %%a IN ('attrib %1') DO set z=%%a
	if "!z:~0,1!"=="A" (
		echo %1 is outdated...
	) ELSE (
		set count=
		for /F "usebackq" %%a IN (%1) DO set /A count+=1
		if DEFINED count (
			echo Previous scan result of !count! lines in %1.
			set /P choice=Re[S]can,[A]pply or [E]xit ? 
			if /I "!choice!"=="A" (
				set choice=
				if DEFINED subinacl (
					echo Missing subinacl.exe command.
					goto :EOF
				)
				if DEFINED stringconverter (
					echo Missing stringconverter.exe command.
					goto :EOF
				)
				if NOT DEFINED offline if DEFINED movefile (
					echo Missing movefile.exe command.
					goto :EOF
				)
				call :CreateHardlinks %1
				if DEFINED error goto :EOF
				if NOT DEFINED offline (
					echo.
					call :ActivateHardlinks %ToSchedule%
			)	)
			goto :EOF
)	)	)
set /P choice=[S]can or [E]xit ? 
goto :EOF

:CreateHardlinks
set error=true
if NOT EXIST %1 (
	echo %1 not found.
	goto :EOF
)
if NOT DEFINED offline (
	md "%LinksDir%" 2>NUL
	echo OFF >%ToSchedule%
)
setlocal
call :OpenWindow Modifying_the_system_-_creating_hardlinks...
if "%2"=="SkipSD" goto CreateHL
echo   Calculating new security descriptors...
for /F "delims==" %%a IN ('"set Mask 2>NUL"') DO set %%a=
set hex=
for %%a IN (0 1 2 3 4 5 6 7 8 9 a b c d e f) DO for %%b IN (0 1 2 3 4 5 6 7 8 9 a b c d e f) DO set hex=!hex!%%a%%b
echo //>>%1
attrib -s -h -r -a %1 >NUL
call :EchoWindow " Calculating new security descriptors..."
echo __cachefileonly__>%buf%
echo OFF >%important%
echo.>%BBuf%
set files=-2
set groups=-1
set old=
for /F "usebackq delims=/ tokens=2,3" %%a IN (%1) DO (
	set /A files+=1
	if /I NOT "%%b"=="!old!" (
		set /A files+=1
		set /A groups+=1
		if NOT EXIST !BusyWindow! call :EchoWindow " Running total: !files! security descriptors merged into !groups!."
		subinacl.exe /nov /nos /offl=%buf% /pla %BBuf% >%ABuf%
		stringconverter.exe %ABuf% %ABuf% /ANSI /FORCEUNICODE
		echo OFF >%BBuf%
		set valid=
		set own=
		set owners= 
		set SIDs=
		set SIDsID=
		for /F "usebackq tokens=1*" %%c IN (%ABuf%) DO (
			if NOT DEFINED valid (
				if "%%c"=="+File" (
					echo %%d>>%BBuf%
					set valid=1
				)
			) ELSE if "%%c"=="/pace" (
				set z=%%d
				for /F "tokens=1,3,5,7 delims== " %%e IN ("!z:-=a!") DO if %%f==0x0 (
					if %%g==0x10 (
						if NOT DEFINED MaskID%%e set SIDsID=!SIDsID! %%e
						set /A "MaskID%%e|=%%h"
					) ELSE (
						if NOT DEFINED Mask%%e set SIDs=!SIDs! %%e
						set /A "Mask%%e|=%%h"
				)	)
			) ELSE if "%%c"=="/owner" (
				for /F "delims==" %%e IN ("%%d") DO if "!owners:%%e=!"=="!owners!" set owners=!owners! %%e
				set valid=
		)	)
		for %%c IN (s-1-1-0 s-1-5-18 s-1-5-19 s-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 s-1-5-32-545 s-1-5-21- s-1-5-32-544) DO if NOT DEFINED own if NOT "!owners:%%c=!"=="!owners!" set own=%%c
		if /I "!own!"=="s-1-5-21-" for /F %%c IN ("!owners:*s-1-5-21-=s-1-5-21-!") DO set own=%%c
		if NOT DEFINED own for /F %%c IN ("!owners!") DO set own=%%c
		set own=O:!own!D:P
		for %%c IN (!SIDs!) DO (
			set /A "z=(Mask%%c^MaskID%%c)&MaskID%%c"
			if !z!==0 set MaskID%%c=
			set "own=!own!(A;;0x"
			set /A "z=Mask%%c>>23&0x1FE"
			if NOT !z!==0 for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=Mask%%c>>15&0x1FE"
			for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=Mask%%c>>7&0x1FE"
			for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=Mask%%c<<1&0x1FE"
			set old=%%c
			for %%d IN (!z!) DO set "own=!own!!hex:~%%d,2!;;;!old:a=-!)"
			set Mask%%c=
		)
		for %%c IN (!SIDsID!) DO if DEFINED MaskID%%c (
			set "own=!own!(A;ID;0x"
			set /A "z=MaskID%%c>>23&0x1FE"
			if NOT !z!==0 for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=MaskID%%c>>15&0x1FE"
			for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=MaskID%%c>>7&0x1FE"
			for %%d IN (!z!) DO set own=!own!!hex:~%%d,2!
			set /A "z=MaskID%%c<<1&0x1FE"
			set old=%%c
			for %%d IN (!z!) DO set "own=!own!!hex:~%%d,2!;;;!old:a=-!)"
			set MaskID%%c=
		)
		for /F "usebackq delims=" %%c IN (%BBuf%) DO (
			echo +fil %%c>>%important%
			echo /sddl=!own!>>%important%
		)
		echo +fil %rootd%%%b>%BBuf%
		echo /dis=dacl>>%BBuf%
		echo /dis=owner>>%BBuf%
		set old=%%b
	)
	echo +fil %rootd%%%a>>%BBuf%
	echo /dis=dacl>>%BBuf%
	echo /dis=owner>>%BBuf%
)
call :EchoWindow "         Total: !files! security descriptors merged into !groups!."
call :EchoWindow "."
call :EchoWindow " Removing filesystem security on !files! files in !groups! groups..."
call :EchoWindow "."
echo OFF >%BBuf%
for /F "usebackq delims=/ tokens=2,3" %%a IN (%1) DO (
	echo %%~pa>>%BBuf%
	echo %%~pb>>%BBuf%
)
echo OFF >%ABuf%
set z=
for /F "delims=" %%a IN ('sort /L ""C"" %BBuf%') DO if /I NOT "%%a"=="!z!" if NOT "%%a"=="\" (
	echo +fil %rootd%%%a>>%ABuf%
	echo /dis=sddl>>%ABuf%
	echo /perm>>%ABuf%
	echo /pace=s-1-1-0 Type=0x0 Flags=0x0 AccessMask=0x1f01ff>>%ABuf%
	set z=%%a
)
set z=
for /F "usebackq delims=/ tokens=2,3" %%a IN (%1) DO (
	echo +fil %rootd%%%a>>%ABuf%
	echo /perm>>%ABuf%
	echo /pace=s-1-1-0 Type=0x0 Flags=0x0 AccessMask=0x1f01ff>>%ABuf%
	if /I NOT "%%b"=="!z!" (
		echo +fil %rootd%%%b>>%ABuf%
		echo /perm>>%ABuf%
		echo /pace=s-1-1-0 Type=0x0 Flags=0x0 AccessMask=0x1f01ff>>%ABuf%
		set z=%%b
)	)
subinacl.exe /nov /nos /pla %ABuf% >%BBuf%
stringconverter.exe %BBuf% %BBuf% /ANSI /FORCEUNICODE
type %BBuf% >>%important%
echo   Done.
:CreateHL
echo Generating replacement hardlinks...
call :EchoWindow " Generating replacement hardlinks..."
call :EchoWindow "."
echo.>>%log%
echo ## %DATE% %TIME%: Generating replacement hardlinks using %1.>>%log%
attrib -s -h -r +a %ToDo:/=1% >NUL
attrib -s -h -r +a %ToDo:/=2% >NUL
attrib -s -h -r -a %1 >NUL
set ErrStr=""
set ErrStrLog=""
set count=0
set scheduled=
set MissingTarget=
set FailedCreate=
set FailedCreateCritical=
set FailedDelete=
for /F "usebackq delims=/ tokens=1-3" %%a IN (%1) DO (
	set Echoed=
	set /A count+=1
	if NOT EXIST !BusyWindow! (
		set /A z=MissingTarget+FailedCreate+FailedCreateCritical+FailedDelete
		set z=!z! failures.
		if DEFINED scheduled set z=!scheduled! needs a reboot. !z!
		call :EchoWindow " !count! hardlinks created. !z!"
	)
	if NOT EXIST "%rootd%%%c" (
		set /A MissingTarget+=1
		call :EchoError %%a "Couldn't find link target." "Couldn't find link target '%rootd%%%c'."
	) ELSE (
		del /F "%rootd%%%b" >NUL 2>&1
		if NOT DEFINED offline (
			if EXIST "%rootd%%%b" (
				%hlink% "%LinksDir%%%a" "%rootd%%%c" >NUL 2>&1
				if NOT EXIST "%LinksDir%%%a" (
					set /A FailedCreate+=1
					call :EchoError %%a "Failed to create to-be scheduled replacement hardlink." "Failed to create to-be scheduled replacement for '%rootd%%%b' - link to '%rootd%%%c'."
				) ELSE (
					echo %%a/%%b/%%c>>%ToSchedule%
					set /A scheduled+=1
				)
			) ELSE (
				%hlink% "%rootd%%%b" "%rootd%%%c" >NUL 2>&1
				if NOT EXIST "%rootd%%%b" (
					%hlink% "%LinksDir%%%a" "%rootd%%%c" >NUL 2>&1
					if NOT EXIST "%LinksDir%%%a" (
						set /A FailedCreateCritical+=1
						call :EchoError %%a "Failed to create immediate replacement hardlink." "Failed to create immediate replacement for '%rootd%%%b' - link to '%rootd%%%c'."
					) ELSE (
						echo %%a/%%b/%%c>>%ToSchedule%
						set /A scheduled+=1
			)	)	)
		) ELSE (
			if EXIST "%rootd%%%b" (
				attrib -s -h "%rootd%%%b" >NUL
				del /F "%rootd%%%b" >NUL 2>&1
				if EXIST "%rootd%%%b" (
					set /A FailedDelete+=1
					call :EchoError %%a "Failed to delete file for immediate replacement." "Failed to delete '%rootd%%%b'."
			)	)
			if NOT EXIST "%rootd%%%b" (
				%hlink% "%rootd%%%b" "%rootd%%%c" >NUL 2>&1
				if NOT EXIST "%rootd%%%b" (
					set /A FailedCreateCritical+=1
					call :EchoError %%a "Failed to create immediate replacement hardlink." "Failed to create immediate replacement for '%rootd%%%b' - link to '%rootd%%%c'."
	)	)	)	)
	if NOT DEFINED Echoed call :EchoError 0 "" ""
)
call :EchoError 0 "" ""
attrib -s -h -r +a %1 >NUL
set /A error=MissingTarget+FailedCreate+FailedCreateCritical+FailedDelete
set z=%error% failures.
if DEFINED scheduled set z=%scheduled% needs a reboot. %z%
call :EchoWindow " %count% hardlinks created. %z%"
if %error% GTR 0 call :CloseWindow ECHO
echo Completed processing %count% lines in %1.>%ABuf%
set /A count-=MissingTarget+FailedCreate+FailedCreateCritical+FailedDelete
echo %count% hardlinks were successfully created.>>%ABuf%
if DEFINED scheduled echo %scheduled% of them needs to be scheduled for activation on reboot.>>%ABuf%
if DEFINED MissingTarget echo %MissingTarget% link targets not found.>>%ABuf%
if DEFINED FailedCreate echo %FailedCreate% to-be scheduled hardlinks couldn't be created.>>%ABuf%
if DEFINED FailedDelete echo %FailedDelete% files couldn't be deleted for immediate hardlink replacement.>>%ABuf%
if DEFINED FailedCreateCritical (
	echo %FailedCreateCritical% immediate replacement hardlinks couldn't be created.>>%ABuf%
	echo     These files are now missing from the system, and has to be linked manually.>>%ABuf%
)
set /A count=MissingTarget+FailedCreate+FailedCreateCritical+FailedDelete
if NOT %count%==0 echo %count% hardlink generation failures in total.>>%ABuf%
type %ABuf%
type %ABuf% >>%log%
echo ## %DATE% %TIME%: Done.>>%log%
call :CloseWindow
endlocal
set error=
if DEFINED offline call :RestoreSDs Applying merged security descriptors...
goto :EOF

:ActivateHardlinks
if NOT EXIST %1 (
	echo %1 not found.
	goto :EOF
)
if %~z1==0 goto :EOF
setlocal
echo Scheduling activation of replacement hardlinks...
echo.>>%log%
echo ## %DATE% %TIME%: Scheduling activation of replacement hardlinks using %1.>>%log%
set ErrStr=""
set ErrStrLog=""
set count=0
set MissingFile=
set FailedDelete=
set FailedRename=
set FailedCreateCritical=
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
for /F "usebackq delims=/ tokens=1,2" %%a IN (%1) DO (
	set Echoed=
	set /A count+=1
	if NOT EXIST "%LinksDir%%%a" (
		set /A MissingFile+=1
		call :EchoError %%a "" "Replacement hardlink not found in '!LinksDir:~0,-1!'."
	) ELSE (
		set error=
		if EXIST "%rootd%%%b" (
			for /F "delims=" %%d IN ('attrib "%rootd%%%b"') DO set z=%%d
			if "!z:~5,1!"=="R" attrib -r -s -h "%rootd%%%b" >NUL
			movefile.exe "%rootd%%%b" "" >NUL
			if NOT !ERRORLEVEL!==30 (
				set error=true
				set /A FailedDelete+=1
				call :EchoError %%a "Failed to schedule deletion." "Failed to schedule deletion of '%rootd%%%b'."
		)	)
		if NOT DEFINED error (
			for /F "delims=" %%d IN ('attrib "%LinksDir%%%a"') DO set z=%%d
			if "!z:~5,1!"=="R" attrib -r -s -h "%LinksDir%%%a" >NUL
			movefile.exe "%LinksDir%%%a" "%rootd%%%b" >NUL
			if NOT !ERRORLEVEL!==30 (
				set /A FailedRename+=1
				call :EchoError %%a "Failed to schedule rename." "Failed to schedule rename of '%LinksDir%%%a' to '%rootd%%%b'."
	)	)	)
	if NOT DEFINED Echoed call :EchoError 0 "" ""
)
call :EchoError 0 "" ""
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
echo Completed processing %count% lines in %1.>%ABuf%
set /A count-=MissingFile+FailedDelete+FailedRename
echo %count% files were successfully scheduled for replacement.>>%ABuf%
if DEFINED MissingFile echo %MissingFile% replacement hardlinks not found.>>%ABuf%
if DEFINED FailedDelete echo %FailedDelete% files couldn't be scheduled for deletion.>>%ABuf%
if DEFINED FailedRename (
	echo %FailedRename% replacement hardlinks couldn't be scheduled for activation.>>%ABuf%
	echo     Either they have to be moved and renamed manually after reboot,>>%ABuf%
	echo     or all scheduled operations has to be cancelled before reboot.>>%ABuf%
)
set /A count=MissingFile+FailedDelete+FailedRename
if NOT %count%==0 echo %count% scheduling failures in total.>>%ABuf%
type %ABuf%
type %ABuf% >>%log%
echo ## %DATE% %TIME%: Done.>>%log%
echo.
echo   IMPORTANT - After reboot, run WinsxsLite
echo   to restore security descriptors.
call :CloseWindow ECHO
endlocal
goto :EOF

:Phase1
call :Apply %1
if /I NOT "%choice%"=="S" goto :EOF
set choice=
if DEFINED NoVista (
	echo This function needs Vista to run.
	goto :EOF
)
if DEFINED ln (
	echo Missing ln.exe command.
	goto :EOF
)
if DEFINED fcmp (
	echo Missing fcmp.exe command.
	goto :EOF
)
if DEFINED md5file (
	echo Missing md5file.exe command.
	goto :EOF
)
setlocal
echo Phase 1: Scanning...
echo.>>%log%
echo ## %DATE% %TIME%: Started phase 1 scan.>>%log%
call :OpenWindow Phase_1:_Scanning...
set excludes=
for %%a IN (%exclude%) DO (
	set z=%%~a
	if "!z:~-1!"=="\" set excludes=!excludes! %%a
)
echo OFF >%ABuf%
set count=0
for %%a IN ("%root%\%win%" %ProgFiles86% %ProgFiles%) DO (
	set z=%%~a
	echo !z:\=!>>%ABuf%
	dir /AD-L /B /S %%a >%buf%
	find /V "=" %buf% >%BBuf%
	if %%a=="%root%\%win%" call :EchoWindow "."
	for /F "usebackq skip=2 delims=" %%b IN (%BBuf%) DO (
		set z=%%b\
		set valid=1
		for %%c IN (%excludes%) DO if NOT "!z:%%~c=!"=="!z!" set valid=
		if DEFINED valid (
			set /A count+=1
			if NOT EXIST !BusyWindow! call :EchoWindow " !count! folders enumerated [%%~a]."
			set z=%%b
			echo !z:\=!>>%ABuf%
	)	)
	call :EchoWindow " !count! folders enumerated [%%~a]."
)
call :EchoWindow "."
call :EchoWindow " Filtering..."
set excludes=
echo OFF >%BBuf%
set old=%root%\
for /F "delims=" %%a IN ('sort /L ""C"" %ABuf%') DO (
	set z=%%a
	for %%b IN ("!z:=\!") DO if NOT "!old:%%~dpb=!"=="!old!" (
		set old=%%~b\
		echo -/%%~b>>%BBuf%
		dir /A-D-L /B %%b 2>NUL >>%BBuf%
)	)
set old=
for %%a IN (%exclude%) DO (
	set z=%%~a
	if NOT "!z:~-1!"=="\" set excludes=!excludes! %%a
)
find /V "=" %BBuf% >%ABuf%
call :EchoWindow "."
echo OFF >%BBuf%
set count=0
for /F "usebackq skip=2 delims=/ tokens=1*" %%a IN (%ABuf%) DO if "%%b"=="" (
	for %%c IN ("!dir!\%%a") DO if %%~zc GTR 0 (
		set z=%%~c/
		set valid=1
		for %%d IN (%excludes%) DO if NOT "!z:%%~d=!"=="!z!" set valid=
		if DEFINED valid (
			set /A count+=1
			if NOT EXIST !BusyWindow! call :EchoWindow " !count! files enumerated."
			echo %%~zc/%%~pnxc>>%BBuf%
	)	)
) ELSE set dir=%%b
call :EchoWindow " %count% files enumerated."
call :EchoWindow "."
call :EchoWindow " Filtering..."
set excludes=
set dir=
find "/%root:~2%\%win%\winsxs\" %BBuf% >%ABuf%
for /F "usebackq skip=2 delims=/" %%a IN (%ABuf%) DO echo %%a/>>%BBuf%
sort /L ""C"" %BBuf% /O %BBuf%
echo OFF >%ABuf%
set score=0
set z=/
for /F "usebackq delims=/ tokens=1,2" %%a IN (%BBuf%) DO if NOT "%%b"=="" (
	if %%a==!z! (
		set /A score+=1
		echo %%a/%%b>>%ABuf%
	)
) ELSE set z=%%a
call :EchoWindow "."
call :EchoWindow " A total of %score% files left for main processing."
sort /L ""C"" /R %ABuf% /O %ABuf%
echo 0/>>%ABuf%
set done 2>NUL >%buf%
set hash 2>NUL >>%buf%
set \ 2>NUL >>%buf%
for /F "usebackq delims==" %%a IN (%buf%) DO set %%a=
call :EchoWindow "."
echo OFF >%1
set freed=0
set count=No
set files=0
set groups=0
set size=/
for /F "usebackq delims=/ tokens=1,2" %%a IN (%ABuf%) DO (
	set /A files+=1
	if NOT EXIST !BusyWindow! (
		set /A z=files*1000/%score%
		if !z! GEQ 30 (
			for /F "delims=:., tokens=1-3,5-7" %%c IN ("!TIME::0=:!:%TIME::0=:%") DO set /A valid=%%c*3600+%%d*60+%%e-%%f*3600-%%g*60-%%h
			if !valid! LSS 0 set /A valid+=86400
			set /A valid=%score%*1000/files*valid/1000-valid
			set /A target=valid/3600
			set /A valid-=target*3600
			set /A score=valid/60
			set /A valid-=score*60
			set target= !target!
			set score=0!score!
			set valid=0!valid!
			set valid=  Est. time remaining: !target:~-2!:!score:~-2!:!valid:~-2!
		) ELSE set valid=
		set z=   !z:~0,-1!.!z:~-1!
		set z=!z: .=0.!
		set files=      !files!
		call :EchoWindow " !z:~-5!%%%%,    !files:~-7! files processed.!valid!"
		set /A "z=(freed*25+32)/64"
		set z=  !z!
		set z=!z:~0,-2!.!z:~-2!
		set z=!z:. 0=0   !
		set z=!z:. =.0!
		set z=!z: .=0.!
		set z=    !z!
		set count=      !count!
		call :EchoWindow "      !count:~-7! hardlinks to create.			  Will free!z:~-8! MB."
	)
	if NOT %%a==!size! (
		if NOT !groups!==0 (
			for %%f IN ("!file!") DO if "!%%~f!"=="" (
				set /A groups+=1
				ln.exe -l "%rootd%!file!">%buf%
				for %%c IN (!groups!) DO (
					set group%%c=
					for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO if NOT "%%d"=="ERROR" (
						set /A group%%c+=1
						set group%%cf!group%%c!=\%%e
						set \%%e=%%c
					)
					if NOT DEFINED group%%c set /A groups-=1
			)	)
			if !groups! GEQ 2 (
				verify >NUL
				set %winsxs:~2% 2>NUL >%buf%
				if NOT ERRORLEVEL 1 (
					set valid=1
					set ListWinsxs= 
					for /F "usebackq delims== tokens=2" %%c IN (%buf%) DO set ListWinsxs=!ListWinsxs!%%c 
					set %root:~2%\%win%\System32\ 2>NUL >%buf%
					set ListSystem32= 
					for /F "usebackq delims== tokens=2" %%c IN (%buf%) DO set ListSystem32=!ListSystem32!%%c 
				) ELSE set valid=
			)
			for /L %%c IN (1,1,!groups!) DO for /L %%d IN (1,1,!group%%c!) DO set !group%%cf%%d!=
			if !groups! GEQ 2 if DEFINED valid (
				set hashes=
				set HashGroups=
				for /L %%c IN (!groups!,-1,1) DO (
					md5file.exe "%rootd%!group%%cf1!">%buf%
					for /F "usebackq delims=" %%d IN (%buf%) DO (
						set z=%%d
						for %%e IN (!z:~-8!) DO if DEFINED hash%%e (
							if "!hash%%e:~-1!"==" " set HashGroups=!HashGroups! %%e
							set hash%%e=!hash%%e! %%c
						) ELSE (
							set hashes=!hashes! %%e
							set hash%%e=%%c 
				)	)	)
				for %%c IN (!HashGroups!) DO for %%d IN (!hash%%c!) DO (
					if NOT DEFINED done%%d (
						set valid=
						for %%e IN (!hash%%c!) DO if %%e LSS %%d if NOT DEFINED done%%e (
							fcmp.exe /S "%rootd%!group%%df1!" "%rootd%!group%%ef1!"
							if !ERRORLEVEL!==0 (
								set valid=!valid!%%e 
								set done%%e=1
						)	)
						if DEFINED valid (
							set valid= !valid!%%d 
							set z=
							for %%e IN (!valid!) DO if NOT "!ListWinsxs!"=="!ListWinsxs: %%e =!" set z=1
							if DEFINED z (
								set score=0
								for %%e IN (!valid!) DO (
									set z=
									if NOT "!ListSystem32!"=="!ListSystem32: %%e =!" set z=10000
									set /A z+=group%%e
									if !z! GTR !score! (
										set score=!z!
										set target=%%e
								)	)
								for %%e IN (!target!) DO (
									set valid=!valid: %%e = !
									set target=!group%%ef1!
								)
								for %%e IN (!valid!) DO (
									set /A "freed+=(size+4095)/4096"
									for /L %%f IN (1,1,!group%%e!) DO (
										set /A count+=1
										echo !count!/!group%%ef%%f!/!target!>>%1
					)	)	)	)	)
					set done%%d=
				)
				for %%c IN (!hashes!) DO set hash%%c=
			)
			for /L %%c IN (1,1,!groups!) DO (
				for /L %%d IN (1,1,!group%%c!) DO set group%%cf%%d=
				set group%%c=
			)
			set groups=0
		)
		set size=%%a
	) ELSE for %%f IN ("!file!") DO if "!%%~f!"=="" (
		set /A groups+=1
		ln.exe -l "%rootd%!file!">%buf%
		for %%c IN (!groups!) DO (
			set group%%c=
			for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO if NOT "%%d"=="ERROR" (
				set /A group%%c+=1
				set group%%cf!group%%c!=\%%e
				set \%%e=%%c
			)
			if NOT DEFINED group%%c set /A groups-=1
	)	)
	set file=%%b
)
attrib -a %1
set files=      %files%
call :EchoWindow " 100.0%%%%,    %files:~-7% files processed."
set /A "z=(freed*25+32)/64"
set z=  %z%
set z=%z:~0,-2%.%z:~-2%
set z=%z:. 0=0   %
set z=%z:. =.0%
set z=%z: .=0.%
set z=    %z%
set count=      %count%
call :EchoWindow "      %count:~-7% hardlinks to create.			  Will free%z:~-8% MB."
call :CloseWindow
echo OFF >%ABuf%
for /F "usebackq delims=/ tokens=2,3" %%a IN (%1) DO echo %%~xa # %%a # %%b>>%ABuf%
sort /L ""C"" %ABuf% /O %P1Ext%
echo %count% lines written to %1.
echo %count% lines written to %1.>>%log%
if NOT %freed%==0 (
	set z=Applying this scan will free %z: =% MB.
	echo !z!
	echo !z!>>%log%
)
echo ## %DATE% %TIME%: Done.>>%log%
endlocal
goto :EOF

:Phase2
call :Apply %1
if /I NOT "%choice%"=="S" goto :EOF
set choice=
if DEFINED NoVista (
	echo This function needs Vista to run.
	goto :EOF
)
if DEFINED ln (
	echo Missing ln.exe command.
	goto :EOF
)
setlocal
echo Phase 2: Scanning...
echo.>>%log%
echo ## %DATE% %TIME%: Started phase 2 scan.>>%log%
call :OpenWindow Phase_2:_Scanning...
cd /D %winsxs%
dir /B /AD-L >%buf%
call :EchoWindow "."
echo OFF >%ABuf%
set LangNr=499
set score=0
for /F "usebackq delims=" %%a IN (%buf%) DO (
	set name=
	set z=%%a
	for /L %%b IN (1,1,10) DO if DEFINED z for /F "delims=_ tokens=1-5*" %%c IN ("!z!") DO (
		if "%%h"=="" (
			if NOT "%%g"=="" (
				for /F "delims=. tokens=1-3*" %%i IN ("%%e") DO (
					set sibling1=00%%i
					set sibling2=000000%%j
					set sibling3=000000%%k
					set sibling4=000000%%l
				)
				if NOT DEFINED LangCode%%f (
					set LangCode%%f=!LangNr!
					set /A LangNr-=1
				)
				set /A score+=1
				if NOT EXIST !BusyWindow! call :EchoWindow " !score! winsxs folders parsed."
				echo !name!%%c/!LangCode%%f!/!sibling1:~-2!!sibling2:~-6!!sibling3:~-6!!sibling4:~-6!/%%a>>%ABuf%
			)
			set z=
		) ELSE (
			set name=!name!%%c_
			set z=%%d_%%e_%%f_%%g_%%h
)	)	)
call :EchoWindow " !score! winsxs folders parsed."
call :EchoWindow "."
echo OFF >%buf%
for /F "delims== tokens=1,2" %%a IN ('"set LangCode 2>NUL"') DO echo %%b/%%a>>%buf%
call :EchoWindow " Language codes found:"
echo OFF >"%home%$LanguageStrings.txt"
set language=
for /F "delims=/ tokens=1,2" %%a IN ('sort /L ""C"" /R %buf%') DO (
	set z= %%a
	set z= !z: 0=!
	set /A z=!z: 0=!
	if !z! LEQ 499 (
		set z=%%b
	) ELSE set z=%%b=BASE
	set z=!z:LangCode=!
	if DEFINED LangKeep%%a set z=!z!=KEEP
	echo !z!>>"%home%$LanguageStrings.txt"
	set z=!z!                  
	set language=!language!!z:~0,19!
	if NOT "!language:~57,1!"=="" (
		call :EchoWindow " !language!"
		set language=
)	)
if DEFINED language call :EchoWindow " %language%"
sort /L ""C"" /R %ABuf% /O %ABuf%
call :EchoWindow "."
echo OFF >%BBuf%
set freed=0
set files=0
set count=0
set HighID=
for /F "usebackq delims=/ tokens=1,2,4" %%a IN (%ABuf%) DO (
	set /A files+=1
	if NOT EXIST !BusyWindow! (
		set /A z=files*1000/%score%
		if !z! GEQ 30 (
			for /F "delims=:., tokens=1-3,5-7" %%c IN ("!TIME::0=:!:%TIME::0=:%") DO set /A valid=%%c*3600+%%d*60+%%e-%%f*3600-%%g*60-%%h
			if !valid! LSS 0 set /A valid+=86400
			set /A valid=%score%*1000/files*valid/1000-valid
			set /A target=valid/3600
			set /A valid-=target*3600
			set /A score=valid/60
			set /A valid-=score*60
			set target= !target!
			set score=0!score!
			set valid=0!valid!
			set valid=  Est. time remaining: !target:~-2!:!score:~-2!:!valid:~-2!
		) ELSE set valid=
		set z=   !z:~0,-1!.!z:~-1!
		set z=!z: .=0.!
		set files=      !files!
		call :EchoWindow " !z:~-5!%%%%,    !files:~-7! files processed.!valid!"
		set /A "z=(freed*25+32)/64"
		set z=  !z!
		set z=!z:~0,-2!.!z:~-2!
		set z=!z:. 0=0   !
		set z=!z:. =.0!
		set z=!z: .=0.!
		set z=    !z!
		set count=      !count!
		call :EchoWindow "      !count:~-7! hardlinks to create.			  Will free!z:~-8! MB."
	)
	if /I "!HighID!"=="%%a" (
		if NOT !PrevLang!==%%b (
			if !PrevLang! GEQ 500 set BasePathList=!BasePathList!!PrevLang! 
			set LangPath%%b=
			set HighPathList=
		) ELSE set HighPathList=%%b
		if NOT DEFINED LangKeep%%b set HighPathList=!BasePathList!!HighPathList!
		if DEFINED HighPathList (
			dir /B /S /A-D-L "%%c" 2>NUL >%ABuf%
			for /F "usebackq delims=" %%d IN (%ABuf%) DO (
				set HighFile=
				set z=%%d
				for %%h IN (!HighPathList!) DO if NOT DEFINED HighFile (
					set HighPath=!LangPath%%h!
					for /F "delims=\ tokens=1*" %%i IN ("!z:%winsxs%=!") DO set HighFile=%%~$HighPath:j
					if DEFINED HighFile (
						set valid=
						set z=0
						ln.exe -l "%%d">%buf%
						for /F "usebackq skip=1 delims=\: tokens=1*" %%f IN (%buf%) DO if DEFINED z if NOT "%%f"=="ERROR" if /I NOT "%%f:\%%g"=="!HighFile!" (
							set /A z+=1
							set sibling!z!=%%f:\%%g
							if NOT DEFINED valid if /I NOT "%%f:\%%g"=="%%d" (
								set target=%%f:\%%g
								if NOT "!target:%winsxs%=!"=="%%f:\%%g" for /F "delims=\" %%i IN ("!target:%winsxs%=!") DO (
									set target=%%i
									if NOT "!target:_=!"=="%%i" set valid=0
								)
							) ELSE set valid=1
						) ELSE set z=
						if DEFINED z (
							for /L %%i IN (1,1,!z!) DO echo !HighFile!/!sibling%%i!>>%BBuf%
							if "!valid!"=="1" (
								set /A count+=z
								set /A "freed+=(%%~zd+4095)/4096"
		)	)	)	)	)	)
	) ELSE (
		set HighID=%%a
		set BasePathList=
		set LangPath%%b=
	)
	set LangPath%%b=!LangPath%%b!%%c;
	set PrevLang=%%b
)
cd /D %home%
set files=      %files%
call :EchoWindow " 100.0%%%%,    %files:~-7% files processed."
set /A "z=(freed*25+32)/64"
set z=  %z%
set z=%z:~0,-2%.%z:~-2%
set z=%z:. 0=0   %
set z=%z:. =.0%
set z=%z: .=0.%
set z=    %z%
set count=      %count%
call :EchoWindow "      %count:~-7% hardlinks to create.			  Will free%z:~-8% MB."
set score=%z: =%
call :EchoWindow "."
call :EchoWindow " Making adjustments..."
call :EchoWindow "."
echo OFF >%ABuf%
set old=
for /F "delims=/ tokens=1,2" %%a IN ('sort /L ""C"" %BBuf%') DO (
	set z=%%a
	for /F "delims=\" %%c IN ("!z:%winsxs%=!") DO if /I NOT "%%c"=="!old!" (
		set z=%%c
		for /L %%d IN (1,1,10) DO if DEFINED z for /F "delims=_ tokens=1-5*" %%e IN ("!z!") DO (
			if "%%j"=="" (
				for /F "delims=. tokens=1-3*" %%k IN ("%%g") DO (
					set sibling1=00%%k
					set sibling2=000000%%l
					set sibling3=000000%%m
					set sibling4=000000%%n
				)
				set version=!sibling1:~-2!!sibling2:~-6!!sibling3:~-6!!sibling4:~-6!
				set z=
			) ELSE set z=%%f_%%g_%%h_%%i_%%j
		)
		set old=%%c
	)
	echo %%b/!version!/%%a>>%ABuf%
)
echo OFF >%BBuf%
set z=
for /F "delims=/ tokens=1,3" %%a IN ('sort /L ""C"" /R %ABuf%') DO if /I NOT "%%a"=="!z!" (
	set z=%%a
	echo %%a/1/1/%%b>>%BBuf%
	echo %%b/2/1/%%a>>%BBuf%
)
echo OFF >%ABuf%
set valid=2
:DeChain
sort /L ""C"" %BBuf% /O %buf%
echo OFF >%BBuf%
set z=
for /F "usebackq delims=/ tokens=1-4" %%a IN (%buf%) DO if %%b==1 (
	set z=%%a
	set target=%%d
	set old=%%c
	echo %%a/1/%%c/%%d>>%BBuf%
) ELSE if /I NOT "%%a"=="!z!" (
	echo %%a/%%d>>%ABuf%
	set valid=2
) ELSE if !valid! GTR 0 (
	if /I NOT "%%d"=="!target!" (
		if !old!==2 (
			echo !target!/%%d>>%ABuf%
			echo %%d/1/2/!target!>>%BBuf%
			set valid=2
		) ELSE echo !target!/2/1/%%d>>%BBuf%
	) ELSE if NOT !old!==2 echo %%a/2/1/%%d>>%BBuf%
) ELSE (
	echo %%a/%%d>>%ABuf%
	echo %%d/1/2/%%a>>%BBuf%
	echo %%a/1/2/%%a>>%BBuf%
	set valid=2
)
if !valid! GTR 0 (
	set /A valid-=1
	goto DeChain
)
echo OFF >%1
set count=No
for /F "delims=/ tokens=1,2" %%a IN ('sort /L ""C"" %ABuf%') DO (
	set /A count+=1
	echo !count!/%%~pnxb/%%~pnxa>>%1
)
attrib -a %1
call :EchoWindow " %count% hardlinks to create. Will free %score% MB."
call :CloseWindow
echo %count% lines written to %1.
echo %count% lines written to %1.>>%log%
if NOT %freed%==0 (
	set z=Applying this scan will free %score% MB.
	echo !z!
	echo !z!>>%log%
)
echo ## %DATE% %TIME%: Done.>>%log%
endlocal
goto :EOF

:RelocFolders
if DEFINED NoVista (
	echo This function needs Vista to run.
	goto :EOF
)
set error=
if DEFINED movefile set error=movefile
if DEFINED pendmoves set error=pendmoves
if DEFINED ln set error=ln
if DEFINED subinacl set error=subinacl
if DEFINED error (
	echo Missing %error%.exe command.
	goto :EOF
)
if NOT EXIST "%reloc:~0,2%" (
	echo Can't relocate folders to "%reloc%" - drive not found.
	goto :EOF
)
set z=0
for /F %%a IN ('fsutil FSINFO NTFSINFO %reloc:~0,2%') DO set /A z+=1
if %z% LSS 5 (
	echo Target drive %reloc:~0,2% needs to be NTFS.
	goto :EOF
)
set z=
for %%a IN (%RelocPaths%) DO (
	set valid=
	for /F "delims=" %%b IN ('"dir /AD-L /B "%%~dpa" 2>NUL"') DO if /I "%%b"=="%%~nxa" (
		set z=!z! %%a
		set valid=1
	)
	if NOT DEFINED valid for /F "delims=> tokens=2" %%b IN ('"dir /AD-L /X "%%~dpa" 2>NUL"') DO (
		set valid=%%b
		for /F %%c IN ("!valid:~10,13!") DO if /I "%%c"=="%%~nxa" set z=!z! %%a
)	)
if NOT DEFINED z (
	echo Nothing to relocate.
	goto :EOF
)
echo Going to perform the following folder relocations:
echo.
for %%a IN (%z%) DO (
	echo     %%a
	echo ==^> "%reloc%%%~pnxa"
	echo.
)
set /P choice=Proceed - [Y]es/[N]o ? 
if /I NOT "%choice%"=="Y" goto :EOF
setlocal
echo.>>%log%
echo ## %DATE% %TIME%: Relocating folders.>>%log%
set RelocPaths=%z%
echo OFF >%important%
for %%a IN (%RelocPaths%) DO (
	cd /D %%~da\
	set z=%%~dpa
	subinacl.exe /nov /nos /fil "!z:~0,-1!" /dis=sddl >>%important%
	subinacl.exe /nov /nos /fil %%a /dis=sddl >>%important%
)
echo.>%ABuf%
echo OFF >%BBuf%
echo OFF >%ToSchedule%
set typeJUNCTION=/J
set typeSYMLINKD=/D
set typeSYMLINK=
set old= 
for %%a IN (%RelocPaths%) DO (
	echo.
	echo Copying %%a
	echo      to "%reloc%%%~pnxa"...
	echo Copying %%a to "%reloc%%%~pnxa"...>>%log%
	if EXIST "%reloc%%%~pnxa" (
		set z=The target folder already exists - aborting relocation.
		echo !z!
		echo !z!>>%log%
		set RelocPaths=!RelocPaths:%%a=!
	) ELSE (
		md "%reloc%%%~pnxa"
		if NOT EXIST "%reloc%%%~pnxa" (
			set z=Failed to create destination folder - aborting relocation.
			echo !z!
			echo !z!>>%log%
			set RelocPaths=!RelocPaths:%%a=!
		) ELSE (
			call :DirSetWD "%reloc%%%~pnxa"
			set valid=1
			robocopy %%a "%reloc%%%~pnxa" /E /B /COPY:DAT /DCOPY:T /SL /XJ /R:0 /NS /NC /NFL /NDL /NP /NJH /NJS >%buf%
			if ERRORLEVEL 4 (
				set /P choice=Errors encountered during copy - [A]bort/[C]omplete on reboot ? 
				if /I "!choice!"=="C" (
					echo %%~a/%reloc%%%~pnxa>>%ToSchedule%
				) ELSE set valid=
			)
			for %%b IN (%buf%) DO if %%~zb GTR 4 type %buf% >>%log%
			if NOT DEFINED valid (
				set z=Relocation aborted.
				echo !z!
				echo !z!>>%log%
				rd /S /Q "%reloc%%%~pnxa" >NUL 2>&1
				set RelocPaths=!RelocPaths:%%a=!
			) ELSE (
				set z=Scanning for, and copying, junctions and symbolic links...
				echo !z!
				echo !z!>>%log%
				echo OFF >%buf%
				for /F "delims=" %%b IN ('"dir /ADL /B /S %%a 2>NUL"') DO echo %%b\>>%buf%
				dir /AL /B /S %%a 2>NUL >>%buf%
				set dir=/
				for /F "delims=" %%b IN ('sort /L ""C"" %buf%') DO for %%i IN ("!dir!") DO (
					set z=%%b
					if "!z:%%~i=!"=="!z!" if NOT "!z:~-1!"=="\" (
						dir /AL "!z:~0,-1!?" 2>NUL >%buf%
						for /F "usebackq delims=<> tokens=2,3" %%c IN (%buf%) DO (
							set z=%%c%%d
							for /F "delims=: tokens=1*" %%e IN ("!z:~13,-1!") DO if NOT "%%f"=="" (
								set valid=%%e
								set z=!valid:~-1!:%%f
								set valid=!valid:~0,-3!
							) ELSE for /F "delims=[ tokens=1*" %%g IN ("%%e") DO (
								set valid=%%g
								set z=%%h
								set valid=!valid:~0,-1!
							)
							if /I "!valid!"=="%%~nxb" (
								mklink !type%%c! "%reloc%%%~pnxb" "!z!" >NUL 2>&1
								attrib "%%b" /L >%buf%
								for /F "usebackq delims=" %%e IN (%buf%) DO set z=%%e
								if /I "!z:~13!"=="%%b" (
									set z= +!z:~0,1! +!z:~3,1! +!z:~4,1! +!z:~5,1! +!z:~8,1!
									set z=!z: + =!
									attrib -a -i "%reloc%%%~pnxb" /L >NUL
									attrib !z! "%reloc%%%~pnxb" /L >NUL
						)	)	)
					) ELSE set dir=%%b
				)
				for /F "delims=\ tokens=1,2" %%b IN ("%%~a\") DO if "!old:"%%b\%%c"=!"=="!old!" set old=!old! "%%b\%%c"
				set z=Scanning for preservable hardlinks...
				echo !z!
				echo !z!>>%log%
				echo OFF >%buf%
				for /F "delims=" %%b IN ('"dir /ADL /B /S %%a 2>NUL"') DO echo %%b\>>%buf%
				dir /A-D /B /S %%a 2>NUL >>%buf%
				set dir=/
				for /F "delims=" %%b IN ('sort /L ""C"" %buf%') DO for %%f IN ("!dir!") DO (
					set z=%%b
					if "!z:%%~f=!"=="!z!" if NOT "!z:~-1!"=="\" (
						ln.exe -l "%%b">%buf%
						set valid=
						set done=
						for /F "usebackq skip=1 delims=\: tokens=1*" %%c IN (%buf%) DO if NOT "!valid!"=="0" (
							set z=%%c:\%%d
							for %%e IN (%RelocPaths%) DO if DEFINED z if NOT "!z:%%~e\=!"=="!z!" set z=
							if NOT DEFINED z (
								if DEFINED valid (
									echo %reloc%\%%d/%reloc%%%~pnxb>>%BBuf%
								) ELSE if /I "%%c:\%%d"=="%%b" (
									set valid=1
								) ELSE set valid=0
							) ELSE if NOT DEFINED done set done=%%c:\%%d
						)
						if DEFINED done if "!valid!"=="1" (
							echo +fil !done!>>%ABuf%
							echo /dis=sddl>>%ABuf%
						)
					) ELSE set dir=%%b
				)
				for /F "usebackq delims=/ tokens=1,2" %%b IN (%BBuf%) DO if EXIST "%%c" (
					del /F "%%b" >NUL 2>&1
					if EXIST "%%b" (
						attrib -s -h -r "%%b" /L >NUL
						del /F "%%b" >NUL 2>&1
)	)	)	)	)	)
if "%RelocPaths: =%"=="" (
	del /F %important% >NUL
	cd /D %home%
	echo ## %DATE% %TIME%: Done.>>%log%
	endlocal
	goto :EOF
)
echo.
set z=Restoring hardlinks where possible...
echo %z%
echo %z%>>%log%
for /F "usebackq delims=/ tokens=1,2" %%a IN (%BBuf%) DO %hlink% "%%a" "%%b" >NUL 2>&1
echo Done.
echo Done.>>%log%
echo Copying security...
echo Copying security...>>%log%
subinacl.exe /nov /nos /pla %ABuf% >>%important%
attrib +r +s %important% >NUL
for %%a IN (%old%) DO (
	subinacl.exe /nov /nos /sub "%reloc%%%~pnxa\*" /pathc=%%a >NUL
	subinacl.exe /nov /nos /fil "%reloc%%%~pnxa" /objectc=%%a >NUL
)
echo Done.
echo Done.>>%log%
set valid=1
for %%a IN (%RelocPaths%) DO (
	set z=Activating "%reloc%%%~pnxa"...
	echo !z!
	echo !z!>>%log%
	cd /D %%~da\
	set z=%%~dpa
	subinacl.exe /nov /nos /fil "!z:~0,-1!" /grant=s-1-1-0=F >NUL
	subinacl.exe /nov /nos /fil %%a /grant=s-1-1-0=F >NUL
	subinacl.exe /nov /nos /sub "%%~a\*" /grant=s-1-1-0=F >NUL
	mklink /J "%%~a.$RenameMe" "%reloc%%%~pnxa" >NUL 2>&1
	if ERRORLEVEL 1 (
		set z=Failed to create temporary junction "%%~a.$RenameMe"
		echo !z!
		echo !z!>>%log%
	) ELSE (
		subinacl.exe /nov /nos /fil "%%~a.$RenameMe" /grant=s-1-1-0=F >NUL
		call :ActivateJunction %%a
	)
	echo.
)
cd /D %home%
echo ## %DATE% %TIME%: Done.>>%log%
if NOT DEFINED valid (
	echo Reboot to complete the folder relocation.
	for %%a IN (%ToSchedule%) DO if %%~za GTR 0 call :SetStartup
	echo.
	endlocal
	pause
	exit
)
attrib -r -s %important% >NUL
call :RestoreSDs Restoring security...
endlocal
goto :EOF

:ActivateJunction
if EXIST "%~1.$RenameMe" (
	attrib -s -h -r %1 /L >NUL
	ren %1 "%~nx1.$DeleteMe" 2>NUL
	if NOT EXIST %1 ren "%~1.$RenameMe" "%~nx1" 2>NUL
	if EXIST "%~1.$RenameMe" ren "%~1.$DeleteMe" "%~nx1" 2>NUL
)
if EXIST "%~1.$RenameMe" (
	movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
	movefile.exe %1 "%~1.$DeleteMe" >NUL
	movefile.exe "%~1.$RenameMe" %1 >NUL
	movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
	set z=Scheduled for activation on reboot.
	echo !z!
	echo !z!>>%log%
	set valid=
)
if EXIST %1 if EXIST "%~1.$DeleteMe" (
	robocopy "%reloc%%~pnx1" %1 /B /COPY:AT /DCOPY:T /CREATE /SL /XJ /R:0 /NS /NC /NFL /NDL /NP /NJH /NJS >NUL
	robocopy "%reloc%%~pnx1" "%~1.$DeleteMe" /B /COPY:AT /DCOPY:T /CREATE /SL /XJ /R:0 /NS /NC /NFL /NDL /NP /NJH /NJS >NUL
	if EXIST %ToSchedule% for /F "usebackq delims=/" %%A IN (%ToSchedule%) DO if "%%A"==%1 (
		echo Copying %1
		echo      to "%reloc%%~pnx1"...
		echo Copying %1 to "%reloc%%~pnx1"...>>%log%
		robocopy "%~1.$DeleteMe" "%reloc%%~pnx1" /E /B /COPY:DAT /SL /XJ /XC /XN /XO /R:0 /NS /NC /NFL /NDL /NP /NJH /NJS >%buf%
		for %%B IN (%buf%) DO if %%~zB GTR 4 type %buf% >>%log%
	)
	set z=Removing deactivated %1...
	echo !z!
	echo !z!>>%log%
	call :EraseDir "%~1.$DeleteMe"
)
goto :EOF

:EraseDir
rd /S /Q %1 >NUL 2>&1
if NOT EXIST %1 goto :EOF
set valid=
attrib -r -s -h %1 /L >NUL
echo OFF >%buf%
for /F "delims=" %%A IN ('"dir /ADL /B /S %1 2>NUL"') DO echo %%A\>>%buf%
dir /AR /B /S %1 2>NUL >>%buf%
set dir=/
for /F "delims=" %%A IN ('sort /L ""C"" %buf%') DO for %%B IN ("!dir!") DO (
	set z=%%A
	if "!z:%%~B=!"=="!z!" if NOT "!z:~-1!"=="\" (
		attrib "%%A" /L >%buf%
		for /F "usebackq delims=" %%C IN (%buf%) DO set z=%%C
		if /I "!z:~13,3!"=="%%~dA\" (
			set z= +!z:~3,1! +!z:~4,1!
			set z=!z: + =!
			attrib -r!z! "%%A" /L >NUL
		)
	) ELSE set dir=%%A
)
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
echo OFF >%buf%
for /F "delims=" %%A IN ('"dir /ADL /B /S %1 2>NUL"') DO echo %%A\>>%buf%
dir /A-D /B /S %1 2>NUL >>%buf%
set dir=/
for /F "delims=" %%A IN ('sort /L ""C"" %buf%') DO for %%B IN ("!dir!") DO (
	set z=%%A
	if "!z:%%~B=!"=="!z!" if NOT "!z:~-1!"=="\" (
		movefile.exe "%%A" "" >NUL
	) ELSE set dir=%%A
)
echo OFF >%buf%
for /F "delims=" %%A IN ('"dir /ADL /B /S %1 2>NUL"') DO echo %%A\>>%buf%
dir /AD /B /S %1 2>NUL >>%buf%
echo >>%buf%
set dir=/
for /F "delims=" %%A IN ('sort /L ""C"" %buf%') DO if NOT "%%A"=="" for %%B IN ("!dir!") DO (
	set z=%%A
	if "!z:%%~B=!"=="!z!" if NOT "!z:~-1!"=="\" (
		echo %%A>>%buf%
	) ELSE set dir=%%A
) ELSE echo OFF >%buf%
sort /L ""C"" /R %buf% /O %buf%
for /F "usebackq delims=" %%A IN (%buf%) DO movefile.exe "%%A" "" >NUL
movefile.exe %1 "" >NUL
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
set z=Remainder scheduled for removal on reboot.
echo %z%
echo %z%>>%log%
goto :EOF

:RestoreSDs
echo   %*
subinacl.exe /nov /nos /pla %important% >NUL
move /Y %important% %unimportant% >NUL
echo   Done.
goto :EOF

:DirSetWD
subinacl.exe /nov /nos /fil %1 /sddl=D:PARAI(A;OICI;FA;;;WD) >NUL
goto :EOF

:WinsxsSize
set choice=
if DEFINED ReParse (
	echo "%winsxs:~0,-1%" is a reparse point to !ReParse!
	goto :EOF
)
if DEFINED NoVista (
	echo This function needs Vista to run.
	goto :EOF
)
if DEFINED ln (
	echo Missing ln.exe command.
	goto :EOF
)
setlocal
echo.>>%log%
echo ## %DATE% %TIME%: Calculating folder sizes.>>%log%
set z=
for /F "delims=: tokens=2" %%a IN ('fsutil VOLUME DISKFREE %rootd%') DO set z=!z!%%a
for /F "tokens=2,3" %%a IN ("%z%") DO (
	set total=%%a0
	set unique=%%b0
)
set z= %total:~-4%
set z=%z: 0= %
set z=%z: 0= %
set z=%z: 0= %
set total=%total:~0,-4%
set /A "total=((2500*(total&0x3FFFF)+(%z%+1)/4+0x1FFFF)>>18)+2500*(total>>18)"
set z= %unique:~-4%
set z=%z: 0= %
set z=%z: 0= %
set z=%z: 0= %
set unique=%unique:~0,-4%
set /A "unique=((2500*(unique&0x3FFFF)+(%z%+1)/4+0x1FFFF)>>18)+2500*(unique>>18)"
set /A z=total-unique
set z= %z:~0,-1%.%z:~-1%
set z=%z: .=0.%
set unique= %unique:~0,-1%.%unique:~-1%
set unique=%unique: .=0.%
set z= %z: =% MB used,  %unique: =% MB free space on drive %rootd%
echo %z%
echo.
echo %z%>>%log%
set SizePaths="%winsxs%Temp" "%winsxs%InstallTemp" "%winsxs%ManifestCache" "%winsxs%FileMaps" "%winsxs%Catalogs" "%winsxs%Manifests" "%winsxs%Backup" "%winsxs:~0,-1%"
set SizePaths=!SizePaths:%rootd%\=!
dir /AD-L /B /S "%winsxs%" >%ABuf%
find /V "=" %ABuf% >%BBuf%
set z=%winsxs:~0,-1%
echo %z:\=%>%ABuf%
for /F "usebackq skip=2 delims=" %%a IN (%BBuf%) DO (
	set z=%%a
	echo !z:\=!>>%ABuf%
)
set z=     Unique         Shared              Folder
echo %z%
echo %z%>>%log%
echo OFF >%BBuf%
set old=%root%\%win%\
for /F "delims=" %%a IN ('sort /L ""C"" %ABuf%') DO (
	set z=%%a
	for %%b IN ("!z:=\!") DO if NOT "!old:%%~dpb=!"=="!old!" (
		set old=%%~b\
		echo -/%%~b>>%BBuf%
		dir /A-D-L /B %%b 2>NUL >>%BBuf%
)	)
find /V "=" %BBuf% >%ABuf%
set z=-----------------------------------------------------------------
echo %z%
echo %z%>>%log%
echo OFF >%BBuf%
for /F "usebackq skip=2 delims=/ tokens=1*" %%a IN (%ABuf%) DO if "%%b"=="" (
	for %%c IN ("!z!\%%a") DO if NOT "%%~zc"=="" echo %%~zc%%~pnxc>>%BBuf%
) ELSE set z=%%b
sort /L ""C"" %BBuf% /O %ABuf%
set total=0
for %%a IN (%SizePaths%) DO (
	set unique=0
	set shared=0
	if %%a=="%winsxs:~3,-1%" (
		sort /L ""C"" %ABuf% /O %ABuf%
		echo ->>%ABuf%
		echo ->%BBuf%
		echo ->>%BBuf%
		set valid=
		set z=
		for /F "usebackq delims=" %%b IN (%ABuf%) DO if /I NOT "%%b"=="!z!" (
			if DEFINED valid (
				echo !z!>>%BBuf%
			) ELSE set valid=1
			set z=%%b
		) ELSE set valid=
	) ELSE find "\%%~a\" %ABuf% >%BBuf%
	for /F "usebackq skip=2 delims=\ tokens=1*" %%b IN (%BBuf%) DO if "!\%%c!"=="" (
		set valid=1
		ln.exe -l "%rootd%\%%c">%buf%
		for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO if /I NOT "%%e"=="%%c" (
			set z=\%%e
			if NOT "!z:\%%~a\=!"=="!z!" (
				set \%%e=1
			) ELSE set valid=
		)
		if DEFINED valid (
			if NOT %%a=="%winsxs:~3,-1%" for /F "usebackq skip=1 delims=\: tokens=1*" %%d IN (%buf%) DO echo %%b\%%e>>%ABuf%
			set /A "unique+=(%%b+4095)/4096"
		) ELSE set /A "shared+=(%%b+4095)/4096"
	) ELSE set \%%c=
	set /A total+=unique
	if %%a=="%winsxs:~3,-1%" set unique=!total!
	set /A "z=(shared*25+32)/64"
	set z=        !z!
	set z=!z:~0,-2!.!z:~-2!
	set z=!z:. =.0!
	set shared=!z: .=0.!
	set /A "z=(unique*25+32)/64"
	set z=        !z!
	set z=!z:~0,-2!.!z:~-2!
	set z=!z:. =.0!
	set unique=!z: .=0.!
	set z=!unique:~-10! MB  !shared:~-10! MB    "%rootd%\%%~a"
	echo !z!
	echo !z!>>%log%
)
set z=-----------------------------------------------------------------
echo %z%
echo %z%>>%log%
echo ## %DATE% %TIME%: Done.>>%log%
endlocal
goto :EOF

:ClearLinksDir
call :ClearReg
if DEFINED error goto :EOF
setlocal
echo Deleting hardlinks from "%LinksDir:~0,-1%"...
set scheduled=
set count=No
set MissingFile=
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
for /F "usebackq delims=/ tokens=1,2" %%a IN (%ToSchedule%) DO if EXIST "%LinksDir%%%a" if EXIST "%rootd%%%b" (
	set /A count+=1
	del /F "%LinksDir%%%a" >NUL 2>&1
	if EXIST "%LinksDir%%%a" (
		for /F "delims=" %%d IN ('attrib "%LinksDir%%%a"') DO set z=%%d
		if "!z:~5,1!"=="R" attrib -r -s -h "%LinksDir%%%a" >NUL
		set /A scheduled+=1
		movefile.exe "%LinksDir%%%a" "" >NUL
	)
) ELSE (
	move /Y "%LinksDir%%%a" "%rootd%%%b" >NUL 2>&1
	if NOT EXIST "%rootd%%%b" set /A MissingFile+=1
)
movefile.exe "%LinksDir%$Mark" "%LinksDir%$Mark" >NUL
if DEFINED scheduled (
	set /A z=count-scheduled
	echo !z! hardlinks out of !count! were deleted.
	echo The remaining !scheduled! hardlinks were scheduled for deletion on reboot.
) ELSE echo !count! hardlinks were deleted.
if DEFINED MissingFile (
	echo !MissingFile! hardlinks weren't deleted, because the files they're meant to replace,
	echo don't exist anymore, and for some reason they couldn't be moved to solve this.
	echo It's important that these hardlinks are activated.
)
endlocal
goto :EOF

:ClearReg
set error=true
setlocal
echo Clearing pending WinsxsLite file operations from registry...
set valid=true
set z=
for /F "delims=: tokens=1,2*" %%A IN ('"pendmoves.exe 2>NUL"') DO (
	if NOT DEFINED z (
		reg DELETE "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /V "PendingFileRenameOperations" /F >NUL 2>&1
		reg QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /V "PendingFileRenameOperations" >NUL 2>&1
		if NOT ERRORLEVEL 1 (
			echo Unable to clear pending file delete and rename operations in registry.
			endlocal
			goto :EOF
		)
		set z=/
	)
	if "%%A"=="Source" (
		set z=%%B
		set source="!z:~1!:%%C"
	) ELSE (
		set target=
		if "%%A"=="Target" (
			set z=%%B
			set target="!z:~1!:%%C"
		) ELSE if "%%B"==" Target" (
			set z=%%C
			set target="!z:~1!"
		)
		if DEFINED target (
			if DEFINED valid (
				if /I NOT !source!=="%LinksDir%$Mark" (
					if !target!=="DELETE" set target=""
					movefile.exe !source! !target! >NUL
				) ELSE set valid=
			) ELSE if /I !source!=="%LinksDir%$Mark" set valid=true
)	)	)
endlocal
set error=
echo Done.
goto :EOF

:SetStartup
if DEFINED NoVista goto :EOF
setlocal
echo WinsxsLite has been scheduled to run on reboot.
set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0
if DEFINED AutoStarted (
	for /F "delims=\ tokens=12" %%A IN ('"reg QUERY "%z%" /F "ClearAutoStart" /S /D 2>NUL"') DO (
		reg ADD "%z%\%%A" /F /V "Parameters" /D "AutoReboot" >NUL 2>&1
		reg ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\%%A" /F /V "Parameters" /D "AutoReboot" >NUL 2>&1
	)
	endlocal
	goto :EOF
)
call :ClearStartup
set valid=-1
for /F "delims=\ tokens=12" %%A IN ('"reg QUERY "%z%" /F "*" /K 2>NUL"') DO if %%A GTR !valid! set valid=%%A
set /A valid+=1
set AutoStart=0
set /A ClearAutoStart=valid+1
for /L %%A IN (1,1,2) DO (
	set count=!valid!
	for /L %%B IN (!valid!,-1,1) DO (
		set /A count-=1
		reg COPY "!z!\!count!" "!z!\%%B" /S /F >NUL 2>&1
		reg DELETE "!z!\!count!" /F >NUL 2>&1
	)
	reg ADD "!z!" /F /V "GPO-ID" /D "LocalGPO" >NUL 2>&1
	reg ADD "!z!" /F /V "SOM-ID" /D "Local" >NUL 2>&1
	reg ADD "!z!" /F /V "FileSysPath" /D "%root%\%win%\System32\GroupPolicy\Machine" >NUL 2>&1
	reg ADD "!z!" /F /V "DisplayName" /D "Local Group Policy" >NUL 2>&1
	reg ADD "!z!" /F /V "GPOName" /D "Local Group Policy" >NUL 2>&1
	for %%B IN (AutoStart ClearAutoStart) DO (
		reg ADD "!z!\!%%B!" /F /V "Script" /D %WinsxsLite% >NUL 2>&1
		reg ADD "!z!\!%%B!" /F /V "Parameters" /D "%%B" >NUL 2>&1
		reg ADD "!z!\!%%B!" /F /V "ExecTime" /T REG_BINARY /D 00000000000000000000000000000000 >NUL 2>&1
	)
	set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0
)
set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
reg ADD "%z%" /F /V "MaxGPOScriptWait" /T REG_DWORD /D 0 >NUL 2>&1
reg ADD "%z%" /F /V "HideStartupScripts" /T REG_DWORD /D 0 >NUL 2>&1
reg ADD "%z%" /F /V "RunStartupScriptSync" /T REG_DWORD /D 1 >NUL 2>&1
endlocal
goto :EOF

:ClearStartup
if DEFINED NoVista goto :EOF
setlocal
set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0
for /F "delims=\ tokens=12" %%A IN ('"reg QUERY "%z%" /F %WinsxsLite% /S /D 2>NUL"') DO (
	reg DELETE "%z%\%%A" /F >NUL 2>&1
	reg DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\%%A" /F >NUL 2>&1
)
echo OFF >%buf%
for /F "delims=\ tokens=12" %%A IN ('"reg QUERY "%z%" /F "*" /K 2>NUL"') DO (
	set count=   %%A
	echo !count:~-4!>>%buf%
)
sort /L ""C"" %buf% /O %buf%
set count=0
for /F "usebackq" %%A IN (%buf%) DO (
	if NOT "%%A"=="!count!" (
		reg COPY "%z%\%%A" "%z%\!count!" /S /F >NUL 2>&1
		reg DELETE "%z%\%%A" /F >NUL 2>&1
		set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0
		reg COPY "!z!\%%A" "!z!\!count!" /S /F >NUL 2>&1
		reg DELETE "!z!\%%A" /F >NUL 2>&1
	)
	set /A count+=1
)
set z=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
reg DELETE "%z%" /F /V "MaxGPOScriptWait" >NUL 2>&1
reg DELETE "%z%" /F /V "HideStartupScripts" >NUL 2>&1
reg DELETE "%z%" /F /V "RunStartupScriptSync" >NUL 2>&1
endlocal
goto :EOF

:Help
echo OFF >"%home%Help.htm"
echo OFF >%ABuf%
set valid=
for /F "usebackq delims=" %%a IN (%WinsxsLite%) DO if DEFINED valid (
	if NOT "%%a"==":TEXTEND" (
		set z=%%a
		if NOT "!z:~0,1!"=="<" (
			for /F "delims=" %%b IN ("!z:¤=!") DO echo%%b>>%ABuf%
			if NOT "!z:¤=!"=="!z!" set "z= <A HREF="!z:*¤=!">!z:*¤=!</A>"
			set "z=!z:~1!<BR>"
		)
		if "!z:¤=!"=="!z!" echo !z!>>"%home%Help.htm"
	) ELSE set valid=
) ELSE if "%%a"==":TEXTBEGIN" set valid=1
if NOT "%1"=="NoShow" more %ABuf%
goto :EOF

:TEXTBEGIN
<HTML>
<HEAD>
<TITLE>WinsxsLite help</TITLE>
</HEAD>
<BODY>
¤¤.
<B>
 -------------------------Disclaimer/License------------------------------
</B>
.
 Version 1.87 was released August 26, 2011.
.
 First a word of warning:
 WinsxsLite is provided as is, and comes with no warranty.
 WinsxsLite makes irreversible changes to the entire system partition.
 The only way to undo these changes, is to restore the system partition
 from a backup taken before running WinsxsLite.
 By chosing to use WinsxsLite, you assume full responsibility for any ill
 effects that might arise from using it.
.
 You may use WinsxsLite for free, provided that it's for private use only.
.
 You may not use it, or part of it, commercially - that is, using it to
 support a business in any way - without reaching an agreement with me first.
.
 WinsxsLite is Copyright (C) 2009 Christian Bering Boegh
.
<B>
 -------------------------Contact/Donations-------------------------------
</B>
.
 For bug reports, suggestions, requests or comments in general, email me at:
.
  chrisberingb@live.com
.
<B>
 For the latest version, visit:
</B>
 ¤http://sites.google.com/site/winsxslite
.
 WinsxsLite is freeware, but if you value it, and want to reward me for my
 work, you might consider a donation via PayPal:
¤¤.
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_s-xclick">
<input type="hidden" name="hosted_button_id" value="2870530">
<input type="image" src="https://www.paypal.com/en_GB/i/btn/btn_donate_LG.gif" border="0" name="submit" alt="">
<img alt="" border="0" src="https://www.paypal.com/en_US/i/scr/pixel.gif" width="1" height="1">
</form>
¤¤ https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=2870530
¤¤.
<B>
 -------------------------Overview and phases-----------------------------
</B>
.
 WinsxsLite is meant as a tool to help reduce the size of winsxs in Vista.
.
 WinsxsLite is split into two phases.
 The first phase searches the Program Files and Windows folders for files,
 that are exactly identical to files in the winsxs folder.
.
 The second phase replaces all the old versions of each file in winsxs,
 with hardlinks to the highest version file.
 So, it will still seem like there's, say, 16 different versions of a
 particular file, but in reality, there's only one data object pointed to
 by 16 directory entries.
 Additionally, unused localized files can be eliminated, by replacing them
 with hardlinks to the corresponding files in other languages.
.
 Note: Both phases are optional.
.
 Note: If Vista SP1 is installed, make sure vsp1cln.exe has been run.
.
<B>
 -------------------------Scan and apply----------------------------------
</B>
.
 Each phase is split in two.
 The scan generates a ToDo list of files that should be replaced.
 After that, selecting apply will perform the changes described in the
 ToDo file.
.
 The apply option behaves differently, depending on whether the changes
 are to be made to an online system partition, or an offline one.
 Typically, WinsxsLite is asked to modify the current, running system.
.
 In that case (online), the apply function changes as much as it can,
 and schedules the remaining in-use files to be replaced at reboot.
 It's important that the system is rebooted when requested.
 So, a typical online-system session would look like this:
 Phase 1 scan
 Phase 1 apply
 Reboot
 Phase 2 scan
 Phase 2 apply
 Reboot
.
 It's easier in a multiboot system, where one can boot the second Vista,
 and then modify the first one.
 A typical offline-system session would look like this:
 Phase 1 scan
 Phase 1 apply
 Phase 2 scan
 Phase 2 apply
.
 No in-use files means no reboots.
.
 Note: Beware of outdated scans^!
       If the system is modified after a scan, that scan should be considered
       outdated, and a rescan should be performed before applying.
       Applying an outdated scan may corrupt the system.
.
 Note: If apply is operating in online mode, a few hardlinks may linger in
       the temporary C:\$ directory (if root=C:), even after a reboot.
       this is because a few system files get locked before pending file
       operations are performed during reboot.
       Running WinsxsLite again will then present the option to reschedule
       these files. Rescheduling also "shuffles" the files in each hardlink
       group, in an attempt to cure this problem.
       Sometimes, rescheduling may even save one from having to do the post-
       apply reboot in the first place.
.
       A related problem is the failure to delete a few obsolete hardlinks
       in C:\$, even during a reboot. This is because Vista mistakenly thinks
       they are locked, when in reality, it's the files they are linking to,
       that are locked. The only way to get rid of these hardlinks, is to put
       the partition offline and delete them manually.
.
 Note: Some functions, like the apply function, works under Windows XP.
.
<B>
 -------------------------Relocate folders--------------------------------
</B>
.
 This, the 3rd phase, takes care of data that is never used,
 or almost never used.
.
 There's no reason to keep more than a gigabyte of drivers on the system
 drive - particularly if it's a high performance SSD.
 The same goes for install packages left by certain software.
 Those will only be used again, if the software is ever uninstalled.
.
 See below for config options.
.
<B>
 -------------------------Auto start--------------------------------------
</B>
.
 This function schedules WinsxsLite to run automatically on the next reboot.
.
 It's very useful, because it runs before everything else, including logon.
 This means fewer files are locked, thus fewer 'access denied' issues.
.
 The folder relocate function will activate auto start if errors occurred
 during copies, and the user chose 'Complete on reboot'.
.
<B>
 -------------------------Configuration-----------------------------------
</B>
.
 The first time WinsxsLite is run, it creates an example configuration file.
 Close WinsxsLite, and review Config.txt to make sure it fits your needs.
.
 Note: Config.txt is only parsed once - during program startup.
       So, restart WinsxsLite for changes in Config.txt to take effect.
.
<B>
 The first section of the default Config.txt starts like this:
</B>
.
 :PHASE 1 EXCLUDES
 \desktop.ini/
 \system.ini/
 .log/
 .etl/
 .tmp/
 .nt/
 .config/
 \NTUSER.DAT
 \usrclass.dat
 $winsxs$\InstallTemp\
 $winsxs$\ManifestCache\
.
  (...)
.
 This tells phase 1 that certain files shouldn't be considered for replacement.
 The strings are matched against full paths, so specifying:
 \System32\DriverStore\
 - would exclude all files in that directory.
 The optional forward slash, that can be put at the end of a line, means
 only-match-against-end-of-full-path.
 $root$, $win$, $winsxs$ and $system32$ expands to the the various windows
 folder paths (like C: , C:\Windows and so on).
.
 Note: $Phase1Extensions.txt is generated as additional help to see what's
       going on. It contains almost the same information as ToDo1.txt,
       but sorted according to extensions.
.
 Note: Setting ':PROGRAM FILES DIR=' causes program files to be omitted
       during phase 1.
.
<B>
 The second section looks like this:
</B>
.
 :PHASE 2 LANGUAGE PRIORITIES
 en-us=KEEP
 en-gb
 da-dk=KEEP
 sv-se
 nb-no
 de-de
.
 This example defines six prioritized base languages - English-US,English-GB,
 Danish,Swedish,Bokmaal-Norwegian and German.
 English-US and Danish are marked as languages to KEEP.
 Thus, after running phase 2, all localized files, except Danish, will have
 been replaced with hardlinks to English-US.
.
 Why not just:
.
 :PHASE 2 LANGUAGE PRIORITIES
 en-us=KEEP
 da-dk=KEEP
.
 Under most circumstances, this would yield exactly the same results, except if
 English-US and Danish versions of some files are absent. In that case, it
 matters which language is down next on the list.
.
 Leaving this section empty - that is, not defining any base languages,
 will obviously cause all languages to be left alone during phase 2.
.
 Note: After a phase 2 scan, the help file $LanguageStrings.txt contains all
       the different language strings found in winsxs during the scan.
       The second part of a language string denotes the country.
       A list of two-character country codes can be found here:
       ¤http://www.theodora.com/country_digraphs.html
       - and language codes:
       ¤http://msdn.microsoft.com/en-us/library/ms533052(VS.85).aspx
.
<B>
 The last section:
</B>
.
 :RELOCATE FOLDERS=D:\
 $system32$\DriverStore\FileRepository
 $system32$\DriverStore\Temp
 $win$\Installer
.
 These defaults define the folder relocate target path to be the D: drive.
 It then specifies the folders to be moved.
 Note that the $system32$\DriverStore\en-US folder is omitted on purpose.
 It only contains hardlinks, that would turn into objects, if moved to D:
.
 Generally, avoid 'breaking' hardlinks, since the only result is wasted space
 on the target drive. After running phase 1 and 2 on a fresh Vista install,
 the \Program Files folder takes up around 10MB. Relocate it, and the
 broken hardlinks makes it balloon to 500MB.
 Of course, some software can't be prevented from installing a lot of data in
 \Program Files. If this becomes a problem, then just relocate that particular
 software.
.
 Be careful - WinsxsLite will try to relocate anything you ask it to.
.
<B>
 -------------------------Winsxs size-------------------------------------
</B>
.
 This function reports the true size of the winsxs folder.
.
 Explorer doesn't do this. If one puts a single 1MB object with 10 directory
 entries in the same folder, Explorer will report 10MB.
 That 1MB should be the correct answer, is obvious.
 But what if the 10 entries are scattered all over the directory tree ?
 Where is that 1MB truly located ?
.
 That's why two numbers are calculated:
.
 The "unique" number, is the size of all objects that only have directory
 entries in winsxs.
 If one deleted the winsxs folder, this would be the number of bytes freed.
.
 The "shared" number, is the size of all objects that have entries in both
 winsxs and in directories outside winsxs.
 Thus, deleting winsxs won't free any of these bytes, since the objects are
 still referenced from elsewhere. A filesystem object is only deallocated when
 its reference count reaches zero.
.
 Adding these two numbers together, one gets the total amount of bytes
 referenced from within winsxs.
 This isn't the number Explorer reports, because some objects are referenced
 more than once from within winsxs - and Explorer counts each reference.
.
 The results for the main subdirectories in winsxs are listed as well, and put
 in the log too.
.
 The bad news, is that this operation takes about 10 minutes to complete.
.
<B>
 -------------------------3rd party software------------------------------
</B>
.
 WinsxsLite makes use of certain pieces of third party software:
.
 SubInACL v5.2.3790.1180
 From Microsoft
 ¤http://www.microsoft.com/downloads/details.aspx?FamilyID=E8BA3E56-D8FE-4A91-93CF-ED6985E3927B&displaylang=en
 Make sure SubInAcl.exe is put where WinsxsLite can find it.
.
 PendMoves v1.1 and MoveFile v1.0
 By Mark Russinovich
 ¤http://technet.microsoft.com/en-us/sysinternals/bb897556.aspx
.
 Ln v2.6.5.0 - Command Line Hardlinks
 By Hermann Schinagl
 ¤http://schinagl.priv.at/nt/ln/ln.html#contact
 Note: Likely, the runtimes installed by vcredist are already on your system.
.
 Fcmp v1.6 - ATTENTION, DO NOT USE THE BUGGY V1.7^!^!^!
 By Greg Wittmeyer
 ¤http://gammadyne.com/cmdline.htm#fcmp
.
 MD5File
 By Robin Keir
 ¤http://keir.net/md5file.html
.
 StringConverter v1.2
 By Guillaume Bordier
 ¤http://www.gbordier.com/gbtools/stringconverter.htm
.
<B>
 -------------------------------------------------------------------------
</B>
</BODY>
</HTML>
:TEXTEND

:DEFAULTCONFIGBEGIN
.
 :PHASE 1 EXCLUDES
 \desktop.ini/
 \system.ini/
 .log/
 .etl/
 .tmp/
 .nt/
 .config/
 \NTUSER.DAT
 \usrclass.dat
 $winsxs$\InstallTemp\
 $winsxs$\ManifestCache\
 $winsxs$\Temp\
 $system32$\config\
 $system32$\SMI\Store\
 $win$\Temp\
 $win$\Debug\
 $win$\Logs\
 $win$\Prefetch\
 $win$\rescache\
 $win$\SchCache\
 $win$\SoftwareDistribution\
 $system32$\catroot2\
 $system32$\FxsTmp\
 $system32$\LogFiles\
 $system32$\Msdtc\KtmRmTm
 $system32$\wbem\Repository\
 $system32$\WDI\
 $system32$\winevt\
.
 :PHASE 2 LANGUAGE PRIORITIES
 en-us=KEEP
 en-gb
 da-dk=KEEP
 sv-se
 nb-no
 de-de
.
 :RELOCATE FOLDERS=D:\
 $system32$\DriverStore\FileRepository
 $system32$\DriverStore\Temp
 $win$\Installer
.
 :SEARCH FOR SAMPLE MEDIA IN WINSXS=YES
.
 :EOF
:DEFAULTCONFIGEND
