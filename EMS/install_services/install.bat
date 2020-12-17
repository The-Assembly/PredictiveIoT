::Inputs:
::	(OPTIONAL) -wsems <wsems service name>
::	(OPTIONAL) -lsr <lsr service name>
:: Note missing args will be replaced with default values

:: set default values
set WSEMS_NAME="Thingworx_WSEMS"
set LSR_NAME="Thingworx_LSR"

:: check current input and set variables accordingly, _SET labels will handle shifting
:CONTROL
IF "%~1"=="" GOTO END_CONTROL
IF "%~1"=="-wsems" GOTO WSEMS_SET
IF "%~1"=="-lsr" GOTO LSR_SET
GOTO ERROR

:: set wsems service name if given
:WSEMS_SET
SHIFT
IF NOT "%~1"=="" set WSEMS_NAME="%~1"
SHIFT
GOTO CONTROL

:: set lsr service name if given
:LSR_SET
SHIFT
IF NOT "%~1"==""set LSR_NAME="%~1"
SHIFT
GOTO CONTROL

:: if the input is blank or invalid, 
:END_CONTROL

:: remove services if necessary
sc delete %WSEMS_NAME%
sc delete %LSR_NAME%

:: start wsems and lsr as services
echo "installing wsems.exe: %WSEMS_NAME% as a service"
sc create %WSEMS_NAME% binPath= "\"%CD%\..\wsems.exe\" -service -cfg \"%CD%\..\etc\config.json\"" DisplayName= %WSEMS_NAME% start= auto
echo "starting %WSEMS_NAME%"
net start %WSEMS_NAME%

echo "installing luaScriptResource.exe: %LSR_NAME% as a service"
sc create %LSR_NAME% binPath= "\"%CD%\..\luaScriptResource.exe\" -service -cfg \"%CD%\..\etc\config.lua\"" DisplayName= %LSR_NAME% start= auto
echo "starting %LSR_NAME%"
net start %LSR_NAME%

exit

:ERROR
echo "invalid argument"
exit
