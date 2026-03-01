unit uAbout;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, eventlog, process, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LazHelpHTML, Arrow, RichMemo,
  SynHighlighterHTML, IpHtml, RTTICtrls;

type

  { TAboutFrm }

  TAboutFrm = class(TForm)
    btClose: TButton;
    Image1: TImage;
    Panel1: TPanel;
    Panel2: TPanel;
    RichMemo1: TRichMemo;
    procedure btCloseClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RichMemo1Change(Sender: TObject);
  private

  public

  end;

var
  AboutFrm: TAboutFrm;

implementation

{$R *.lfm}

uses uHelpRender;

{ TAboutFrm }

procedure TAboutFrm.FormShow(Sender: TObject);
begin
  //  LoadTaggedHelpFileToRichMemo(
  //  ExtractFilePath(Application.ExeName) + 'doc/USER_GUIDE.txt',
  //  RichMemo1
  //);
end;

procedure TAboutFrm.RichMemo1Change(Sender: TObject);
begin

end;

procedure TAboutFrm.btCloseClick(Sender: TObject);
begin
  Close;
end;


end.

