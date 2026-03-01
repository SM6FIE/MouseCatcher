program MouseCatcher;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, runtimetypeinfocontrols, uMouseCatcher, uStats, uInputStats, uAbout, uHelpRender, uUserGuide, uDocOpenLib;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TStatsFrm, StatsFrm);
  Application.CreateForm(TAboutFrm, AboutFrm);
  Application.CreateForm(TUserGuideFrm, UserGuideFrm);
  Application.Run;
end.

