unit uInputStats;

{$mode objfpc}{$H+}

// Unit:        uInputStats
// Project:     MouseCatcher
// Date:        2026-02-23 21:05:00
// Version:     1.2
// Description: Shared ring buffer for motion timing statistics (dt samples).
// Note:        This unit is intentionally UI-free to avoid circular dependencies.
//              The main form and Stats form consume these functions.
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

interface

uses
  Classes, SysUtils;

const
  DT_RING_MAX = 2000;

procedure ResetDtStats;
procedure AddDtSampleMs(const DtMs: Cardinal);
function  GetDtSnapshot(var DtMsArr: array of Cardinal): Integer;

implementation

var
  DtRing : array[0..DT_RING_MAX - 1] of Cardinal;
  iDtCount: Integer = 0;
  iDtHead : Integer = 0;

// Name:        ResetDtStats
// Description: Clears the dt ring buffer.
// Note:        After reset, GetDtSnapshot returns 0 until new samples arrive.
// Example:     ResetDtStats;
procedure ResetDtStats;
begin
  iDtCount := 0;
  iDtHead  := 0;
end;

// Name:        AddDtSampleMs
// Description: Adds one dt (milliseconds) sample to the ring buffer.
// DtMs:        Time between consecutive motion events in milliseconds.
// Note:        Ring buffer overwrites oldest samples when full.
// Example:     AddDtSampleMs(DtMs);
procedure AddDtSampleMs(const DtMs: Cardinal);
begin
  DtRing[iDtHead] := DtMs;

  Inc(iDtHead);
  if iDtHead >= DT_RING_MAX then
    iDtHead := 0;

  if iDtCount < DT_RING_MAX then
    Inc(iDtCount);
end;

// Name:        GetDtSnapshot
// Description: Copies dt samples into the caller-provided array.
// DtMsArr:     Destination array. Copies min(Length(DtMsArr), available) samples.
// Result:      Number of copied samples.
// Note:        Samples are returned in chronological order (oldest -> newest).
// Example:     iN := GetDtSnapshot(DtMsArr);
function GetDtSnapshot(var DtMsArr: array of Cardinal): Integer;
var
  i, iTmp, iStartIdx, iIdx: Integer;
begin
  iTmp := iDtCount;
  if iTmp > Length(DtMsArr) then
    iTmp := Length(DtMsArr);

  if iTmp <= 0 then
    Exit(0);

  // DtHead points to next write position. Oldest = DtHead - DtCount (wrapped).
  iStartIdx := iDtHead - iDtCount;
  while iStartIdx < 0 do
    Inc(iStartIdx, DT_RING_MAX);

  // If buffer has more than we can copy, skip (DtCount - iN) oldest samples.
  iStartIdx := (iStartIdx + (iDtCount - iTmp)) mod DT_RING_MAX;

  for i := 0 to iTmp - 1 do
  begin
    iIdx := (iStartIdx + i) mod DT_RING_MAX;
    DtMsArr[i] := DtRing[iIdx];
  end;

  Result := iTmp;
end;

end.
