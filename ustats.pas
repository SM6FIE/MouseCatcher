unit uStats;

{$mode objfpc}{$H+}

// Unit:        uStats
// Project:     MouseCatcher
// Date:        2026-02-27 06:45:00
// Version:     1.6
// Description: Statistics form for mouse motion timing (dt) samples.
// Note:        Reads dt samples (ms) from uInputStats and presents:
//              - Time series plot (ChartDt/serDt)
//              - Histogram (ChartHist/serHist) with fixed bins 0..20 ms (1 ms bins)
//              - Summary statistics (mean, median, p95, max, drop counts)
//              Status bar behavior:
//              1) "No motion timing samples yet..." until first sample arrives
//              2) "Collecting Statistical Values..." once samples exist
//              ClearMsgFlag() forces message 1 again (used by main-form Reset).
//              Shows dt time-series and histogram. Histogram bin-span mode is controlled by
//              rgBinSpan.ItemIndex:
//              0 = Fixed bin span 0..20 ms (1 ms bins, values >20 ms are clamped into 20 ms bin)
//              1 = Floating bin span min..max (dynamic bins).
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Graphics,
  TAGraph, TASeries, Math;

type

  { TStatsFrm }

  TStatsFrm = class(TForm)
    btClose: TButton;
    btCloseHist: TButton;
    ChartHist: TChart;
    ChartDt: TChart;
    gbStatValues: TGroupBox;
    ledDrop25: TLabeledEdit;
    ledDrop50: TLabeledEdit;
    ledDtMean: TLabeledEdit;
    ledMax: TLabeledEdit;
    ledMedian: TLabeledEdit;
    ledP95: TLabeledEdit;
    ledRate: TLabeledEdit;
    ledtSamples: TLabeledEdit;
    paButtons: TPanel;
    PageControl1: TPageControl;
    rgBinSpan: TRadioGroup;
    sbStatus: TStatusBar;
    serDt: TLineSeries;
    serHist: TBarSeries;
    tsDt: TTabSheet;
    tsHist: TTabSheet;
    TmrUpdate: TTimer;
    procedure btCloseClick(Sender: TObject);
    procedure btCloseHistClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure rgBinSpanClick(Sender: TObject);
    procedure TmrUpdateTimer(Sender: TObject);
  private
  const
    PLOT_MAX          = 250;   // dt chart: number of latest samples to draw
    SNAP_MAX          = 2000;  // local snapshot size (should match ring size in uInputStats)
    BIN_COUNT_FLOAT   = 60;    // floating histogram bins

    BIN_FIXED_MIN_MS  = 0;     // fixed span lower
    BIN_FIXED_MAX_MS  = 20;    // fixed span upper (values > 20 ms are clamped into 20 ms bin)
  private
    FDtSnap: array of Cardinal;
    FMsgFlg: Boolean;          // False => message 1 active, True => message 2 active
    FLastCount: Integer;       // number of valid dt samples in FDtSnap

    procedure EnsureSnapBuffer;
    procedure SetStatusMsgNoSamples;
    procedure SetStatusMsgCollecting;
    procedure UpdateSummaryAndPlot;
    procedure UpdateHistogramUI;
  public
    procedure RefreshNow(const bForce: Boolean);
    procedure ClearMsgFlag;
  end;

var
  StatsFrm: TStatsFrm;

implementation

{$R *.lfm}

uses
  uInputStats;

// Name:        FormCreate
// Description: Initializes UI defaults for the statistics form.
// Sender:      Standard Lazarus event sender.
// Note:        Sets axis titles and help hints.
// Example:     FormCreate(Sender);
procedure TStatsFrm.FormCreate(Sender: TObject);
begin
  ChartDt.Title.Visible := True;
  ChartDt.Title.Text.Clear;
  ChartDt.Title.Alignment := taCenter;
  ChartDt.Title.Font.Size := 12;
  ChartDt.Title.Font.Style := [fsItalic];
  ChartDt.Title.Text.Add('Time order of Mouse response time');
  ChartDt.BottomAxis.Title.Caption := 'Sample # (time order)';
  ChartDt.LeftAxis.Title.Caption := 'dt (ms)';
  ChartDt.BottomAxis.Title.Visible := True;
  ChartDt.LeftAxis.Title.Visible := True;

  ChartHist.Title.Visible := True;
  ChartHist.Title.Text.Clear;
  ChartHist.Title.Alignment := taCenter;
  ChartHist.Title.Font.Size := 12;
  ChartHist.Title.Font.Style := [fsItalic];
  ChartHist.Title.Text.Add('Histogram over Mouse response time');
  ChartHist.BottomAxis.Title.Caption := 'Bin,dt (ms)';
  ChartHist.LeftAxis.Title.Caption := 'Frequency #';
  ChartHist.BottomAxis.Title.Visible := True;
  ChartHist.LeftAxis.Title.Visible := True;

  Caption := 'Mouse Statistics when moving mouse in “Mouse Area”';

  ledtSamples.Hint := 'Number of mouse move samples catches so far…';
  ledRate.Hint := 'The rate of mouse move events in samples/second (Hz)';
  ledDtMean.Hint := 'Mean response time in ms for a mouse move events';
  ledMedian.Hint := 'Median response time in ms for a mouse move events';
  ledP95.Hint := 'Show the 95% percentile in millie seconds ';
  ledMax.Hint := 'Max response time in ms for a mouse move events';
  ledDrop25.Hint := 'The number of “Drops” that are longer than 25 millie seconds';
  ledDrop50.Hint := 'The number of “Drops” that are longer than 50 millie seconds';

  ledtSamples.ShowHint := True;
  ledRate.ShowHint := True;
  ledDtMean.ShowHint := True;
  ledMedian.ShowHint := True;
  ledP95.ShowHint := True;
  ledMax.ShowHint := True;
  ledDrop25.ShowHint := True;
  ledDrop50.ShowHint := True;

  if Assigned(btCloseHist) then
  begin
    btCloseHist.ShowHint := True;
    btCloseHist.Hint := 'Close statistics window (does not stop sampling)';
  end;

  if Assigned(rgBinSpan) then
  begin
    rgBinSpan.ShowHint := True;
    rgBinSpan.Hint := 'Histogram bin span mode';
    if rgBinSpan.ItemIndex < 0 then
      rgBinSpan.ItemIndex := 0;
  end;
end;

// Name:        EnsureSnapBuffer
// Description: Ensures that the local snapshot buffer is allocated.
// Note:        Fixed size avoids reallocations during runtime.
// Example:     EnsureSnapBuffer;
procedure TStatsFrm.EnsureSnapBuffer;
begin
  if Length(FDtSnap) <> SNAP_MAX then
    SetLength(FDtSnap, SNAP_MAX);
end;

// Name:        SetStatusMsgNoSamples
// Description: Shows "no samples yet" message in the status bar (Message 1).
// Note:        Used after Reset and before first motion samples arrive.
// Example:     SetStatusMsgNoSamples;
procedure TStatsFrm.SetStatusMsgNoSamples;
begin
  if Assigned(sbStatus) then
    sbStatus.SimpleText := 'No motion timing samples yet. Move cursor in the main plot.';
  FMsgFlg := False;
end;

// Name:        SetStatusMsgCollecting
// Description: Shows "collecting" message in the status bar (Message 2).
// Note:        Only set once (guarded by FMsgFlg) to avoid unnecessary string writes.
// Example:     SetStatusMsgCollecting;
procedure TStatsFrm.SetStatusMsgCollecting;
begin
  if Assigned(sbStatus) then
    sbStatus.SimpleText := 'Collecting Statistical Values...';
  FMsgFlg := True;
end;

// Name:        ClearMsgFlag
// Description: Resets status bar back to Message 1 logic (used by main-form Reset).
// Note:        Fast path; keeps the timer refresh efficient.
// Example:     ClearMsgFlag;
procedure TStatsFrm.ClearMsgFlag;
begin
  SetStatusMsgNoSamples;
end;

// Name:        RefreshNow
// Description: Triggers an immediate refresh of the statistics form.
// bForce:      If True, refresh even if form is currently hidden.
// Note:        Safe to call from the main form after creating/showing StatsFrm.
// Example:     RefreshNow(True);
procedure TStatsFrm.RefreshNow(const bForce: Boolean);
begin
  if (csDestroying in ComponentState) then
    Exit;

  if (not bForce) and (not Visible) then
    Exit;

  UpdateSummaryAndPlot;
end;

// Name:        FormShow
// Description: Initializes UI behavior and starts timer updates.
// Sender:      Standard Lazarus event sender.
// Note:        Performs an immediate refresh so the form is not empty on open.
// Example:     FormShow(Sender);
procedure TStatsFrm.FormShow(Sender: TObject);
begin
  EnsureSnapBuffer;

  if TmrUpdate.Interval < 50 then
    TmrUpdate.Interval := 250;

  FLastCount := 0;
  SetStatusMsgNoSamples;

  TmrUpdate.Enabled := True;
  RefreshNow(True);
end;

// Name:        FormClose
// Description: Hides the statistics form instead of freeing it.
// Sender:      Standard Lazarus event sender.
// CloseAction: Requested close action.
// Note:        Avoids dangling pointer problems when main form keeps StatsFrm reference.
// Example:     FormClose(Sender, CloseAction);
procedure TStatsFrm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

// Name:        FormDestroy
// Description: Clears global StatsFrm reference when the form is destroyed.
// Sender:      Standard Lazarus event sender.
// Note:        Safety against calls to a freed form instance.
// Example:     FormDestroy(Sender);
procedure TStatsFrm.FormDestroy(Sender: TObject);
begin
  if StatsFrm = Self then
    StatsFrm := nil;
end;

// Name:        btCloseClick
// Description: Closes (hides) the statistics window.
// Sender:      Standard Lazarus event sender.
// Note:        Close triggers FormClose -> caHide.
// Example:     btCloseClick(Sender);
procedure TStatsFrm.btCloseClick(Sender: TObject);
begin
  Close;
end;

// Name:        btCloseHistClick
// Description: Closes (hides) the statistics window from the Histogram tab.
// Sender:      Standard Lazarus event sender.
// Note:        Same behavior as btCloseClick.
// Example:     btCloseHistClick(Sender);
procedure TStatsFrm.btCloseHistClick(Sender: TObject);
begin
  Close;
end;

// Name:        PageControl1Change
// Description: On tab change, update histogram when histogram tab becomes active.
// Sender:      Standard Lazarus event sender.
// Note:        Avoids empty histogram when switching tabs.
// Example:     PageControl1Change(Sender);
procedure TStatsFrm.PageControl1Change(Sender: TObject);
begin
  if PageControl1.ActivePage = tsHist then
    UpdateHistogramUI;
end;

// Name:        rgBinSpanClick
// Description: Updates histogram when the user changes bin span mode.
// Sender:      Standard Lazarus event sender.
// Note:        rgBinSpan.ItemIndex: 0=fixed 0..20ms, 1=floating min..max.
// Example:     rgBinSpanClick(Sender);
procedure TStatsFrm.rgBinSpanClick(Sender: TObject);
begin
  UpdateHistogramUI;
end;

//
// Name:        TmrUpdateTimer
// Description: Periodic refresh of statistics while form is shown.
// Sender:      Standard Lazarus event sender.
// Note:        Keeps chart and summary live without heavy processing per mouse event.
// Example:     TmrUpdateTimer(Sender);
//
procedure TStatsFrm.TmrUpdateTimer(Sender: TObject);
begin
  RefreshNow(False);
end;

// Name:        UpdateSummaryAndPlot
// Description: Copies dt samples, computes stats and updates dt chart.
// Note:        Histogram is updated from the same snapshot to keep plots consistent.
// Example:     UpdateSummaryAndPlot;
procedure TStatsFrm.UpdateSummaryAndPlot;

  // Name:        QuickSortCardinalLocal
  // Description: In-place quicksort for Cardinal array.
  // Arr:         Array to sort.
  // iL:          Left index.
  // iR:          Right index.
  // Note:        Used for median/p95/max calculation.
  // Example:     QuickSortCardinalLocal(CopyArr, 0, iCount - 1);
  procedure QuickSortCardinalLocal(var Arr: array of Cardinal; const iL, iR: Integer);
  var
    i, j: Integer;
    cPivot, cTmp: Cardinal;
  begin
    i := iL;
    j := iR;
    cPivot := Arr[(iL + iR) div 2];

    repeat
      while Arr[i] < cPivot do Inc(i);
      while Arr[j] > cPivot do Dec(j);

      if i <= j then
      begin
        cTmp := Arr[i];
        Arr[i] := Arr[j];
        Arr[j] := cTmp;
        Inc(i);
        Dec(j);
      end;
    until i > j;

    if iL < j then
      QuickSortCardinalLocal(Arr, iL, j);
    if i < iR then
      QuickSortCardinalLocal(Arr, i, iR);
  end;

  // Name:        PercentileFromSortedLocal
  // Description: Returns percentile from a sorted array.
  // Arr:         Sorted array (ascending).
  // iArrCount:   Number of valid elements.
  // dP:          Percentile in range 0..1 (e.g. 0.95 for P95).
  // Result:      Percentile value (ms).
  // Note:        Uses nearest-rank on index trunc((N-1)*p).
  // Example:     cP95Dt := PercentileFromSortedLocal(CopyArr, iCount, 0.95);
  function PercentileFromSortedLocal(const Arr: array of Cardinal; const iArrCount: Integer; const dP: Double): Cardinal;
  var
    iIdx2: Integer;
    dPP: Double;
  begin
    if iArrCount <= 0 then
      Exit(0);

    if iArrCount = 1 then
      Exit(Arr[0]);

    dPP := EnsureRange(dP, 0.0, 1.0);
    iIdx2 := Trunc((iArrCount - 1) * dPP);

    if iIdx2 < 0 then
      iIdx2 := 0;
    if iIdx2 > iArrCount - 1 then
      iIdx2 := iArrCount - 1;

    Result := Arr[iIdx2];
  end;

var
  iCount, iIdx, iPlotN: Integer;
  CopyArr: array of Cardinal;
  dSum: Double;
  dMeanDt: Double;
  cMedDt, cP95Dt, cMaxDt: Cardinal;
  dHzEst: Double;
  iDrop25, iDrop50: Integer;
begin
  EnsureSnapBuffer;

  iCount := GetDtSnapshot(FDtSnap);
  FLastCount := iCount;

  if iCount <= 0 then
  begin
    if FMsgFlg then
      SetStatusMsgNoSamples;

    serDt.Clear;
    serHist.Clear;
    Exit;
  end;

  if not FMsgFlg then
    SetStatusMsgCollecting;

  SetLength(CopyArr, iCount);
  for iIdx := 0 to iCount - 1 do
    CopyArr[iIdx] := FDtSnap[iIdx];

  QuickSortCardinalLocal(CopyArr, 0, iCount - 1);

  dSum := 0.0;
  for iIdx := 0 to iCount - 1 do
    dSum := dSum + CopyArr[iIdx];

  dMeanDt := dSum / iCount;

  cMedDt := PercentileFromSortedLocal(CopyArr, iCount, 0.50);
  cP95Dt := PercentileFromSortedLocal(CopyArr, iCount, 0.95);
  cMaxDt := CopyArr[iCount - 1];

  iDrop25 := 0;
  iDrop50 := 0;
  for iIdx := 0 to iCount - 1 do
  begin
    if FDtSnap[iIdx] > 25 then Inc(iDrop25);
    if FDtSnap[iIdx] > 50 then Inc(iDrop50);
  end;

  if cMedDt > 0 then
    dHzEst := 1000.0 / cMedDt
  else
    dHzEst := 0.0;

  ledtSamples.Text := IntToStr(iCount);
  ledRate.Text := FloatToStrF(dHzEst, ffFixed, 8, 0);
  ledDtMean.Text := FloatToStrF(dMeanDt, ffFixed, 10, 1);
  ledMedian.Text := IntToStr(cMedDt);
  ledP95.Text := IntToStr(cP95Dt);
  ledMax.Text := IntToStr(cMaxDt);
  ledDrop25.Text := IntToStr(iDrop25);
  ledDrop50.Text := IntToStr(iDrop50);

  serDt.BeginUpdate;
  try
    serDt.Clear;

    iPlotN := iCount;
    if iPlotN > PLOT_MAX then
      iPlotN := PLOT_MAX;

    for iIdx := iCount - iPlotN to iCount - 1 do
      serDt.AddXY(iIdx - (iCount - iPlotN), FDtSnap[iIdx]);
  finally
    serDt.EndUpdate;
  end;

  UpdateHistogramUI;
end;

// Name:        UpdateHistogramUI
// Description: Updates histogram series serHist using the current snapshot (FDtSnap).
// Note:        Fixed span 0..20ms uses 1 ms bins; values >20ms are clamped into 20 ms bin.
// Example:     UpdateHistogramUI;
procedure TStatsFrm.UpdateHistogramUI;
var
  iCount, iIdx, iBin, iBins: Integer;
  cMin, cMax, cRange, cBinW: Cardinal;
  Bin: array of Integer;
  dX: Double;
  iMode: Integer;
begin
  iCount := FLastCount;

  if iCount <= 0 then
  begin
    serHist.Clear;
    ChartHist.Invalidate;
    Exit;
  end;

  iMode := 0;
  if Assigned(rgBinSpan) then
    iMode := rgBinSpan.ItemIndex;

  if iMode = 0 then
  begin
    cMin := BIN_FIXED_MIN_MS;
    cMax := BIN_FIXED_MAX_MS;
    cBinW := 1;
    iBins := (BIN_FIXED_MAX_MS - BIN_FIXED_MIN_MS) + 1; // 21 bins: 0..20
  end
  else
  begin
    cMin := FDtSnap[0];
    cMax := FDtSnap[0];
    for iIdx := 1 to iCount - 1 do
    begin
      if FDtSnap[iIdx] < cMin then cMin := FDtSnap[iIdx];
      if FDtSnap[iIdx] > cMax then cMax := FDtSnap[iIdx];
    end;

    if cMax = cMin then
    begin
      serHist.Clear;
      serHist.AddXY(cMin, iCount);
      ChartHist.Invalidate;
      Exit;
    end;

    iBins := BIN_COUNT_FLOAT;
    cRange := cMax - cMin;
    cBinW := cRange div Cardinal(iBins);
    if cBinW = 0 then
      cBinW := 1;
  end;

  SetLength(Bin, iBins);
  for iIdx := 0 to iBins - 1 do
    Bin[iIdx] := 0;

  for iIdx := 0 to iCount - 1 do
  begin
    if iMode = 0 then
    begin
      if FDtSnap[iIdx] >= Cardinal(BIN_FIXED_MAX_MS) then
        iBin := BIN_FIXED_MAX_MS
      else
        iBin := Integer(FDtSnap[iIdx]);

      if iBin < 0 then iBin := 0;
      if iBin > iBins - 1 then iBin := iBins - 1;
      Inc(Bin[iBin]);
    end
    else
    begin
      iBin := Integer((FDtSnap[iIdx] - cMin) div cBinW);
      if iBin < 0 then iBin := 0;
      if iBin > iBins - 1 then iBin := iBins - 1;
      Inc(Bin[iBin]);
    end;
  end;

  serHist.BeginUpdate;
  try
    serHist.Clear;

    if iMode = 0 then
    begin
      for iIdx := 0 to iBins - 1 do
      begin
        dX := iIdx;
        serHist.AddXY(dX, Bin[iIdx]);
      end;
    end
    else
    begin
      for iIdx := 0 to iBins - 1 do
      begin
        dX := cMin + Cardinal(iIdx) * cBinW;
        serHist.AddXY(dX, Bin[iIdx]);
      end;
    end;
  finally
    serHist.EndUpdate;
  end;

  ChartHist.Invalidate;
end;

end.
