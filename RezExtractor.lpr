program RezExtractor;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, MMSystem;

const
  REZMGR_DLL_CREATE = 7;
  REZMGR_DLL_LOAD = 6;
  REZMGR_DLL_EXTRACT_FILES = 5;
  REZMGR_DLL_EXTRACT_FILE = 4;
  //REZMGR_DLL_EXTRACT_FILE_TO_STREAM = 3;
  REZMGR_DLL_DESTROY = 2;
  REZMGR_DLL_GET_VERSION = 1;

procedure CreateRezMgr(szRezFilename: PChar; InfoCallback: Pointer; ErrorCallback: Pointer;
  szWorkingDir: PChar; chPathSeparator: Char); external 'rezmgr.dll' index REZMGR_DLL_CREATE;
procedure LoadRezMgr(bCreateGlobalMap: Boolean); external 'rezmgr.dll' index REZMGR_DLL_LOAD;
procedure ExtractFiles; external 'rezmgr.dll' index REZMGR_DLL_EXTRACT_FILES;
procedure ExtractFile(szItemName: PChar;
  bMaintainRezPath: Boolean); external 'rezmgr.dll' index REZMGR_DLL_EXTRACT_FILE;
//function ExtractFileToBuffer(szItemName: PChar; var dwSize: Cardinal;
//  var pBuffer: PByte); external 'rezmgr.dll' index REZMGR_DLL_EXTRACT_FILE_TO_STREAM;
procedure DestroyRezMgr; external 'rezmgr.dll' index REZMGR_DLL_DESTROY;
procedure GetVersion(szVersion: PChar);  external 'rezmgr.dll' index REZMGR_DLL_GET_VERSION;

type

  { TApplication }

  TApplication = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure REInfoCallback(strMsg: string);
begin
  WriteLn(strMsg);
end;

procedure REErrorCallback(strMsg: string);
begin
  WriteLn('ERROR! ', strMsg);
end;

{ TApplication }

procedure TApplication.DoRun;
var strFilename, strTargetRezItem: string;
    bMaintainRezPath: Boolean;
    bMeausurePerformance: Boolean;
    szVersion: array[0..64] of Char;
    InfoCallback: Pointer = nil;
    dwStartTime: Cardinal = 0;
begin
  strFilename := GetOptionValue('f', '');
  strTargetRezItem := GetOptionValue('t', '');
  bMaintainRezPath := HasOption('m', '');
  bMeausurePerformance := HasOption('p', '');

  if strFilename = '' then
  begin
    GetVersion(szVersion{%H-});
    WriteLn('Rez Extractor + ', szVersion);
    WriteLn('Usage: RezExtractor.exe -f InputFile.REZ');
    WriteLn('Options:');
    WriteLn('   -f <FILE.REZ>: Input REZ file');
    WriteLn('   -t <ATTRIBUTES\WEAPONS.TXT>: Specific file to extract');
    WriteLn('   -m: Maintain internal REZ path');
    WriteLn('   -p: Meausure performance');
  end
  else
  begin
    if not bMeausurePerformance then
      InfoCallback := @REInfoCallback;

    CreateRezMgr(PChar(strFilename), InfoCallback, @REErrorCallback, PChar(strFilename + '_RootFolder'), '\');

    if bMeausurePerformance then
    begin
      timeBeginPeriod(1);
      dwStartTime := timeGetTime();
    end;

    if strTargetRezItem = '' then
    begin
      LoadRezMgr(False);
      ExtractFiles;
    end
    else
    begin
      LoadRezMgr(True);
      ExtractFile(PChar(strTargetRezItem), bMaintainRezPath);
    end;

    if bMeausurePerformance then
    begin
      timeEndPeriod(1);
      WriteLn('Execution took ', timeGetTime() - dwStartTime, ' ms');
    end;

    DestroyRezMgr;
  end;

  Terminate;
end;

constructor TApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TApplication.Destroy;
begin
  inherited Destroy;
end;

var
  Application: TApplication;
begin
  Application := TApplication.Create(nil);
  Application.Title := 'RezExtractor';
  Application.Run;
  Application.Free;
end.

