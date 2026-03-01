unit uUserGuide;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, RichMemo,
  uHelpRender;

type

  { TUserGuideFrm }

  TUserGuideFrm = class(TForm)
    btClose: TButton;
    Panel1: TPanel;
    rmUserGuide: TRichMemo;
    procedure btCloseClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
  public

  end;

var
  UserGuideFrm: TUserGuideFrm;

implementation

{$R *.lfm}

{ TUserGuideFrm }

procedure TUserGuideFrm.btCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TUserGuideFrm.FormShow(Sender: TObject);
var
  Spec: THelpRenderSpec;
begin
  Spec := DefaultHelpRenderSpec;
  RenderTaggedHelpFile('docs/USER_GUIDE.txt', rmUserGuide, Spec);
end;



end.
