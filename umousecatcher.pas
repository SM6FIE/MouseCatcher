unit uMouseCatcher;

{$mode objfpc}{$H+}

// Unit:        uMouseCatcher
// Project:     MouseCatcher
// Date:        2026-02-23 01:27:13
// Version:     1.0
// Description: Mouse diagnostic tool with plot, trail and counters.
// Note:        Intended for diagnosing mouse hardware/driver issues by visualizing
//              pointer movement and counting button/wheel events including XButtons.
//              Plot area equals PaintBox client area defined in the form designer (.lfm).
// Author:      Bo Gärdmark, SM6FIE, Gothenburg, SWEDEN, boarne.gardmark@gamil.com
// Copyright:   All rights reserved, Copyright Bo Gärdmark 2022
// Dissclaimer: DISCLAIMER OF WARRANTY - The SOFTWARE is provided as is without warranty of any kind.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Math, Types;

type
  TForm1 = class(TForm)
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

    procedure FormCreate(Sender: TObject);
    procedure BtnResetClick(Sender: TObject);

    procedure PaintBoxPaint(Sender: TObject);
    procedure PaintBoxMouseLeave(Sender: TObject);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);

  private
    const TailMax = 70;

  private
    LeftClicks, MiddleClicks, RightClicks: Int64;
    BackClicks, ForwardClicks: Int64;
    MoveEvents: Int64;
    WheelUp, WheelDown: Int64;
    TotalDistance: Double;

    LastPosValid: Boolean;
    LastPos: TPoint;

    DotPosValid: Boolean;
    DotPos: TPoint;

    IsLeftDown, IsMiddleDown, IsRightDown: Boolean;
    IsBackDown, IsForwardDown: Boolean;

    Tail: array of TPoint;
    TailCount: Integer;

    procedure UpdateUI;
    procedure SetLed(const Led: TShape; const OnState: Boolean);

    procedure ResetAll;
    procedure TailClear;
    procedure TailPush(const P: TPoint);

    function AnyButtonDown: Boolean;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

// Name:        FormCreate
// Description: Initializes state and resets counters.
// Sender:      Standard Lazarus event sender.
// Note:        Calls ResetAll which also refreshes UI and redraws plot.
// Example:     FormCreate(Sender);
procedure TForm1.FormCreate(Sender: TObject);
begin
  TailClear;
  ResetAll;
end;

// Name:        BtnResetClick
// Description: Resets counters and clears trail.
// Sender:      Standard Lazarus event sender.
// Note:        Equivalent to ResetAll.
// Example:     BtnResetClick(Sender);
procedure TForm1.BtnResetClick(Sender: TObject);
begin
  ResetAll;
end;

// Name:        AnyButtonDown
// Description: Returns True if any tracked mouse button is currently held down.
// Note:        Used to decide when it is safe to release capture.
// Example:     AnyButtonDown;
function TForm1.AnyButtonDown: Boolean;
begin
  Result := IsLeftDown or IsMiddleDown or IsRightDown or IsBackDown or IsForwardDown;
end;

// Name:        ResetAll
// Description: Resets all counters and internal state.
// Note:        Releases mouse capture, clears tail and triggers repaint.
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

  SetCaptureControl(nil);
  TailClear;

  UpdateUI;
  PaintBox.Invalidate;
end;

// Name:        SetLed
// Description: Updates a LED indicator according to state.
// Led:         LED control.
// OnState:     True = active (green), False = inactive (maroon).
// Note:        Visual indication only.
// Example:     SetLed(LedLeft, True);
procedure TForm1.SetLed(const Led: TShape; const OnState: Boolean);
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

  LblMoves.Caption := Format('Moves: %d  |  L:%d  M:%d  R:%d  B:%d  F:%d',
    [MoveEvents, LeftClicks, MiddleClicks, RightClicks, BackClicks, ForwardClicks]);

  LblDistance.Caption := Format('Distance: %.1f px', [TotalDistance]);
  LblWheel.Caption := Format('Wheel: Up %d / Down %d', [WheelUp, WheelDown]);

  if GetCaptureControl = PaintBox then
    LblCapture.Caption := 'Capture: YES'
  else
    LblCapture.Caption := 'Capture: no';
end;

// Name:        TailClear
// Description: Clears trail history.
// Note:        Resets tail count and frees the dynamic array.
// Example:     TailClear;
procedure TForm1.TailClear;
begin
  TailCount := 0;
  SetLength(Tail, 0);
end;

// Name:        TailPush
// Description: Adds a point to the trail.
// P:           Pointer position in PaintBox coordinates.
// Note:        Newest point is stored at index 0; buffer size is limited by TailMax.
// Example:     TailPush(P);
procedure TForm1.TailPush(const P: TPoint);
begin
  if Length(Tail) <> TailMax then
    SetLength(Tail, TailMax);

  if TailCount < TailMax then
    Inc(TailCount);

  if TailCount > 1 then
    Move(Tail[0], Tail[1], (TailCount - 1) * SizeOf(TPoint));

  Tail[0] := P;
end;

// Name:        PaintBoxPaint
// Description: Draws plot background, tail and cursor indicator.
// Sender:      Standard Lazarus event sender.
// Note:        Background and border colors are set here for consistent rendering.
// Example:     PaintBoxPaint(Sender);
procedure TForm1.PaintBoxPaint(Sender: TObject);
var
  R: TRect;
  i: Integer;
begin
  R := PaintBox.ClientRect;

  PaintBox.Canvas.Brush.Color := $00FFFDE4;
  PaintBox.Canvas.FillRect(R);

  PaintBox.Canvas.Pen.Color := clGray;
  PaintBox.Canvas.Rectangle(R);

  if TailCount > 1 then
  begin
    PaintBox.Canvas.Pen.Color := clRed;
    PaintBox.Canvas.Pen.Width := 1;
    for i := TailCount - 1 downto 1 do
      PaintBox.Canvas.Line(Tail[i].X, Tail[i].Y, Tail[i-1].X, Tail[i-1].Y);
  end;

  if DotPosValid then
  begin
    PaintBox.Canvas.Brush.Color := clRed;
    PaintBox.Canvas.Pen.Color := clRed;
    PaintBox.Canvas.Ellipse(DotPos.X - 4, DotPos.Y - 4, DotPos.X + 4, DotPos.Y + 4);
  end;
end;

// Name:        PaintBoxMouseLeave
// Description: Clears dot and trail when pointer leaves plot.
// Sender:      Standard Lazarus event sender.
// Note:        Resets LastPosValid to avoid a distance jump on re-enter.
// Example:     PaintBoxMouseLeave(Sender);
procedure TForm1.PaintBoxMouseLeave(Sender: TObject);
begin
  DotPosValid := False;
  LastPosValid := False;
  TailClear;
  UpdateUI;
  PaintBox.Invalidate;
end;

// Name:        PaintBoxMouseMove
// Description: Tracks pointer movement and updates statistics and trail.
// X:           Pointer X coordinate inside PaintBox.
// Y:           Pointer Y coordinate inside PaintBox.
// Note:        Distance is accumulated incrementally using previous point.
// Example:     PaintBoxMouseMove(Sender, Shift, X, Y);
procedure TForm1.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  Inc(MoveEvents);

  P := Point(X, Y);

  if LastPosValid then
    TotalDistance := TotalDistance + Hypot(P.X - LastPos.X, P.Y - LastPos.Y);

  LastPos := P;
  LastPosValid := True;

  DotPos := P;
  DotPosValid := True;

  TailPush(P);

  UpdateUI;
  PaintBox.Invalidate;
end;

// Name:        PaintBoxMouseDown
// Description: Handles button press and enables capture.
// Button:      Mouse button pressed.
// Note:        XButtons are mapped by LCL as mbExtra1 (Back) and mbExtra2 (Forward).
// Example:     PaintBoxMouseDown(Sender, Button, Shift, X, Y);
procedure TForm1.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetCaptureControl(PaintBox);

  case Button of
    mbLeft:   begin IsLeftDown := True;   Inc(LeftClicks);   end;
    mbMiddle: begin IsMiddleDown := True; Inc(MiddleClicks); end;
    mbRight:  begin IsRightDown := True;  Inc(RightClicks);  end;

    mbExtra1: begin IsBackDown := True;   Inc(BackClicks);   end;
    mbExtra2: begin IsForwardDown := True; Inc(ForwardClicks); end;
  end;

  UpdateUI;
end;

// Name:        PaintBoxMouseUp
// Description: Handles button release and updates capture state.
// Button:      Mouse button released.
// Note:        Capture is released when no tracked buttons are pressed.
// Example:     PaintBoxMouseUp(Sender, Button, Shift, X, Y);
procedure TForm1.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  case Button of
    mbLeft:   IsLeftDown := False;
    mbMiddle: IsMiddleDown := False;
    mbRight:  IsRightDown := False;

    mbExtra1: IsBackDown := False;
    mbExtra2: IsForwardDown := False;
  end;

  if not AnyButtonDown then
    SetCaptureControl(nil);

  UpdateUI;
end;

// Name:        PaintBoxMouseWheel
// Description: Counts wheel activity.
// WheelDelta:  Wheel delta (positive=up, negative=down).
// Handled:     Marks event handled.
// Note:        Counter increments can reveal unintended wheel activity.
// Example:     PaintBoxMouseWheel(Sender, Shift, WheelDelta, MousePos, Handled);
procedure TForm1.PaintBoxMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then
    Inc(WheelUp)
  else if WheelDelta < 0 then
    Inc(WheelDown);

  Handled := True;
  UpdateUI;
end;

end.
