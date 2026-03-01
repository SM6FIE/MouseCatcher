unit uMouseCatcher;

{$mode objfpc}{$H+}

// Unit:        uMouseCatcher
// Project:     MouseCatcher
// Date:        2026-02-23 21:05:00
// Version:     1.3
// Description: Mouse diagnostic tool with plot, trail, counters and timing feed.
// Note:        Motion timing (dt) is collected and stored in uInputStats for plotting in StatsFrm.
//              Reset counters also resets dt stats and resets StatsFrm status message state.
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Menus,
  Math, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    LedRight2: TShape;
    miAbout: TMenuItem;
    miDevNotes: TMenuItem;
    miUserGuide: TMenuItem;
    Separator1: TMenuItem;
    miFile: TMenuItem;
    miStats: TMenuItem;
    TopPanel: TPanel;
    BtnGroup: TGroupBox;

    LedLeft: TShape;
    LedMiddle: TShape;
    LedRight: TShape;
    LedBack: TShape;
    LedForward: TShape;

    LblLeft: TLabel;
    LblMiddle: TLabel;
    LblRight: TLabel;
    LblPos: TLabel;
    LblMoves: TLabel;
    LblDistance: TLabel;
    LblWheel: TLabel;
    LblCapture: TLabel;

    BtnReset: TButton;
    PaintBox: TPaintBox;

    MainMenu1: TMainMenu;
    miClose: TMenuItem;
    miView: TMenuItem;

    procedure FormCreate(Sender: TObject);
    procedure BtnResetClick(Sender: TObject);
    procedure miAboutClick(Sender: TObject);
    procedure miDevNotesClick(Sender: TObject);
    procedure miUserGuideClick(Sender: TObject);

    procedure PaintBoxPaint(Sender: TObject);
    procedure PaintBoxMouseLeave(Sender: TObject);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure PaintBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: integer;
      MousePos: TPoint; var Handled: boolean);

    procedure miCloseClick(Sender: TObject);
    procedure miStatsClick(Sender: TObject);

  private
  const
    TailMax = 70;

  private
    LeftClicks, MiddleClicks, RightClicks: int64;
    BackClicks, ForwardClicks: int64;
    MoveEvents: int64;
    WheelUp, WheelDown: int64;
    TotalDistance: double;

    LastPosValid: boolean;
    LastPos: TPoint;

    DotPosValid: boolean;
    DotPos: TPoint;

    IsLeftDown, IsMiddleDown, IsRightDown: boolean;
    IsBackDown, IsForwardDown: boolean;

    Tail: array of TPoint;
    TailCount: integer;

    LastMoveTickValid: boolean;
    LastMoveTickMs: QWord;

    procedure UpdateUI;
    procedure SetLed(const Led: TShape; const OnState: boolean);

    procedure ResetAll;
    procedure TailClear;
    procedure TailPush(const P: TPoint);

    function AnyButtonDown: boolean;

    procedure RefreshStatsIfVisible;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  uInputStats, uStats, uAbout, uUserGuide, uDocOpenLib;

// Name:        FormCreate
// Description: Initializes state and assigns menu handlers.
// Sender:      Standard Lazarus event sender.
// Note:        Menu handlers are assigned here so the designer does not need to wire events.
// Example:     FormCreate(Sender);
procedure TForm1.FormCreate(Sender: TObject);
begin
  miClose.OnClick := @miCloseClick;
  miStats.OnClick := @miStatsClick;

  TailClear;
  ResetAll;
end;

// Name:        miCloseClick
// Description: Closes the application.
// Sender:      Standard Lazarus event sender.
// Note:        Closes the main form.
// Example:     miCloseClick(Sender);
procedure TForm1.miCloseClick(Sender: TObject);
begin
  Close;
end;

// Name:        miStatsClick
// Description: Opens the Statistics form.
// Sender:      Standard Lazarus event sender.
// Note:        Creates StatsFrm on first use, then shows it non-modal.
// Example:     miStatsClick(Sender);
procedure TForm1.miStatsClick(Sender: TObject);
begin
  if StatsFrm = nil then
    Application.CreateForm(TStatsFrm, StatsFrm);

  StatsFrm.Show;
  StatsFrm.BringToFront;
  StatsFrm.RefreshNow(True);
end;

// Name:        BtnResetClick
// Description: Resets counters and clears trail.
// Sender:      Standard Lazarus event sender.
// Note:        Also resets dt statistics and status message state used by StatsFrm.
// Example:     BtnResetClick(Sender);
procedure TForm1.BtnResetClick(Sender: TObject);
begin
  ResetAll;
end;

// Name:        miAboutClick
// Description: Show about MouseCatcher form
// Sender:      Main menu event
// Note:        XX
// Example:     miAboutClick(Sender);
procedure TForm1.miAboutClick(Sender: TObject);
begin
  AboutFrm.Show;
end;

// Name:        miDevNotesClick
// Description: Show form with development notes
// Sender:      Main menu event
// Note:        XX
// Example:     miDevNotesClick((Sender);
procedure TForm1.miDevNotesClick(Sender: TObject);
begin
  OpenMyDoc('MouseCatcher_Technical_Documentation_v1_9.pdf');
  // OpenMyDoc('Kalle');
end;

// Name:        miUserGuideClick
// Description: Show PDF dokument with user guide
// Sender:      Main menu event
// Note:        XX
// Example:     miUserGuideClick(Sender);
procedure TForm1.miUserGuideClick(Sender: TObject);
begin
  UserGuideFrm.Show;
end;

// Name:        AnyButtonDown
// Description: Returns True if any tracked mouse button is currently held down.
// Result:      True when any button is down.
// Note:        Used to decide when it is safe to release capture.
// Example:     bAny := AnyButtonDown;
function TForm1.AnyButtonDown: boolean;
begin
  Result := IsLeftDown or IsMiddleDown or IsRightDown or IsBackDown or IsForwardDown;
end;

// Name:        RefreshStatsIfVisible
// Description: Refreshes StatsFrm if it exists and is visible.
// Note:        Avoids relying solely on the stats timer and makes live updates robust.
// Example:     RefreshStatsIfVisible;
procedure TForm1.RefreshStatsIfVisible;
begin
  if (StatsFrm <> nil) and StatsFrm.Visible then
    StatsFrm.RefreshNow(False);
end;

// Name:        ResetAll
// Description: Resets all counters and internal state.
// Note:        Clears tail, resets dt stats and resets StatsFrm status messages.
// Example:     ResetAll;
procedure TForm1.ResetAll;
begin
  LeftClicks := 0;
  MiddleClicks := 0;
  RightClicks := 0;
  BackClicks := 0;
  ForwardClicks := 0;

  MoveEvents := 0;
  WheelUp := 0;
  WheelDown := 0;
  TotalDistance := 0;

  LastPosValid := False;
  DotPosValid := False;

  IsLeftDown := False;
  IsMiddleDown := False;
  IsRightDown := False;
  IsBackDown := False;
  IsForwardDown := False;

  LastMoveTickValid := False;
  LastMoveTickMs := 0;

  SetCaptureControl(nil);
  TailClear;

  ResetDtStats;

  if StatsFrm <> nil then
    StatsFrm.ClearMsgFlag;

  UpdateUI;
  PaintBox.Invalidate;

  RefreshStatsIfVisible;
end;

// Name:        SetLed
// Description: Updates a LED indicator according to state.
// Led:         LED control.
// OnState:     True = active (green), False = inactive (maroon).
// Note:        Visual indication only.
// Example:     SetLed(LedLeft, True);
procedure TForm1.SetLed(const Led: TShape; const OnState: boolean);
begin
  if OnState then
    Led.Brush.Color := clLime
  else
    Led.Brush.Color := clMaroon;
end;

// Name:        UpdateUI
// Description: Refreshes labels and LED indicators.
// Note:        Uses current internal counters and states.
// Example:     UpdateUI;
procedure TForm1.UpdateUI;
begin
  SetLed(LedLeft, IsLeftDown);
  SetLed(LedMiddle, IsMiddleDown);
  SetLed(LedRight, IsRightDown);
  SetLed(LedBack, IsBackDown);
  SetLed(LedForward, IsForwardDown);

  if DotPosValid then
    LblPos.Caption := Format('Pos: (%d, %d)', [DotPos.X, DotPos.Y])
  else
    LblPos.Caption := 'Pos: (outside)';

  LblMoves.Caption := Format('Moves: %d  |  L:%d  M:%d  R:%d  B:%d  F:%d', [MoveEvents,
    LeftClicks, MiddleClicks, RightClicks, BackClicks, ForwardClicks]);

  LblDistance.Caption := Format('Distance: %.1f px', [TotalDistance]);
  LblWheel.Caption := Format('Wheel: Up %d / Down %d', [WheelUp, WheelDown]);

  if GetCaptureControl = PaintBox then
    LblCapture.Caption := 'Capture: YES'
  else
    LblCapture.Caption := 'Capture: no';
end;

// Name:        TailClear
// Description: Clears the motion tail.
// Note:        Tail is drawn in PaintBoxPaint.
// Example:     TailClear;
procedure TForm1.TailClear;
begin
  TailCount := 0;
  SetLength(Tail, TailMax);
end;

// Name:        TailPush
// Description: Adds a new point to the tail.
// P:           New point in PaintBox coordinates.
// Note:        Keeps only the last TailMax points.
// Example:     TailPush(Point(X,Y));
procedure TForm1.TailPush(const P: TPoint);
var
  i: integer;
begin
  if TailCount < TailMax then
  begin
    Tail[TailCount] := P;
    Inc(TailCount);
    Exit;
  end;

  for i := 0 to TailMax - 2 do
    Tail[i] := Tail[i + 1];

  Tail[TailMax - 1] := P;
end;

// Name:        PaintBoxPaint
// Description: Draws move area background, tail, and dot marker.
// Sender:      Standard Lazarus event sender.
// Note:        Uses your chosen colors for nicer appearance.
// Example:     PaintBoxPaint(Sender);
procedure TForm1.PaintBoxPaint(Sender: TObject);
var
  i: integer;
begin
  PaintBox.Canvas.Brush.Color := $00FFFDE4;
  PaintBox.Canvas.FillRect(PaintBox.ClientRect);

  PaintBox.Canvas.Pen.Color := clRed;

  if TailCount >= 2 then
  begin
    for i := 1 to TailCount - 1 do
      PaintBox.Canvas.Line(Tail[i - 1].X, Tail[i - 1].Y, Tail[i].X, Tail[i].Y);
  end;

  if DotPosValid then
  begin
    PaintBox.Canvas.Brush.Color := clRed;
    PaintBox.Canvas.Ellipse(DotPos.X - 4, DotPos.Y - 4, DotPos.X + 4, DotPos.Y + 4);
  end;
end;

// Name:        PaintBoxMouseLeave
// Description: Marks cursor as outside the plot area.
// Sender:      Standard Lazarus event sender.
// Note:        Does not reset counters; only affects UI position status.
// Example:     PaintBoxMouseLeave(Sender);
procedure TForm1.PaintBoxMouseLeave(Sender: TObject);
begin
  DotPosValid := False;
  UpdateUI;
end;

// Name:        PaintBoxMouseMove
// Description: Tracks mouse movement, updates tail and timing dt samples.
// Sender:      Standard Lazarus event sender.
// Note:        dt is measured using GetTickCount64 to estimate motion event spacing.
// Example:     PaintBoxMouseMove(Sender, Shift, X, Y);
procedure TForm1.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
var
  P: TPoint;
  dDx, dDy: double;
  qNowMs: QWord;
  cDt: cardinal;
begin
  P := Point(X, Y);

  DotPosValid := True;
  DotPos := P;

  TailPush(P);

  if LastPosValid then
  begin
    dDx := P.X - LastPos.X;
    dDy := P.Y - LastPos.Y;
    TotalDistance := TotalDistance + Sqrt(dDx * dDx + dDy * dDy);
  end;

  LastPos := P;
  LastPosValid := True;

  Inc(MoveEvents);

  qNowMs := GetTickCount64;
  if LastMoveTickValid then
  begin
    if qNowMs >= LastMoveTickMs then
    begin
      cDt := cardinal(qNowMs - LastMoveTickMs);
      AddDtSampleMs(cDt);
    end;
  end;

  LastMoveTickMs := qNowMs;
  LastMoveTickValid := True;

  UpdateUI;
  PaintBox.Invalidate;

  RefreshStatsIfVisible;
end;

// Name:        PaintBoxMouseDown
// Description: Handles mouse button press and updates LEDs/counters.
// Sender:      Standard Lazarus event sender.
// Button:      Which mouse button was pressed.
// Note:        Uses SetCaptureControl(PaintBox) so dragging continues outside.
// Example:     PaintBoxMouseDown(Sender, Button, Shift, X, Y);
procedure TForm1.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  SetCaptureControl(PaintBox);

  case Button of
    mbLeft:
    begin
      IsLeftDown := True;
      Inc(LeftClicks);
    end;
    mbMiddle:
    begin
      IsMiddleDown := True;
      Inc(MiddleClicks);
    end;
    mbRight:
    begin
      IsRightDown := True;
      Inc(RightClicks);
    end;
    mbExtra1:
    begin
      IsBackDown := True;
      Inc(BackClicks);
    end;
    mbExtra2:
    begin
      IsForwardDown := True;
      Inc(ForwardClicks);
    end;
  end;

  UpdateUI;
end;

// Name:        PaintBoxMouseUp
// Description: Handles mouse button release and releases capture if safe.
// Sender:      Standard Lazarus event sender.
// Button:      Which mouse button was released.
// Note:        Releases capture only when no tracked buttons remain pressed.
// Example:     PaintBoxMouseUp(Sender, Button, Shift, X, Y);
procedure TForm1.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  case Button of
    mbLeft: IsLeftDown := False;
    mbMiddle: IsMiddleDown := False;
    mbRight: IsRightDown := False;
    mbExtra1: IsBackDown := False;
    mbExtra2: IsForwardDown := False;
  end;

  if not AnyButtonDown then
    SetCaptureControl(nil);

  UpdateUI;
end;

// Name:        PaintBoxMouseWheel
// Description: Tracks wheel up/down events.
// Sender:      Standard Lazarus event sender.
// WheelDelta:  Wheel movement delta.
// Handled:     Set True to mark handled.
// Note:        WheelDelta > 0 means up, < 0 means down.
// Example:     PaintBoxMouseWheel(Sender, Shift, WheelDelta, MousePos, Handled);
procedure TForm1.PaintBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: integer;
  MousePos: TPoint; var Handled: boolean);
begin
  if WheelDelta > 0 then
    Inc(WheelUp)
  else if WheelDelta < 0 then
    Inc(WheelDown);

  Handled := True;
  UpdateUI;
end;

end.
