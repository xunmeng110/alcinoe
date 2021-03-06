unit ALFiles;

interface

uses ALCommon;

{$IF CompilerVersion >= 25} {Delphi XE4}
  {$LEGACYIFEND ON} // http://docwiki.embarcadero.com/RADStudio/XE4/en/Legacy_IFEND_(Delphi)
{$IFEND}

{$IFNDEF NEXTGEN}
Function  AlEmptyDirectory(Directory: ansiString;
                           SubDirectory: Boolean;
                           const IgnoreFiles: Array of AnsiString;
                           Const RemoveEmptySubDirectory: Boolean = True;
                           Const FileNameMask: ansiString = '*';
                           Const MinFileAge: TdateTime = ALNullDate): Boolean; overload;
Function  AlEmptyDirectory(const Directory: ansiString;
                           SubDirectory: Boolean;
                           Const RemoveEmptySubDirectory: Boolean = True;
                           Const FileNameMask: ansiString = '*';
                           Const MinFileAge: TdateTime = ALNullDate): Boolean; overload;
Function  AlCopyDirectory(SrcDirectory,
                          DestDirectory: ansiString;
                          SubDirectory: Boolean;
                          Const FileNameMask: ansiString = '*';
                          Const FailIfExists: Boolean = True): Boolean;
function  ALGetModuleName: ansistring;
function  ALGetModuleFileNameWithoutExtension: ansistring;
function  ALGetModulePath: ansiString;
Function  AlGetFileSize(const AFileName: ansistring): int64;
Function  AlGetFileVersion(const AFileName: ansistring): ansiString;
function  ALGetFileCreationDateTime(const aFileName: Ansistring): TDateTime;
function  ALGetFileLastWriteDateTime(const aFileName: Ansistring): TDateTime;
function  ALGetFileLastAccessDateTime(const aFileName: Ansistring): TDateTime;
Procedure ALSetFileCreationDateTime(Const aFileName: Ansistring; Const aCreationDateTime: TDateTime);
function  ALIsDirectoryEmpty(const directory: ansiString): boolean;
function  ALFileExists(const Path: ansiString): boolean;
function  ALDirectoryExists(const Directory: Ansistring): Boolean;
function  ALCreateDir(const Dir: Ansistring): Boolean;
function  ALRemoveDir(const Dir: Ansistring): Boolean;
function  ALDeleteFile(const FileName: Ansistring): Boolean;
function  ALRenameFile(const OldName, NewName: ansistring): Boolean;
{$ENDIF}

Function  AlEmptyDirectoryU(Directory: String;
                            SubDirectory: Boolean;
                            const IgnoreFiles: Array of String;
                            Const RemoveEmptySubDirectory: Boolean = True;
                            Const FileNameMask: String = '*';
                            Const MinFileAge: TdateTime = ALNullDate): Boolean; overload;
Function  AlEmptyDirectoryU(const Directory: String;
                            SubDirectory: Boolean;
                            Const RemoveEmptySubDirectory: Boolean = True;
                            Const FileNameMask: String = '*';
                            Const MinFileAge: TdateTime = ALNullDate): Boolean; overload;
function  ALGetFileSizeU(const FileName : string): Int64;

implementation

uses System.Classes,
     System.sysutils,
     System.Masks,
     {$IFNDEF NEXTGEN}
     Winapi.Windows,
     Winapi.ShLwApi,
     {$ELSE}
     Posix.Unistd,
     {$ENDIF}
     ALString,
     ALStringList;

{$IFNDEF NEXTGEN}

{***********************************************}
Function  AlEmptyDirectory(Directory: ansiString;
                           SubDirectory: Boolean;
                           const IgnoreFiles: Array of AnsiString;
                           const RemoveEmptySubDirectory: Boolean = True;
                           const FileNameMask: ansiString = '*';
                           const MinFileAge: TdateTime = ALNullDate): Boolean;
var sr: TSearchRec;
    aIgnoreFilesLst: TalStringList;
    i: integer;
begin
  if (Directory = '') or
     (Directory = '.') or
     (Directory = '..') then raise EALException.CreateFmt('Wrong directory ("%s")', [Directory]);

  Result := True;
  Directory := ALIncludeTrailingPathDelimiter(Directory);
  aIgnoreFilesLst := TalStringList.Create;
  try
    for I := 0 to length(IgnoreFiles) - 1 do aIgnoreFilesLst.Add(ALExcludeTrailingPathDelimiter(IgnoreFiles[i]));
    aIgnoreFilesLst.Duplicates := DupIgnore;
    aIgnoreFilesLst.Sorted := True;
    if System.sysutils.FindFirst(string(Directory) + '*', faAnyFile	, sr) = 0 then begin
      Try
        repeat
          If (sr.Name <> '.') and
             (sr.Name <> '..') and
             (aIgnoreFilesLst.IndexOf(Directory + ansistring(sr.Name)) < 0) Then Begin
            If ((sr.Attr and faDirectory) <> 0) then begin
              If SubDirectory then begin
                Result := AlEmptyDirectory(Directory + ansistring(sr.Name),
                                           True,
                                           IgnoreFiles,
                                           RemoveEmptySubDirectory,
                                           fileNameMask,
                                           MinFileAge);
                If result and RemoveEmptySubDirectory then RemoveDir(string(Directory) + sr.Name);
              end;
            end
            else If ((FileNameMask = '*') or
                     ALMatchesMask(AnsiString(sr.Name), FileNameMask))
                    and
                    ((MinFileAge=ALNullDate) or
                     (sr.TimeStamp < MinFileAge))
            then Result := System.sysutils.Deletefile(string(Directory) + sr.Name);
          end;
        until (not result) or (FindNext(sr) <> 0);
      finally
        System.sysutils.FindClose(sr);
      end;
    end;
  finally
    aIgnoreFilesLst.Free;
  end;
end;

{****************************************************}
Function AlEmptyDirectory(const Directory: ansiString;
                          SubDirectory: Boolean;
                          Const RemoveEmptySubDirectory: Boolean = True;
                          Const FileNameMask: ansiString = '*';
                          Const MinFileAge: TdateTime = ALNullDate): Boolean;
begin
  result := AlEmptyDirectory(Directory,
                             SubDirectory,
                             [],
                             RemoveEmptySubDirectory,
                             FileNameMask,
                             MinFileAge);
end;

{************************************}
Function AlCopyDirectory(SrcDirectory,
                         DestDirectory: ansiString;
                         SubDirectory: Boolean;
                         Const FileNameMask: ansiString = '*';
                         Const FailIfExists: Boolean = True): Boolean;
var sr: TSearchRec;
begin
  Result := True;
  SrcDirectory := ALIncludeTrailingPathDelimiter(SrcDirectory);
  DestDirectory := ALIncludeTrailingPathDelimiter(DestDirectory);
  If not DirectoryExists(string(DestDirectory)) and (not Createdir(String(DestDirectory))) then begin
    result := False;
    exit;
  end;

  if System.sysutils.FindFirst(String(SrcDirectory) + '*', faAnyFile, sr) = 0 then begin
    Try
      repeat
        If (sr.Name <> '.') and (sr.Name <> '..') Then Begin
          If ((sr.Attr and faDirectory) <> 0) then begin
            If SubDirectory then Result := AlCopyDirectory(SrcDirectory + ansiString(sr.Name),
                                                           DestDirectory + ansiString(sr.Name),
                                                           SubDirectory,
                                                           FileNameMask,
                                                           FailIfExists);
          end
          else If (FileNameMask = '*') or
                  (ALMatchesMask(AnsiString(sr.Name), FileNameMask)) then begin
            result := CopyfileA(PAnsiChar(SrcDirectory + AnsiString(sr.Name)),
                                PAnsiChar(DestDirectory + AnsiString(sr.Name)),
                                FailIfExists);
          end;
        end;
      until (not result) or (FindNext(sr) <> 0);
    finally
      System.sysutils.FindClose(sr);
    end;
  end
end;

{**********************************************************}
Function  AlGetFileSize(const AFileName: ansistring): int64;
var
  Handle: THandle;
  FindData: TWin32FindDataA;
begin
  Handle := FindFirstFileA(PAnsiChar(AFileName), FindData);
  if Handle <> INVALID_HANDLE_VALUE then
  begin
    {$IF CompilerVersion >= 23}{Delphi XE2}Winapi.{$IFEND}Windows.FindClose(Handle);
    if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
    begin
      Int64Rec(Result).Lo := FindData.nFileSizeLow;
      Int64Rec(Result).Hi := FindData.nFileSizeHigh;
      Exit;
    end;
  end;
  Result := -1;
end;

{*****************************************************************}
Function AlGetFileVersion(const AFileName: ansiString): ansiString;
var
  FileName: ansiString;
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  FI: PVSFixedFileInfo;
  VerSize: DWORD;
begin
  Result := '';
  FileName := AFileName;
  UniqueString(FileName);
  InfoSize := GetFileVersionInfoSizeA(PAnsiChar(FileName), Wnd);
  if InfoSize <> 0 then begin
    GetMem(VerBuf, InfoSize);
    try
      if GetFileVersionInfoA(PAnsiChar(FileName), Wnd, InfoSize, VerBuf) then
        if VerQueryValue(VerBuf, '\', Pointer(FI), VerSize) then
          Result := ALIntToStr(HiWord(FI.dwFileVersionMS)) +'.'+ ALIntToStr(LoWord(FI.dwFileVersionMS)) +'.'+ ALIntToStr(HiWord(FI.dwFileVersionLS)) +'.'+ ALIntToStr(LoWord(FI.dwFileVersionLS));
    finally
      FreeMem(VerBuf);
    end;
  end;
end;

{*******************************************************}
function ALGetModuleFileNameWithoutExtension: ansiString;
Var Ln: Integer;
begin
  result := ALExtractFileName(ALGetModuleName);
  ln := Length(ALExtractFileExt(Result));
  if Ln > 0 then delete(Result,length(Result)-ln+1,ln);  
end;

{***********************************}
function ALGetModuleName: ansiString;
var ModName: array[0..MAX_PATH] of AnsiChar;
begin
  SetString(Result, ModName, {$IF CompilerVersion >= 23}{Delphi XE2}Winapi.{$IFEND}Windows.GetModuleFileNameA(HInstance, ModName, SizeOf(ModName)));
  If ALpos('\\?\',result) = 1 then delete(Result,1,4);
end;

{***********************************}
function ALGetModulePath: ansiString;
begin
  Result:=ALExtractFilePath(ALGetModuleName);
  If (length(result) > 0) and (result[length(result)] <> '\') then result := result + '\';
end;

{**************************************************************************}
function  ALGetFileCreationDateTime(const aFileName: Ansistring): TDateTime;
var aHandle: THandle;
    aFindData: TWin32FindDataA;
    aLocalFileTime: TFileTime;
    aFileDate: Integer;
begin
  aHandle := FindFirstFileA(PAnsiChar(aFileName), aFindData);
  if (aHandle = INVALID_HANDLE_VALUE) or
     (not {$IF CompilerVersion >= 23}{Delphi XE2}Winapi.{$IFEND}Windows.FindClose(aHandle)) or
     (not FileTimeToLocalFileTime(aFindData.ftCreationTime, aLocalFileTime)) or
     (not FileTimeToDosDateTime(aLocalFileTime, LongRec(aFileDate).Hi, LongRec(aFileDate).Lo)) then raiselastOsError;
  Result := filedatetodatetime(aFileDate);
end;

{***************************************************************************}
function  ALGetFileLastWriteDateTime(const aFileName: Ansistring): TDateTime;
var aHandle: THandle;
    aFindData: TWin32FindDataA;
    aLocalFileTime: TFileTime;
    aFileDate: Integer;
begin
  aHandle := FindFirstFileA(PAnsiChar(aFileName), aFindData);
  if (aHandle = INVALID_HANDLE_VALUE) or
     (not {$IF CompilerVersion >= 23}{Delphi XE2}Winapi.{$IFEND}Windows.FindClose(aHandle)) or
     (not FileTimeToLocalFileTime(aFindData.ftLastWriteTime, aLocalFileTime)) or
     (not FileTimeToDosDateTime(aLocalFileTime, LongRec(aFileDate).Hi, LongRec(aFileDate).Lo)) then raiselastOsError;
  Result := filedatetodatetime(aFileDate);
end;

{****************************************************************************}
function  ALGetFileLastAccessDateTime(const aFileName: Ansistring): TDateTime;
var aHandle: THandle;
    aFindData: TWin32FindDataA;
    aLocalFileTime: TFileTime;
    aFileDate: Integer;
begin
  aHandle := FindFirstFileA(PAnsiChar(aFileName), aFindData);
  if (aHandle = INVALID_HANDLE_VALUE) or
     (not {$IF CompilerVersion >= 23}{Delphi XE2}Winapi.{$IFEND}Windows.FindClose(aHandle)) or
     (not FileTimeToLocalFileTime(aFindData.ftLastAccessTime, aLocalFileTime)) or
     (not FileTimeToDosDateTime(aLocalFileTime, LongRec(aFileDate).Hi, LongRec(aFileDate).Lo)) then raiselastOsError;
  Result := filedatetodatetime(aFileDate);
end;

{***************************************************************************************************}
Procedure ALSetFileCreationDateTime(Const aFileName: Ansistring; Const aCreationDateTime: TDateTime);
Var ahandle: Thandle;
    aSystemTime: TsystemTime;
    afiletime: TfileTime;
Begin
  aHandle := {$IF CompilerVersion >= 23}{Delphi XE2}System.{$IFEND}sysUtils.fileOpen(String(aFileName), fmOpenWrite or fmShareDenyNone);
  if aHandle = INVALID_HANDLE_VALUE then raiseLastOsError;
  Try
    dateTimeToSystemTime(aCreationDateTime, aSystemTime);
    if (not SystemTimeToFileTime(aSystemTime, aFileTime)) or
       (not LocalFileTimeToFileTime(aFileTime, aFileTime)) or
       (not setFileTime(aHandle, @aFileTime, nil, nil)) then raiselastOsError;
  finally
    fileClose(aHandle);
  end;
End;

{****************************************************************}
function ALIsDirectoryEmpty(const directory: ansiString): boolean;
begin
  Result := PathIsDirectoryEmptyA(PansiChar(directory));
end;

{******************************************************}
function  ALFileExists(const Path: ansiString): boolean;
begin
  result := PathFileExistsA(PansiChar(Path)) and (not PathIsDirectoryA(PansiChar(Path)));
end;

{****************************************************************}
function  ALDirectoryExists(const Directory: Ansistring): Boolean;
begin
  result := PathFileExistsA(PansiChar(Directory)) and (PathIsDirectoryA(PansiChar(Directory)));
end;

{****************************************************}
function  ALCreateDir(const Dir: Ansistring): Boolean;
begin
  Result := CreateDirectoryA(PAnsiChar(Dir), nil);
end;

{****************************************************}
function  ALRemoveDir(const Dir: Ansistring): Boolean;
begin
  Result := RemoveDirectoryA(PansiChar(Dir));
end;

{**********************************************************}
function  ALDeleteFile(const FileName: Ansistring): Boolean;
begin
  Result := DeleteFileA(PAnsiChar(FileName));
end;

{******************************************************************}
function  ALRenameFile(const OldName, NewName: ansistring): Boolean;
begin
  Result := MoveFileA(PansiChar(OldName), PansiChar(NewName));
end;

{$ENDIF}

{********************************************}
Function  AlEmptyDirectoryU(Directory: String;
                            SubDirectory: Boolean;
                            const IgnoreFiles: Array of String;
                            const RemoveEmptySubDirectory: Boolean = True;
                            const FileNameMask: String = '*';
                            const MinFileAge: TdateTime = ALNullDate): Boolean;
var sr: TSearchRec;
    aIgnoreFilesLst: TalStringListU;
    i: integer;
begin
  if (Directory = '') or
     (Directory = '.') or
     (Directory = '..') then raise EALExceptionU.CreateFmt('Wrong directory ("%s")', [Directory]);

  Result := True;
  Directory := ALIncludeTrailingPathDelimiterU(Directory);
  aIgnoreFilesLst := TalStringListU.Create;
  try
    for I := 0 to length(IgnoreFiles) - 1 do aIgnoreFilesLst.Add(ALExcludeTrailingPathDelimiterU(IgnoreFiles[i]));
    aIgnoreFilesLst.Duplicates := DupIgnore;
    aIgnoreFilesLst.Sorted := True;
    if System.sysutils.FindFirst(string(Directory) + '*', faAnyFile	, sr) = 0 then begin
      Try
        repeat
          If (sr.Name <> '.') and
             (sr.Name <> '..') and
             (aIgnoreFilesLst.IndexOf(Directory + sr.Name) < 0) Then Begin
            If ((sr.Attr and faDirectory) <> 0) then begin
              If SubDirectory then begin
                Result := AlEmptyDirectoryU(Directory + sr.Name,
                                            True,
                                            IgnoreFiles,
                                            RemoveEmptySubDirectory,
                                            fileNameMask,
                                            MinFileAge);
                If result and RemoveEmptySubDirectory then RemoveDir(string(Directory) + sr.Name);
              end;
            end
            else If ((FileNameMask = '*') or
                     MatchesMask(sr.Name, FileNameMask))
                    and
                    ((MinFileAge=ALNullDate) or
                     (sr.TimeStamp < MinFileAge))
            then Result := System.sysutils.Deletefile(string(Directory) + sr.Name);
          end;
        until (not result) or (FindNext(sr) <> 0);
      finally
        System.sysutils.FindClose(sr);
      end;
    end;
  finally
    aIgnoreFilesLst.Free;
  end;
end;

{*************************************************}
Function AlEmptyDirectoryU(const Directory: String;
                           SubDirectory: Boolean;
                           Const RemoveEmptySubDirectory: Boolean = True;
                           Const FileNameMask: String = '*';
                           Const MinFileAge: TdateTime = 0): Boolean;
begin
  result := AlEmptyDirectoryU(Directory,
                              SubDirectory,
                              [],
                              RemoveEmptySubDirectory,
                              FileNameMask,
                              MinFileAge);
end;

{*******************************************************}
function ALGetFileSizeU(const FileName : string) : Int64;
var aFileStream: TFileStream;
begin
  aFileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    result := aFileStream.Size;
  finally
    alFreeAndNil(aFileStream);
  end;
end;

end.
