unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Registry, Tlhelp32, ShlObj, ShFolder, ShellAPI;

type
  TForm1 = class(TForm)
    Edit1: TEdit;
    Label1: TLabel;
    Image1: TImage;
    Label2: TLabel;
    Edit2: TEdit;
    Button1: TButton;
    Button2: TButton;
    cbbResolution: TComboBox;
    Label3: TLabel;
    Button3: TButton;
    CheckBox1: TCheckBox;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    procedure EnumResolutions;
    procedure SetCurrentResolution;
  public
    procedure StartGame;
    procedure OpenWebSite;
    procedure Quit;
  end;

function WinExecAndWait(CmdLine: String; uCmdShow: Cardinal): Cardinal;
function GetPidByTaskName(ExeFileName: String): Integer;
function KillTask(ExeFileName: String): Integer;
function ProcessTerminate(dwPID: Cardinal): Boolean;
function Is64BitOS: Boolean;
function Path_ProgramFiles: String;
function MsgBox(Text: String; Caption: String = ''; Buttons: Integer = 0): Integer;
function MsgErr(Text: String): Integer;
function MsgFatal(Text: String): Integer;
function GetRegistryData(RootKey: HKEY; Key, Value: string): variant;
procedure SetRegistryData(RootKey: HKEY; Key, Value: string; RegDataType: TRegDataType; Data: variant);
function GetInstallDir(def: String): String;


var
  Form1: TForm1;

const
  LnBr = #13#10;

implementation

{$R *.dfm}
{$R manifest.res}



function WinExecAndWait(CmdLine: String; uCmdShow: Cardinal): Cardinal;
var
  zCmdLine: array[0..MAXWORD] of char;
  zCurDir: array[0..MAXWORD] of char;
  WorkDir: String;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  StrPCopy(zCmdLine,CmdLine);
  GetDir(0,WorkDir);
  StrPCopy(zCurDir,WorkDir);
  FillChar(StartupInfo,Sizeof(StartupInfo),#0);
  StartupInfo.cb := Sizeof(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := uCmdShow;
  if (not CreateProcess(nil,
    zCmdLine,
    nil,
    nil,
    false,
    CREATE_NEW_CONSOLE or
    NORMAL_PRIORITY_CLASS,
    nil,
    nil,
    StartupInfo,
    ProcessInfo)) then
  begin
    Result := $FFFFFFFF;
  end else
  begin
    WaitforSingleObject(ProcessInfo.hProcess,INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess,Result);
  end;
end;

function GetPidByTaskName(ExeFileName: String): Integer;
const    
  PROCESS_TERMINATE=$0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := Sizeof(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExeFileName))
      or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(ExeFileName))) then
    begin
      Result := Integer(FProcessEntry32.th32ProcessID);
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function KillTask(ExeFileName: String): Integer;
const
  PROCESS_TERMINATE=$0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin    
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := Sizeof(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExeFileName))
      or (UpperCase(FProcessEntry32.szExeFile) = UpperCase(ExeFileName))) then
    begin
      Result := Integer(TerminateProcess(OpenProcess(PROCESS_TERMINATE, BOOL(0), FProcessEntry32.th32ProcessID), 0));
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;


function ProcessTerminate(dwPID: Cardinal): Boolean;   
var
  hToken: THandle;
  SeDebugNameValue: Int64;
  tkp: TOKEN_PRIVILEGES;
  ReturnLength: Cardinal;
  hProcess: THandle;
begin  
  Result := False;
  if ( not OpenProcessToken( GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken ) ) then
  begin
    Exit;
  end;
  if ( not LookupPrivilegeValue( nil, 'SeDebugPrivilege', SeDebugNameValue ) ) then
  begin
    CloseHandle(hToken);
    Exit;
  end;
  tkp.PrivilegeCount:= 1;
  tkp.Privileges[0].Luid := SeDebugNameValue;
  tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
  AdjustTokenPrivileges(hToken,false,tkp,SizeOf(tkp),tkp,ReturnLength);
  if ( GetLastError() <> ERROR_SUCCESS ) then
  begin
    Exit;
  end;
  hProcess := OpenProcess(PROCESS_TERMINATE, FALSE, dwPID);
  if ( hProcess = 0 ) then
  begin
    Exit;
  end;
  if ( not TerminateProcess(hProcess, DWORD(-1)) ) then
  begin
    Exit;
  end;
  CloseHandle( hProcess );
  tkp.Privileges[0].Attributes := 0;
  AdjustTokenPrivileges(hToken, FALSE, tkp, SizeOf(tkp), tkp, ReturnLength);
  if ( GetLastError() <>  ERROR_SUCCESS ) then
  begin
    Exit;
  end;
  Result := True;
end;

function Is64BitOS: Boolean;
{$IFNDEF WIN64}
type
  TIsWow64Process = function(Handle:THandle; var IsWow64 : BOOL) : BOOL; stdcall;
var
  hKernel32 : Integer;
  IsWow64Process : TIsWow64Process;
  IsWow64 : BOOL;
{$ENDIF}
begin
  {$IFDEF WIN64}
     //We're a 64-bit application; obviously we're running on 64-bit Windows.
     Result := True;
  {$ELSE}
  // We can check if the operating system is 64-bit by checking whether
  // we are running under Wow64 (we are 32-bit code). We must check if this
  // function is implemented before we call it, because some older 32-bit 
  // versions of kernel32.dll (eg. Windows 2000) don't know about it.
  // See "IsWow64Process", http://msdn.microsoft.com/en-us/library/ms684139.aspx
  Result := False;
  hKernel32 := LoadLibrary('kernel32.dll');
  if hKernel32 = 0 then RaiseLastOSError;
  try
    @IsWow64Process := GetProcAddress(hkernel32, 'IsWow64Process');
    if Assigned(IsWow64Process) then begin
      if (IsWow64Process(GetCurrentProcess, IsWow64)) then begin
        Result := IsWow64;
      end
      else RaiseLastOSError;
    end;
  finally
    FreeLibrary(hKernel32);
  end;  
  {$ENDIf}
end;

function Path_ProgramFiles: String;
const
  SHGFP_TYPE_CURRENT = 0;
var
  Path: array [0..MAX_PATH] of char;
begin
  SHGetFolderPath(0,CSIDL_PROGRAM_FILES,0,SHGFP_TYPE_CURRENT,@Path[0]);
  Result := Path;
end;

function MsgBox(Text: String; Caption: String = ''; Buttons: Integer = 0): Integer;
begin
  if (Caption = '') then
  begin
    Caption := Application.Title;
  end;
  Result := Application.MessageBox(PAnsiChar(Text), PAnsiChar(Caption), Buttons);
end;

function MsgErr(Text: String): Integer;
var
  s: String;
begin
  s := 'An error occured: ';
  s := s + LnBr + LnBr + Text;
  Result := MsgBox(s, '', MB_ICONERROR+MB_ABORTRETRYIGNORE);
end;

function MsgFatal(Text: String): Integer;
var
  s: String;
begin
  s := 'We are sorry, fatal error has occurred: ' + LnBr + LnBr + Text;
  s := s + LnBr + LnBr + 'Application will be closed.';
  Result := MsgBox(s, '', MB_ICONERROR);
  Halt(1);
end;

function GetRegistryData(RootKey: HKEY; Key, Value: string): variant;
var
  Reg: TRegistry;
  RegDataType: TRegDataType;
  DataSize, Len: integer;
  s: string;
label cantread;
begin
  Reg := nil;
  try
    Reg := TRegistry.Create(KEY_QUERY_VALUE);
    Reg.RootKey := RootKey;
    if Reg.OpenKeyReadOnly(Key) then begin
      try
        RegDataType := Reg.GetDataType(Value);
        if (RegDataType = rdString) or
           (RegDataType = rdExpandString) then
          Result := Reg.ReadString(Value)
        else if RegDataType = rdInteger then
          Result := Reg.ReadInteger(Value)
        else if RegDataType = rdBinary then begin
          DataSize := Reg.GetDataSize(Value);
          if DataSize = -1 then goto cantread;
          SetLength(s, DataSize);
          Len := Reg.ReadBinaryData(Value, PChar(s)^, DataSize);
          if Len <> DataSize then goto cantread;
          Result := s;
        end else
          cantread:
          raise Exception.Create(SysErrorMessage(ERROR_CANTREAD));
      except
        s := ''; // Deallocates memory if allocated
        Reg.CloseKey;
        raise;
      end;
      Reg.CloseKey;
    end else
      raise Exception.Create(SysErrorMessage(GetLastError));
  except
    Reg.Free;
    raise;
  end;
  Reg.Free;
end;


procedure SetRegistryData(RootKey: HKEY; Key, Value: string;
  RegDataType: TRegDataType; Data: variant);
var
  Reg: TRegistry;
  s: string;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := RootKey;
    if Reg.OpenKey(Key, True) then begin
      try
        if RegDataType = rdUnknown then
          RegDataType := Reg.GetDataType(Value);
        if RegDataType = rdString then
          Reg.WriteString(Value, Data)
        else if RegDataType = rdExpandString then
          Reg.WriteExpandString(Value, Data)
        else if RegDataType = rdInteger then
          Reg.WriteInteger(Value, Data)
        else if RegDataType = rdBinary then begin
          s := Data;
          Reg.WriteBinaryData(Value, PChar(s)^, Length(s));
        end else
          raise Exception.Create(SysErrorMessage(ERROR_CANTWRITE));
      except
        Reg.CloseKey;
        raise;
      end;
      Reg.CloseKey;
    end else
      raise Exception.Create(SysErrorMessage(GetLastError));
  finally
    Reg.Free;
  end;
end;

function GetInstallDir(def: String): String;
var
  d, r: String;
  IsWin64: Boolean;
begin
  d := '';
  // We are running always in 32 bit mode
  // so we dont need to switch regkeys
  try
    IsWin64 := False;
    if IsWin64 then
    begin
      r := 'SOFTWARE\Wow6432Node\Electronic Arts\EA Games\Battlefield 2142';
    end else
    begin
      r := 'SOFTWARE\Electronic Arts\EA Games\Battlefield 2142';
    end;
    d := GetRegistryData(HKEY_LOCAL_MACHINE, r, 'InstallDir');
    if (length(d) > 0) then
    begin
      Result := d;
    end else
    begin
      Result := Format( '%s%s', [ Path_ProgramFiles, '\EA GAMES\Battlefield 2142\' ] );
    end;
  except
    on e: Exception do
    begin
      MsgErr ( Format( '%s: %s', [e.ClassName, e.Message] ) );
    end;
  end;
  //MsgBox('Value is "' + Result + '"', mbInformation, MB_OK);
end;

procedure TForm1.EnumResolutions;
var
  i: Integer;
  DevMode : TDeviceMode;
  s : string;
begin
  i:=0;
  Form1.cbbResolution.Items.Clear;
  while EnumDisplaySettings(nil,i,DevMode) do
  begin
    with Devmode do
      begin
        s := (Format('%dx%d',
        [dmPelsWidth,dmPelsHeight]));
        if Form1.cbbResolution.Items.IndexOf(s) = -1
          then Form1.cbbResolution.Items.Add(s);
      end;
    Inc(i);
  end;
end;

procedure TForm1.SetCurrentResolution;
var
  i: Integer;
  s: string;
begin
  //Form1.cbbResolution.Items.Clear;
  s := (Format('%dx%d',  [Screen.DesktopWidth, Screen.DesktopHeight]));
  for i:=0 to Form1.cbbResolution.Items.Count-1 do
  begin
    with Form1.cbbResolution do
    begin
      if Items[i] = s then
      begin
        ItemIndex := i;
      end;
    end;
  end;
end;

procedure TForm1.StartGame;
var
  UserName,
  Password,
  Resolution: String;

  Fullscreen,
  Widescreen: Boolean;

  CmdLine,
  DetectedPath,
  ExeFilename,
  Arguments: String;
begin
  Self.Hide;

  // Here we need to detect actual game path
  // using registry functions. Open/Read key 'InstallDir':
  // We need to expand this path without trailing '\',
  // so Extract will remove it automatically
  DetectedPath := GetInstallDir('');

  // Executable filename is always same
  ExeFilename := 'BF2142.exe';

  // Here we need to switch our arguments
  // by simply appending corresponding value
  Arguments := '+szx 1280 +szy 720 +wx 120 +wy 120 +restart 1 +widescreen 1 +fullscreen 0';

  // This is actual command-line. We can check this string at runtime
  CmdLine := Format( '"%s\%s" %s' , [DetectedPath, ExeFilename, Arguments] );

  // Check cmdLine again before start!
  // MsgBox( 'Starting: ' + LnBr + CmdLine );

  // Right before we start game, we need to change
  // current working directory
  ChDir( DetectedPath );

  // Game process will be executed with arguments supplied
  // Launcher will hide themself, and close after user close game
  WinExecAndWait(CmdLine, SW_NORMAL);

  // Here launcher will close itself
  // Game is closed too
  Self.Quit;
end;

procedure TForm1.OpenWebSite;
begin
  ShellExecute(Self.Handle,'open','http://stg2142.com','','',SW_SHOWNORMAL);
end;

procedure TForm1.Quit;
begin
  Application.Terminate;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // This procedure will be called
  // right on start our launcher application

  // First step:
  // Enumerate all available system display resolutions
  Self.EnumResolutions;

  // We need to determine current display resolution
  Self.SetCurrentResolution;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  // This is action for Button 1
  // Quit application
  Self.Quit;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  // This is action for Button 2
  // Starts game
  Self.StartGame;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  // This is action for Button 3
  // Open website in your default browser
  Self.OpenWebSite;
end;

end.
