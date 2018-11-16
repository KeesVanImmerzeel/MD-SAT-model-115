program HlpDSmodel115;

uses
  Forms,
  Sysutils,
  Dialogs,
  uHlpDsModel115 in 'uHlpDsModel115.pas' {MainForm},
  System.UITypes,
  uModel115ProgramSettings in 'uModel115ProgramSettings.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Try
    Try
      if ( Mode = Interactive ) then begin
        Application.Run;
      end else begin
        {MainForm.GoButton.Click;}
      end;
    Except
      Try Writeln( lf, Format( 'Error in application: [%s].', [Application.ExeName] ) ); except end;
      MessageDlg( Format( 'Error in application: [%s].', [Application.ExeName] ), mtError, [mbOk], 0);
    end;
  Finally
  end;

end.
