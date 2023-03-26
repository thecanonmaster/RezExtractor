library RezMgrPas;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, rez;

const
  C_VERSION = 'RezMgrPas v0.07';

var
  g_pRezMgr: TRezMgr;
  g_ErrorCallback: TRezMgrCallback;

procedure CreateRezMgr(szRezFilename: PChar; InfoCallback: Pointer; ErrorCallback: Pointer;
  szWorkingDir: PChar; chPathSeparator: Char);
var FS: TFileStream;
begin
  g_ErrorCallback := TRezMgrCallback(ErrorCallback);
  try
    FS := TFileStream.Create(szRezFilename, fmOpenRead);
  except on E: Exception do
    g_ErrorCallback(E.Message);
  end;
  g_pRezMgr := TRezMgr.Create(FS, InfoCallback, ErrorCallback, szWorkingDir, chPathSeparator);
end;

procedure LoadRezMgr(bCreateGlobalMap: Boolean);
begin
  if g_pRezMgr <> nil then
    g_pRezMgr.Load(bCreateGlobalMap);
end;

procedure ExtractFiles;
begin
  if g_pRezMgr <> nil then
    g_pRezMgr.ExtractFiles;
end;

procedure ExtractFile(szItemName: PChar; bMaintainRezPath: Boolean);
begin
  if g_pRezMgr <> nil then
    g_pRezMgr.ExtractFile(szItemName, bMaintainRezPath);
end;

function ExtractFileToBuffer(szItemName: PChar; var dwSize: Cardinal;
  var pBuffer: PByte): Boolean;
var pRezItem: TRezItem;
begin
  Result := False;
  if g_pRezMgr = nil then
    Exit;

  pRezItem := TRezItem(g_pRezMgr.GlobalMap.Items[szItemName]);
  if pRezItem <> nil then
  begin
    dwSize := pRezItem.m_dwSize;
    g_pRezMgr.Stream.Seek(pRezItem.m_dwFilePos, soBeginning);
    pBuffer := GetMem(dwSize);
    g_pRezMgr.Stream.ReadBuffer(pBuffer^, dwSize);
    Result := True;
  end
  else
  begin
    g_pRezMgr.ErrorCallbackFunc(Format(C_ERR_ITEM_NOT_FOUND, [szItemName]));
  end;
end;

procedure DestroyRezMgr;
begin
  if g_pRezMgr <> nil then
  begin
    g_pRezMgr.Stream.Free;
    FreeAndNil(g_pRezMgr);
  end;
end;

procedure GetVersion(szVersion: PChar);
begin
  strcopy(szVersion, C_VERSION);
end;

exports
  CreateRezMgr, LoadRezMgr, ExtractFiles, ExtractFile,
  ExtractFileToBuffer, DestroyRezMgr, GetVersion;

begin
end.

