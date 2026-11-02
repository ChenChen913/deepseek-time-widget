#ifndef MyAppVersion
  #define MyAppVersion "1.2.0"
#endif
#ifndef MyAppVersionNumeric
  #define MyAppVersionNumeric "1.2.0.0"
#endif

[Setup]
AppId={{41779911-C827-495F-86E7-089C19F13756}
AppName=DeepSeek 时段挂件
AppVersion={#MyAppVersion}
AppVerName=DeepSeek 时段挂件 {#MyAppVersion}
AppPublisher=ChenChen913
AppPublisherURL=https://github.com/ChenChen913/deepseek-time-widget
AppSupportURL=https://github.com/ChenChen913/deepseek-time-widget/issues
AppUpdatesURL=https://github.com/ChenChen913/deepseek-time-widget/releases
DefaultDirName={localappdata}\Programs\DeepSeekClock
DefaultGroupName=DeepSeek 时段挂件
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=DeepSeekClock-Setup-v{#MyAppVersion}
SetupIconFile=..\assets\deepseek-clock.ico
UninstallDisplayIcon={app}\DeepSeekClock.exe
UninstallDisplayName=DeepSeek 时段挂件
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
LicenseFile=..\LICENSE
AppMutex=Local\DeepSeekClockWidget
CloseApplications=yes
RestartApplications=no
MinVersion=10.0
VersionInfoCompany=ChenChen913
VersionInfoDescription=DeepSeek 时段挂件安装程序
VersionInfoProductName=DeepSeek 时段挂件
VersionInfoVersion={#MyAppVersionNumeric}

[Languages]
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "开机自动启动挂件"; GroupDescription: "其他选项"; Flags: unchecked

[Files]
Source: "..\dist\app\DeepSeekClock.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\app\lib\DeepSeekTime.ps1"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\dist\app\lib\Schemes.ps1"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\dist\app\lib\SchemesPro.ps1"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\dist\app\holidays.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\app\assets\deepseek-clock.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\dist\app\DeepSeekClock.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\app\启动挂件.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\app\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\app\使用说明.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "..\dist\app\install.marker"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\DeepSeek 时段挂件"; Filename: "{app}\DeepSeekClock.exe"; WorkingDir: "{app}"; IconFilename: "{app}\DeepSeekClock.exe"
Name: "{group}\卸载 DeepSeek 时段挂件"; Filename: "{uninstallexe}"
Name: "{autodesktop}\DeepSeek 时段挂件"; Filename: "{app}\DeepSeekClock.exe"; WorkingDir: "{app}"; IconFilename: "{app}\DeepSeekClock.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "DeepSeekClockWidget"; ValueData: """{app}\DeepSeekClock.exe"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\DeepSeekClock.exe"; Description: "{cm:LaunchProgram,DeepSeek 时段挂件}"; Flags: nowait postinstall skipifsilent

[Code]
var
  RemoveUserData: Boolean;
  RunValue: String;

function IsSilentUninstall(): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    if (CompareText(ParamStr(I), '/SILENT') = 0) or (CompareText(ParamStr(I), '/VERYSILENT') = 0) then
      Result := True;
  end;
end;

function InitializeUninstall(): Boolean;
begin
  RemoveUserData := False;
  if not IsSilentUninstall() then
  begin
    RemoveUserData := MsgBox('是否同时删除设置和已同步的节假日数据？' + #13#10 +
      ExpandConstant('{userappdata}\DeepSeekClock'), mbConfirmation, MB_YESNO) = IDYES;
  end;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if RegQueryStringValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Run',
      'DeepSeekClockWidget', RunValue) then
    begin
      // 只删除指向本安装目录的自启项，避免误删便携版或旧版本的自启设置
      if CompareText(RunValue, '"' + ExpandConstant('{app}\DeepSeekClock.exe') + '"') = 0 then
      begin
        RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'DeepSeekClockWidget');
        RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', 'DeepSeekClockWidget');
      end;
    end;
    if RemoveUserData then
      DelTree(ExpandConstant('{userappdata}\DeepSeekClock'), True, True, True);
  end;
end;
