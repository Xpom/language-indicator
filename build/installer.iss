; Установщик Language Indicator (Inno Setup 6). Собирается из build\build.ps1:
;   ISCC /DAppVersion=0.1.0 /DSourceDir=dist\app /Odist build\installer.iss
; Тихая установка (обновление из программы): /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

#ifndef AppVersion
  #error Передайте /DAppVersion
#endif
#ifndef SourceDir
  #error Передайте /DSourceDir
#endif

#define AppName "Language Indicator"
#define AppExe "LanguageIndicator.exe"
; Имя задачи Планировщика — как в src\Autostart.ahk
#define TaskName "Language Indicator"

[Setup]
AppId={{6F3A2C1E-8B4D-4E7A-9C51-2D7E0B9F4A63}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Xpom
AppPublisherURL=https://github.com/Xpom/language-indicator
AppSupportURL=https://github.com/Xpom/language-indicator/issues
AppUpdatesURL=https://github.com/Xpom/language-indicator/releases
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\LanguageIndicator
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=LanguageIndicator-Setup-{#AppVersion}
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Индикатор закрываем сами ключом /quit: Restart Manager убил бы процесс, и в трее остался бы значок-призрак
CloseApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[InstallDelete]
; Старые ui и flags целиком заменяются новыми
Type: filesandordirs; Name: "{app}\ui"
Type: filesandordirs; Name: "{app}\flags"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"

[Run]
; Установщик уже с правами администратора — запускаем с ними же, без второго запроса UAC.
; Флаг postinstall без skipifsilent: после тихого обновления индикатор тоже запускается
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall runascurrentuser

[UninstallRun]
Filename: "{app}\{#AppExe}"; Parameters: "/quit"; Flags: runhidden waituntilterminated; RunOnceId: "Quit"
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""{#TaskName}"" /F"; Flags: runhidden waituntilterminated; RunOnceId: "DeleteTask"

[Code]
// Перед заменой файлов штатно закрываем работающий индикатор
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  if FileExists(ExpandConstant('{app}\{#AppExe}')) then begin
    Exec(ExpandConstant('{app}\{#AppExe}'), '/quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
    Sleep(500);
  end;
  Result := '';
end;
