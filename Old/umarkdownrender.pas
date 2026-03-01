// Unit:        uHelpRender
// Project:     MouseCatcher
// Date:        2026-02-27 21:10:00  (Europe/Stockholm, vintertid)
// Version:     1.0
// Description: Renders a simple tagged help format into a TRichMemo.
// Note:        Help style spec (tagged lines):
//              - "#1:" Big title (bold, large)
//              - "#2:" Small title (bold, medium)
//              - "#3:" Normal text
//              - "#4:" Normal text, italic
//              - "#5:" Normal text, monospace (code)
//              - "#6:" Normal text, small
//              - "#7:" Bullet item (renders with leading "• ")
//              Parsing rules:
//              - If a line starts with "#N:" then that tag becomes the current style.
//              - All following lines continue with that style until a new "#N:" tag occurs.
//              - If a line does not start with "#N:" it is rendered using the current style.
//              - Empty lines are preserved and do not change the current style.
//              - Lines starting with "#N:" may contain text after the tag; that text is rendered.
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

unit uHelpRender;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RichMemo, Graphics;

type
  THelpStyleTag = (hstTitleBig, hstTitleSmall, hstNormal, hstItalic, hstMono, hstSmall, hstBullet);

procedure LoadTaggedHelpFileToRichMemo(const sFileName: string; RM: TRichMemo);

implementation

var
  FontTitleBig:   TFont;
  FontTitleSmall: TFont;
  FontNormal:     TFont;
  FontItalic:     TFont;
  FontMono:       TFont;
  FontSmall:      TFont;
  FontBullet:     TFont;

function StartsWithText(const sText, sPrefix: string): Boolean;
begin
  Result := (Copy(sText, 1, Length(sPrefix)) = sPrefix);
end;

function ParseTagFromLine(const sLine: string; out eTag: THelpStyleTag; out sRest: string): Boolean;
var
  sTag: string;
begin
  Result := False;
  sRest := sLine;

  if Length(sLine) < 3 then
    Exit(False);

  if sLine[1] <> '#' then
    Exit(False);

  // Expected "#N:" where N is 1..7
  sTag := Copy(sLine, 1, 3);
  if (sTag[3] <> ':') then
    Exit(False);

  case sTag[2] of
    '1': eTag := hstTitleBig;
    '2': eTag := hstTitleSmall;
    '3': eTag := hstNormal;
    '4': eTag := hstItalic;
    '5': eTag := hstMono;
    '6': eTag := hstSmall;
    '7': eTag := hstBullet;
  else
    Exit(False);
  end;

  sRest := TrimLeft(Copy(sLine, 4, MaxInt));
  Result := True;
end;

function FontForTag(const eTag: THelpStyleTag): TFont;
begin
  case eTag of
    hstTitleBig:   Result := FontTitleBig;
    hstTitleSmall: Result := FontTitleSmall;
    hstNormal:     Result := FontNormal;
    hstItalic:     Result := FontItalic;
    hstMono:       Result := FontMono;
    hstSmall:      Result := FontSmall;
    hstBullet:     Result := FontBullet;
  else
    Result := FontNormal;
  end;
end;

procedure AddLineWithFont(RM: TRichMemo; const sLine: string; AFont: TFont);
var
  iStart: Integer;
begin
  iStart := Length(RM.Text);
  RM.Lines.Add(sLine);

  if (AFont <> nil) and (Length(sLine) > 0) then
    RM.SetTextAttributes(iStart, Length(sLine), AFont);
end;

// Name:        LoadTaggedHelpFileToRichMemo
// Description: Loads a tagged help text file and renders it into a TRichMemo.
// sFileName:   Full path to the help text file.
// RM:          Destination TRichMemo.
// Note:        Uses the tagged help style spec described in the unit header.
// Example:     LoadTaggedHelpFileToRichMemo('/path/docs/USER_GUIDE.txt', RichMemo1);
procedure LoadTaggedHelpFileToRichMemo(const sFileName: string; RM: TRichMemo);
var
  SL: TStringList;
  sLine: string;
  sText: string;
  eCurTag: THelpStyleTag;
  eNewTag: THelpStyleTag;
  bHasTag: Boolean;
begin
  if RM = nil then
    Exit;

  RM.Clear;

  if not FileExists(sFileName) then
  begin
    AddLineWithFont(RM, 'Help file not found:', FontTitleSmall);
    AddLineWithFont(RM, sFileName, FontMono);
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(sFileName);

    eCurTag := hstNormal;

    for sLine in SL do
    begin
      if Trim(sLine) = '' then
      begin
        AddLineWithFont(RM, '', FontForTag(eCurTag));
        Continue;
      end;

      bHasTag := ParseTagFromLine(sLine, eNewTag, sText);
      if bHasTag then
      begin
        eCurTag := eNewTag;
        // If "#N:" line has no text, keep it as a blank separator.
        if sText = '' then
        begin
          AddLineWithFont(RM, '', FontForTag(eCurTag));
          Continue;
        end;
      end
      else
      begin
        sText := sLine;
      end;

      if eCurTag = hstBullet then
      begin
        // Render bullet lines with a bullet prefix
        if not StartsWithText(TrimLeft(sText), '•') then
          sText := '• ' + TrimLeft(sText)
        else
          sText := TrimLeft(sText);

        AddLineWithFont(RM, sText, FontBullet);
      end
      else
      begin
        AddLineWithFont(RM, sText, FontForTag(eCurTag));
      end;
    end;

  finally
    SL.Free;
  end;
end;

procedure InitFonts;
begin
  FontTitleBig := TFont.Create;
  FontTitleBig.Name  := 'DejaVu Sans';
  FontTitleBig.Size  := 16;
  FontTitleBig.Style := [fsBold];
  FontTitleBig.Color := clBlack;

  FontTitleSmall := TFont.Create;
  FontTitleSmall.Name  := 'DejaVu Sans';
  FontTitleSmall.Size  := 13;
  FontTitleSmall.Style := [fsBold];
  FontTitleSmall.Color := clBlack;

  FontNormal := TFont.Create;
  FontNormal.Name  := 'DejaVu Sans';
  FontNormal.Size  := 11;
  FontNormal.Style := [];
  FontNormal.Color := clBlack;

  FontItalic := TFont.Create;
  FontItalic.Name  := 'DejaVu Sans';
  FontItalic.Size  := 11;
  FontItalic.Style := [fsItalic];
  FontItalic.Color := clBlack;

  FontMono := TFont.Create;
  FontMono.Name  := 'DejaVu Sans Mono';
  FontMono.Size  := 10;
  FontMono.Style := [];
  FontMono.Color := clBlack;

  FontSmall := TFont.Create;
  FontSmall.Name  := 'DejaVu Sans';
  FontSmall.Size  := 9;
  FontSmall.Style := [];
  FontSmall.Color := clBlack;

  FontBullet := TFont.Create;
  FontBullet.Name  := 'DejaVu Sans';
  FontBullet.Size  := 11;
  FontBullet.Style := [];
  FontBullet.Color := clBlack;
end;

procedure FreeFonts;
begin
  FreeAndNil(FontTitleBig);
  FreeAndNil(FontTitleSmall);
  FreeAndNil(FontNormal);
  FreeAndNil(FontItalic);
  FreeAndNil(FontMono);
  FreeAndNil(FontSmall);
  FreeAndNil(FontBullet);
end;

initialization
  InitFonts;

finalization
  FreeFonts;

end.
