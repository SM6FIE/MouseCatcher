unit uHelpRender;

// Unit:        uHelpRender
// Project:     MouseCatcher
// Date:        2026-03-01 00:15:00
// Version:     1.9
// Description: Tagged help renderer for TRichMemo (Lazarus/LCL).
// Note:        Help style spec (tagged lines):
//              '#1:' Big title
//              '#2:' Small title
//              '#3:' Normal text
//              '#4:' Normal text, italic
//              '#5:' Normal text, mono spaced
//              '#6:' Normal text, small
//              '#7:' Bullet line (renders as '• ' + text)
//              If a tag is given, it persists for following lines until a new tag is given.
//              If a line starts with '- ' or '* ' it is also rendered as a bullet.
//              IMPORTANT IMPLEMENTATION NOTE:
//              TRichMemo SetTextAttributes() uses UTF-8 BYTE OFFSETS on many widgetsets,
//              while GetTextLen/SelStart can behave like character positions. This unit
//              therefore maintains its own UTF-8 byte cursor (iPosUtf8) using UTF8Length(),
//              and applies formatting using those offsets.
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, RichMemo, LazUTF8;

type
  THelpTag = (htNormal, htTitleBig, htTitleSmall, htItalic, htMono, htSmall);

  THelpRenderSpec = record
    sFontNameNormal: string;
    sFontNameMono: string;
    iSizeNormal: integer;
    iSizeTitleBig: integer;
    iSizeTitleSmall: integer;
    iSizeSmall: integer;
  end;


function DefaultHelpRenderSpec: THelpRenderSpec;
procedure RenderTaggedHelpFile(const sFileName: ansistring; const rmTarget: TRichMemo; const Spec: THelpRenderSpec);

implementation

// Name:        DefaultHelpRenderSpec
// Description: Returns default rendering specification.
// Result:      Default spec.
// Note:        Choose fonts that exist on Linux Mint by default.
//              You can override fields after calling this.
// Example:     Spec := DefaultHelpRenderSpec;
function DefaultHelpRenderSpec: THelpRenderSpec;
begin
  Result.sFontNameNormal := 'DejaVu Sans';
  Result.sFontNameMono := 'DejaVu Sans Mono';
  Result.iSizeNormal := 12;
  Result.iSizeTitleBig := 22;
  Result.iSizeTitleSmall := 14;
  Result.iSizeSmall := 10;
end;

// Name:        TrimLineEndings
// Description: Removes trailing CR/LF from a line.
// sLine:       Input line.
// Result:      Line without trailing CR/LF.
// Note:        File lines may contain CRLF; we normalize.
// Example:     s := TrimLineEndings(s);
function TrimLineEndings(const sLine: ansistring): ansistring;
var
  iLen: integer;
begin
  Result := sLine;
  iLen := Length(Result);
  while (iLen > 0) and ((Result[iLen] = #10) or (Result[iLen] = #13)) do
  begin
    Delete(Result, iLen, 1);
    Dec(iLen);
  end;
end;

// Name:        DetectTagAndStrip
// Description: Detects '#N:' tag at line start and strips it.
// sLine:       Line (will be stripped if tag found).
// Tag:         Returned tag for styling (if applicable).
// bBullet:     True if '#7:' tag was detected for this line.
// Result:      True if a supported tag was found and stripped.
// Note:        Tag persistence is handled by the caller (TagCur).
// Example:     if DetectTagAndStrip(s, TagTmp, bBullet) then ...
function DetectTagAndStrip(var sLine: ansistring; out Tag: THelpTag; out bBullet: boolean): boolean;
var
  sPrefix: ansistring;
begin
  Result := False;
  Tag := htNormal;
  bBullet := False;

  if Length(sLine) < 3 then
    Exit;

  if (sLine[1] = '#') and (sLine[3] = ':') then
  begin
    sPrefix := Copy(sLine, 1, 3);

    if sPrefix = '#1:' then Tag := htTitleBig
    else if sPrefix = '#2:' then Tag := htTitleSmall
    else if sPrefix = '#3:' then Tag := htNormal
    else if sPrefix = '#4:' then Tag := htItalic
    else if sPrefix = '#5:' then Tag := htMono
    else if sPrefix = '#6:' then Tag := htSmall
    else if sPrefix = '#7:' then
    begin
      Tag := htNormal;
      bBullet := True;
    end
    else
      Exit;

    Delete(sLine, 1, 3);
    if (Length(sLine) > 0) and (sLine[1] = ' ') then
      Delete(sLine, 1, 1);

    Result := True;
  end;
end;

// Name:        IsBulletLine
// Description: Checks if a line is a bullet and returns stripped content.
// sLine:       Input line.
// sOut:        Output line (bullet symbol + content) if bullet.
// Result:      True if bullet was detected.
// Note:        Supports '- ', '* ' and already '• '
// Example:     if IsBulletLine(s, s2) then ...
function IsBulletLine(const sLine: ansistring; out sOut: ansistring): boolean;
begin
  Result := False;
  sOut := sLine;

  if (Length(sLine) >= 2) and (Copy(sLine, 1, 2) = '- ') then
  begin
    sOut := '• ' + Copy(sLine, 3, MaxInt);
    Exit(True);
  end;

  if (Length(sLine) >= 2) and (Copy(sLine, 1, 2) = '* ') then
  begin
    sOut := '• ' + Copy(sLine, 3, MaxInt);
    Exit(True);
  end;

  if (Length(sLine) >= 2) and (Copy(sLine, 1, 2) = '• ') then
  begin
    sOut := sLine;
    Exit(True);
  end;
end;

// Name:        MakeFontParamsForTag
// Description: Creates TFontParams for the given tag.
// Tag:         The style tag.
// Spec:        Render specification.
// Result:      Font params for RichMemo.
// Note:        Keep to supported fields (Name/Size/Style).
// Example:     FP := MakeFontParamsForTag(htNormal, Spec);
function MakeFontParamsForTag(const Tag: THelpTag; const Spec: THelpRenderSpec): TFontParams;
begin
  FillChar(Result, SizeOf(Result), 0);

  Result.Name := Spec.sFontNameNormal;
  Result.Size := Spec.iSizeNormal;
  Result.Style := [];

  case Tag of
    htTitleBig:
    begin
      Result.Size := Spec.iSizeTitleBig;
      Result.Style := [fsBold];
    end;

    htTitleSmall:
    begin
      Result.Size := Spec.iSizeTitleSmall;
      Result.Style := [fsBold];
    end;

    htItalic:
    begin
      Result.Size := Spec.iSizeNormal;
      Result.Style := [fsItalic];
    end;

    htMono:
    begin
      Result.Name := Spec.sFontNameMono;
      Result.Size := Spec.iSizeNormal;
      Result.Style := [];
    end;

    htSmall:
    begin
      Result.Size := Spec.iSizeSmall;
      Result.Style := [];
    end;
    else
    begin
      // htNormal
    end;
  end;
end;

// Name:        AppendStyledLineUtf8
// Description: Appends a line and applies style using UTF-8 byte offsets.
// rmTarget:    Target RichMemo.
// sLine:       Line text WITHOUT line ending.
// FPLine:      Style for line text.
// FPNormal:    Style for the LineEnding (prevents style bleeding).
// iPosUtf8:    Current UTF-8 byte cursor (updated by this procedure).
// Note:        This is the key fix for the “random last letter bold” bug.
// Example:     AppendStyledLineUtf8(rm, 'Main Window', FP, FPNormal, iPosUtf8);
procedure AppendStyledLineUtf8(const rmTarget: TRichMemo; const sLine: ansistring;
  const FPLine: TFontParams; const FPNormal: TFontParams; var iPosUtf8: integer);
var
  sAdd: ansistring;
  iLineBytes: integer;
  iLEBytes: integer;
begin
  sAdd := sLine + LineEnding;

  // Insert at end
  rmTarget.SelStart := rmTarget.GetTextLen;
  rmTarget.SelLength := 0;
  rmTarget.SelText := sAdd;

  iLineBytes := UTF8Length(sLine);
  iLEBytes := UTF8Length(LineEnding);

  if iLineBytes > 0 then
    rmTarget.SetTextAttributes(iPosUtf8, iLineBytes, FPLine);

  if iLEBytes > 0 then
    rmTarget.SetTextAttributes(iPosUtf8 + iLineBytes, iLEBytes, FPNormal);

  iPosUtf8 := iPosUtf8 + iLineBytes + iLEBytes;
end;

// Name:        RenderTaggedHelpFile
// Description: Loads a tagged help file and renders it into a TRichMemo.
// sFileName:   Path to the help file.
// rmTarget:    Target RichMemo.
// Spec:        Render specification (fonts/sizes).
// Note:        Tag persists until changed. '#7:' forces bullet for that line.
//              Existing contents are cleared before rendering.
// Example:     RenderTaggedHelpFile('docs/USER_GUIDE.md', rmHelp, Spec);
procedure RenderTaggedHelpFile(const sFileName: ansistring; const rmTarget: TRichMemo; const Spec: THelpRenderSpec);
var
  sl: TStringList;
  sLine, sOut: ansistring;
  iLine: integer;
  TagCur, TagTmp: THelpTag;
  FPLine: TFontParams;
  FPNormal: TFontParams;
  bTagFound: boolean;
  bBulletTag: boolean;
  iPosUtf8: integer;
begin
  if rmTarget = nil then
    Exit;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(sFileName);

    rmTarget.Lines.BeginUpdate;
    try
      rmTarget.Clear;

      TagCur := htNormal;
      FPNormal := MakeFontParamsForTag(htNormal, Spec);
      iPosUtf8 := 0;

      for iLine := 0 to sl.Count - 1 do
      begin
        sLine := TrimLineEndings(sl[iLine]);

        bTagFound := DetectTagAndStrip(sLine, TagTmp, bBulletTag);
        if bTagFound and (not bBulletTag) then
          TagCur := TagTmp;

        if bBulletTag then
          sLine := '• ' + sLine
        else if IsBulletLine(sLine, sOut) then
          sLine := sOut;

        FPLine := MakeFontParamsForTag(TagCur, Spec);
        AppendStyledLineUtf8(rmTarget, sLine, FPLine, FPNormal, iPosUtf8);
      end;

      rmTarget.SelStart := 0;
      rmTarget.SelLength := 0;
    finally
      rmTarget.Lines.EndUpdate;
    end;

  finally
    sl.Free;
  end;
end;

end.
