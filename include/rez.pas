unit rez;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Contnrs;

const
  C_USER_TITLE_SIZE = 60;
  C_ERR_ITEM_NOT_FOUND = 'Item (%s) not found in REZ file!';
  C_ERR_UNKNOWN_ENTRY = 'Unknown entry type (%X)!';

type

  TDynByteArray = specialize TArray<Byte>;
  TRezMgrCallback = procedure(strMsg: string);

  TRezDir = class;
  TRezType = class;
  TRezItem = class;

  TRezMainHeader = packed record
    chCR1: Char;
    chLF1: Char;
    aFileType: array[0..C_USER_TITLE_SIZE-1] of Char;
    chCR2: Char;
    chLF2: Char;
    aUserTitle: array[0..C_USER_TITLE_SIZE-1] of Char;
    chCR3: Char;
    chLF3: Char;
    chEOF1: Char;
    dwFileFormatVersion: Cardinal;
    dwRootDirPos: Cardinal;
    dwRootDirSize: Cardinal;
    dwRootDirTime: Cardinal;
    dwNextWritePos: Cardinal;
    dwTime: Cardinal;
    dwLargestKeyAry: Cardinal;
    dwLargestDirNameSize: Cardinal;
    dwLargestRezNameSize: Cardinal;
    dwLargestCommentSize: Cardinal;
    nIsSorted: Byte;
  end;

  TFileDirEntryType = (fdetResourceEntry = 0, fdetDirectoryEntry);

  { TRezMgr }

  TRezMgr = class(TObject)
  private
    m_Stream: TFileStream;
    m_InfoCallbackFunc: TRezMgrCallback;
    m_ErrorCallbackFunc: TRezMgrCallback;
    m_Header: TRezMainHeader;
    m_pRootDir: TRezDir;
    m_chPathSeparator: Char;
    m_strWorkingDir: string;
    m_pGlobalMap: TFPObjectHashTable;
    m_strGlobalPath: string;
    function ReadString(Stream: TStream): string;
    procedure DirExtractAllIterator(pItem: TObject; const {%H-}strKey: string; var bContinue: Boolean);
    procedure TypeExtractAllIterator(pItem: TObject; const {%H-}strKey: string; var bContinue: Boolean);
    procedure ItemExtractAllIterator(pItem: TObject; const {%H-}strKey: string; var bContinue: Boolean);
    procedure ExtractDirRec(pDir: TRezDir);
  public
    property GlobalMap: TFPObjectHashTable read m_pGlobalMap;
    property PathSeparator: Char read m_chPathSeparator;
    property WorkingDir: string read m_strWorkingDir write m_strWorkingDir;
    property Stream: TFileStream read m_Stream;
    property InfoCallbackFunc: TRezMgrCallback read m_InfoCallbackFunc;
    property ErrorCallbackFunc: TRezMgrCallback read m_ErrorCallbackFunc;
    procedure Load(bCreateGlobalMap: Boolean);
    procedure ExtractFiles;
    procedure ExtractFile(strItemName: string; bMaintainRezPath: Boolean);
    constructor Create(FS: TFileStream; InfoCallback: Pointer;
      ErrorCallback: Pointer; strWorkingDir: string; chPathSeparator: Char);
    destructor Destroy; override;
  end;

  { TRezType }

  TRezType = class(TObject)
  public
    m_dwType: Cardinal;
    m_pParentDir: TRezDir;
    m_pContents: TFPObjectHashTable;
    m_strType: string;
    constructor Create(dwType: Cardinal; pParentDir: TRezDir);
    destructor Destroy; override;
  end;

  { TRezDir }

  TRezDir = class(TObject)
  public
    m_pMgr: TRezMgr;
    m_strDirName: string;
    m_dwDirPos: Cardinal;
    m_dwDirSize: Cardinal;
    m_dwItemsSize: Cardinal;
    m_dwLastTimeModified: Cardinal;
    m_pParentDir: TRezDir;
    m_pContents: TFPObjectHashTable;
    m_pTypes: TFPObjectHashTable;
    m_strPath: string;
    m_bResultFlag: Boolean;
    procedure DirReadAllIterator(pItem: TObject; const {%H-}strKey: string; var bContinue: Boolean);
    constructor Create(pMgr: TRezMgr; pParentDir: TRezDir; strDirName: string;
      dwPos: Cardinal; dwSize: Cardinal; dwTime: Cardinal);
    destructor Destroy; override;
    function AddType(dwType: Cardinal): TRezType;
    function ReadAllDirs(dwPos: Cardinal; dwSize: Cardinal): Boolean;
    function ReadDirBlock(dwPos: Cardinal; dwSize: Cardinal): Boolean;
  end;

  { TRezItem }

  TRezItem = class(TObject)
  public
    m_pMgr: TRezMgr;
    m_strName: string;
    m_strDesc: string;
    m_pType: TRezType;
    m_dwID: Cardinal;
    m_dwTime: Cardinal;
    m_dwSize: Cardinal;
    m_pParentDir: TRezDir;
    m_dwFilePos: Cardinal;
    constructor Create(pMgr: TRezMgr; pParentDir: TRezDir; strName: string;
      dwID: Cardinal; pType: TRezType; strDesc: string; dwSize: Cardinal;
  dwFilePos: Cardinal; dwTime: Cardinal);
  end;

implementation

{ TRezItem }

constructor TRezItem.Create(pMgr: TRezMgr; pParentDir: TRezDir; strName: string;
  dwID: Cardinal; pType: TRezType; strDesc: string; dwSize: Cardinal;
  dwFilePos: Cardinal; dwTime: Cardinal);
begin
  m_pMgr := pMgr;
  m_pParentDir := pParentDir;
  m_strName := strName;
  m_strDesc := strDesc;
  m_dwID := dwID;
  m_dwSize := dwSize;
  m_dwFilePos := dwFilePos;
  m_dwTime := dwTime;
  m_pType := pType;

  if m_pMgr.GlobalMap <> nil then
  begin
    if m_pParentDir.m_strPath <> '' then
      m_pMgr.GlobalMap.Add(m_pParentDir.m_strPath + m_pMgr.PathSeparator + m_strName + '.' + m_pType.m_strType, Self)
    else
      m_pMgr.GlobalMap.Add(m_strName + '.' + m_pType.m_strType, Self)
  end;
end;

{ TRezType }

constructor TRezType.Create(dwType: Cardinal; pParentDir: TRezDir);
begin
  m_dwType := dwType;
  m_pParentDir := pParentDir;
  m_strType := ReverseString(string(PChar(@m_dwType)));
  m_pContents := TFPObjectHashTable.Create(True);
end;

destructor TRezType.Destroy;
begin
  inherited Destroy;
  m_pContents.Free;
end;

{ TRezDir }

constructor TRezDir.Create(pMgr: TRezMgr; pParentDir: TRezDir;
  strDirName: string; dwPos: Cardinal; dwSize: Cardinal; dwTime: Cardinal);
begin
  m_pMgr := pMgr;
  m_pParentDir := pParentDir;
  m_strDirName := strDirName;
  m_dwDirPos := dwPos;
  m_dwDirSize := dwSize;
  m_dwLastTimeModified := dwTime;
  m_dwItemsSize := 0;
  m_pContents := TFPObjectHashTable.Create(True);
  m_pTypes := TFPObjectHashTable.Create(True);
  if m_pParentDir <> nil then
  begin
    if m_pParentDir.m_strPath <> '' then
      m_strPath := pParentDir.m_strPath + m_pMgr.m_chPathSeparator + m_strDirName
    else
      m_strPath := m_strDirName;
  end;
end;

destructor TRezDir.Destroy;
begin
  inherited Destroy;
  m_pContents.Free;
  m_pTypes.Free;
end;

function TRezDir.AddType(dwType: Cardinal): TRezType;
var pItem: TRezType;
    strType: string;
begin
  strType := dwType.ToString;
  pItem := TRezType(m_pTypes.Items[strType]);
  if pItem <> nil then
  begin
    Result := pItem;
    Exit;
  end
  else
  begin
    pItem := TRezType.Create(dwType, Self);
    m_pTypes.Items[strType] := pItem;
    Result := pItem;
  end;
end;

procedure TRezDir.DirReadAllIterator(pItem: TObject; const strKey: string;
  var bContinue: Boolean);
var pRezItem: TRezDir;
begin
  pRezItem := TRezDir(pItem);
  if pRezItem.m_dwDirPos <> 0 then
    m_bResultFlag := m_bResultFlag and pRezItem.ReadAllDirs(pRezItem.m_dwDirPos, pRezItem.m_dwDirSize);
  bContinue := True;
end;

function TRezDir.ReadAllDirs(dwPos: Cardinal; dwSize: Cardinal): Boolean;
begin
  Result := True;
  if dwSize <= 0 then Exit;

  if ReadDirBlock(dwPos, dwSize) then
  begin
    m_bResultFlag := True;
    m_pContents.Iterate(@DirReadAllIterator);
    Result := m_bResultFlag;
  end
  else
  begin
    Result := False;
  end;
end;

function TRezDir.ReadDirBlock(dwPos: Cardinal; dwSize: Cardinal): Boolean;
var MS: TMemoryStream;
    dwEntry, dwEntryPos, dwEntrySize, dwEntryTime, dwEntryID, dwEntryType, dwEntryNumKeys: Cardinal;
    strEntryName, strEntryDesc: string;
    pNewDir: TRezDir;
    pType: TRezType;
    pItem: TRezItem;
begin
  Result := True;
  m_dwItemsSize := 0;

  MS := TMemoryStream.Create;
  MS.SetSize(dwSize);

  m_pMgr.Stream.Seek(dwPos, soBeginning);
  MS.CopyFrom(m_pMgr.Stream, dwSize);
  MS.Seek(0, soBeginning);

  while MS.Position < dwSize do
  begin
    dwEntry := MS.ReadDWord;
    if dwEntry = Ord(fdetDirectoryEntry) then
    begin
      dwEntryPos := MS.ReadDWord;
      dwEntrySize := MS.ReadDWord;
      dwEntryTime := MS.ReadDWord;
      strEntryName := m_pMgr.ReadString(MS);

      pNewDir := TRezDir(m_pContents.Items[strEntryName]);
      if pNewDir = nil then
      begin
        pNewDir := TRezDir.Create(m_pMgr, Self, strEntryName, dwEntryPos, dwEntrySize, dwEntryTime);
        m_pContents.Items[strEntryName] := pNewDir;
      end
      else
      begin
        pNewDir.m_dwDirPos := dwEntryPos;
        pNewDir.m_dwDirSize := dwEntrySize;
        pNewDir.m_dwLastTimeModified := dwEntryTime;
      end;
    end
    else if dwEntry = Ord(fdetResourceEntry) then
    begin
      dwEntryPos := MS.ReadDWord;
      dwEntrySize := MS.ReadDWord;
      dwEntryTime := MS.ReadDWord;
      dwEntryID := MS.ReadDWord;
      dwEntryType := MS.ReadDWord;
      dwEntryNumKeys := MS.ReadDWord;
      strEntryName := m_pMgr.ReadString(MS);
      strEntryDesc := m_pMgr.ReadString(MS);

      pType := AddType(dwEntryType);

      if dwEntryNumKeys > 0 then
        MS.Seek(dwEntryNumKeys * SizeOf(Cardinal), soCurrent){%H-};

      pItem := TRezItem(pType.m_pContents.Items[strEntryName]);
      if pItem = nil then
      begin
        pItem := TRezItem.Create(m_pMgr, Self, strEntryName, dwEntryID, pType, strEntryDesc, dwEntrySize, dwEntryPos, dwEntryTime);
        pType.m_pContents.Items[pItem.m_strName] := pItem;
        Inc(m_dwItemsSize, pItem.m_dwSize);
      end;
    end
    else
    begin
      MS.Free;
      m_pMgr.ErrorCallbackFunc(Format(C_ERR_UNKNOWN_ENTRY, [dwEntry]));
      Exit(False);
    end;
  end;

  MS.Free;

end;

{ TRezMgr }

function TRezMgr.ReadString(Stream: TStream): string;
var B: Byte;
    qwOldPos: Int64;
    nLen: Integer;
begin
  Result := '';
  qwOldPos := Stream.Position;

  nLen := 0;
  B := Stream.ReadByte;
  while B <> 0 do
  begin
    B := Stream.ReadByte;
    Inc(nLen, 1);
  end;

  if nLen > 0 then
  begin
    SetLength(Result, nLen);
    Stream.Position := qwOldPos;
    Stream.ReadBuffer(Result[1], nLen);
    Stream.Seek(1, soCurrent);
  end;
end;

procedure TRezMgr.Load(bCreateGlobalMap: Boolean);
begin
  if bCreateGlobalMap then
    m_pGlobalMap := TFPObjectHashTable.Create(False);

  m_Stream.Read(m_Header, SizeOf(m_Header));

  if m_InfoCallbackFunc <> nil then
  begin
    m_InfoCallbackFunc(Format('FileFormatVersion = %d', [m_Header.dwFileFormatVersion]));
    m_InfoCallbackFunc(Format('FileType = %s', [string(m_Header.aFileType).TrimRight]));
    m_InfoCallbackFunc(Format('UserTitle = %s', [string(m_Header.aUserTitle).TrimRight]));
  end;

  m_pRootDir := TRezDir.Create(Self, nil, '', m_Header.dwRootDirPos, m_Header.dwRootDirSize, m_Header.dwRootDirTime);
  m_pRootDir.ReadAllDirs(m_Header.dwRootDirPos, m_Header.dwRootDirSize);
end;

procedure TRezMgr.ExtractFiles;
begin
  ExtractDirRec(m_pRootDir);
end;

procedure TRezMgr.ExtractFile(strItemName: string; bMaintainRezPath: Boolean);
var pRezItem: TRezItem;
    FS: TFileStream;
begin
  if m_pGlobalMap = nil then Exit;

  pRezItem := TRezItem(m_pGlobalMap.Items[strItemName]);
  if pRezItem = nil then
  begin
    if m_ErrorCallbackFunc <> nil then
      m_ErrorCallbackFunc(Format(C_ERR_ITEM_NOT_FOUND, [strItemName]));
    Exit;
  end;

  if (bMaintainRezPath) then
  begin
    ForceDirectories(m_strWorkingDir + m_chPathSeparator + Copy(strItemName, 1, strItemName.LastIndexOf(m_chPathSeparator)));
    FS := TFileStream.Create(Format('%s%s%s', [m_strWorkingDir, m_chPathSeparator, strItemName]), fmCreate + fmOpenWrite);
  end
  else
  begin
    CreateDir(m_strWorkingDir);
    FS := TFileStream.Create(Format('%s%s%s.%s', [m_strWorkingDir, m_chPathSeparator, pRezItem.m_strName, pRezItem.m_pType.m_strType]), fmCreate + fmOpenWrite);
  end;

  if m_InfoCallbackFunc <> nil then
    m_InfoCallbackFunc(FS.FileName);

  m_Stream.Seek(pRezItem.m_dwFilePos, soBeginning);
  if pRezItem.m_dwSize > 0 then
    FS.CopyFrom(m_Stream, pRezItem.m_dwSize);
  FS.Free;
end;

procedure TRezMgr.TypeExtractAllIterator(pItem: TObject; const strKey: string;
  var bContinue: Boolean);
var pRezType: TRezType;
begin
  pRezType := TRezType(pItem);
  pRezType.m_pContents.Iterate(@ItemExtractAllIterator);
  bContinue := True;
end;

procedure TRezMgr.ItemExtractAllIterator(pItem: TObject; const strKey: string;
  var bContinue: Boolean);
var pRezItem: TRezItem;
    FS: TFileStream;
begin
  pRezItem := TRezItem(pItem);

  FS := TFileStream.Create(Format('%s%s.%s', [m_strGlobalPath, pRezItem.m_strName, pRezItem.m_pType.m_strType]), fmCreate + fmOpenWrite);

  if m_InfoCallbackFunc <> nil then
    m_InfoCallbackFunc(FS.FileName);

  m_Stream.Seek(pRezItem.m_dwFilePos, soBeginning);
  if pRezItem.m_dwSize > 0 then
    FS.CopyFrom(m_Stream, pRezItem.m_dwSize);
  FS.Free;

  bContinue := True;
end;

procedure TRezMgr.DirExtractAllIterator(pItem: TObject; const strKey: string;
  var bContinue: Boolean);
var pRezDir: TRezDir;
begin
  pRezDir := TRezDir(pItem);
  ExtractDirRec(pRezDir);
  bContinue := True;
end;

procedure TRezMgr.ExtractDirRec(pDir: TRezDir);
var strThisPath: string;
begin
  if pDir.m_strPath <> '' then
    strThisPath := m_strWorkingDir + m_chPathSeparator + pDir.m_strPath + m_chPathSeparator
  else
    strThisPath := m_strWorkingDir + m_chPathSeparator;

  CreateDir(strThisPath);
  m_strGlobalPath := strThisPath;
  pDir.m_pTypes.Iterate(@TypeExtractAllIterator);
  pDir.m_pContents.Iterate(@DirExtractAllIterator);
end;

constructor TRezMgr.Create(FS: TFileStream; InfoCallback: Pointer;
  ErrorCallback: Pointer; strWorkingDir: string; chPathSeparator: Char);
begin
  m_Stream := FS;
  m_strWorkingDir := strWorkingDir;
  m_InfoCallbackFunc := TRezMgrCallback(InfoCallback);
  m_ErrorCallbackFunc := TRezMgrCallback(ErrorCallback);
  m_pRootDir := nil;
  m_chPathSeparator := chPathSeparator;
end;

destructor TRezMgr.Destroy;
begin
  inherited Destroy;
  m_pRootDir.Free;
  if m_pGlobalMap <> nil then
    m_pGlobalMap.Free;
end;

end.

