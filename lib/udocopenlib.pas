unit uDocOpenLib;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Dialogs;

const
  NO_ERRORS = 0;
  ERR_INVAILD_DOC_FILE_PATHNAME = 20;

  // Unit:        uDocOpen
  // Project:     MouseCatcher
  // Date:        2026-02-28 03:46:33
  // Version:     1.0
  // Description: Helper routines to open documentation files using OS defaults.
  // Note:        Linux uses "xdg-open". This is the standard way to open a file
  //              in the user's default application (PDF viewer, browser, etc.).
  // Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
  // Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
  // Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

// procedure OpenTechDocumentationPdf;
function OpenMyDoc(sName: string): integer;

implementation

// Name:        GetAppBaseDir
// Description: Returns the directory where the application expects to find docs.
// Result:      Base directory (string).
// Note:        If you keep docs next to the executable: <appdir>/docs
// Example:     sBase := GetAppBaseDir;
function GetAppBaseDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

// Name:        RunDetached
// Description: Runs a command detached (non-blocking), no terminal window.
// sExe:        Executable name/path.
// sArg1:       First argument.
// Result:      True if process was started.
// Note:        Uses poNoConsole + poNewProcessGroup to avoid blocking UI.
// Example:     bOk := RunDetached('xdg-open', sFile);
function RunDetached(const sExe, sArg1: string): boolean;
var
  Proc: TProcess;
begin
  Result := False;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := sExe;
    Proc.Parameters.Clear;
    Proc.Parameters.Add(sArg1);

    Proc.Options := [poNoConsole, poNewProcessGroup];
    Proc.ShowWindow := swoHide;

    Proc.Execute;
    Result := True;
  finally
    Proc.Free;
  end;
end;

// Name:        OpenMyDoc
// Description: Opens MouseCatcher_Technical_Documentation_v1_9.pdf in default viewer.
// sName:       Name of the document, ith or without path
// Note:        First looks if i has an absolute path/file name, thereafter looks in
//              "<appdir>/docs" second, then in project-run layout as fallback.
// Example:     OpenMyDoc('MyPdfFile');
function OpenMyDoc(sName: string): integer;
var
  sBaseDir: string;
  sAbsPath: string;
  sDocPath: string;
  sAltPath: string;
begin
  Result := NO_ERRORS;
  sBaseDir := GetAppBaseDir;

  // Preferred: ship docs with the executable:  <appdir>/docs/<file>
  sDocPath := IncludeTrailingPathDelimiter(sBaseDir) + 'docs' + DirectorySeparator + sName;

  // Fallback: if you run from Lazarus build dir and docs are one level up, adjust if needed
  sAltPath := IncludeTrailingPathDelimiter(sBaseDir) + sName;
    if FileExists(sName) then
      begin
      RunDetached('xdg-open', sName)
      end
    else if FileExists(sDocPath) then
      begin
      RunDetached('xdg-open', sDocPath)
      end
    else if FileExists(sAltPath) then
      begin
      RunDetached('xdg-open', sAltPath)
      end
else
begin
  ShowMessage('Invalid document name: ' + sName);
  Result := ERR_INVAILD_DOC_FILE_PATHNAME;
  end;
end;

end.
