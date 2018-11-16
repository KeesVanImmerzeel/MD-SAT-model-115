unit uModel115ProgramSettings;

interface

uses
  SysUtils, IniFiles, Forms, Dutils;


Type
  TMode = ( Batch, Interactive );

var
  lf: TextFile;
  fini : TiniFile;
  LogFileName, IniFileName, InitialCurrentDir: TFileName;
  Mode: TMode;

implementation

initialization
  InitialCurrentDir   := GetCurrentDir;
  LogFileName         := ChangeFileExt( Application.ExeName, '.log' );
  IniFileName         := ChangeFileExt( Application.ExeName, '.ini' );
  Mode                := Interactive;
  with FormatSettings do begin {-Delphi XE6}
    DecimalSeparator    := '.';
  end;
  Application.ShowHint := True;
  AssignFile( lf, LogFileName ); Rewrite( lf );
  fini := TIniFile.Create( IniFileName );
  Writeln( lf, Format(  DateTimeToStr(Now) + ': ' + 'Starting application: [%s].', [Application.ExeName] ) );
finalization
  Writeln( lf, Format( DateTimeToStr(Now) + ': ' +'Closing application: [%s].', [Application.ExeName] ) );
  fini.Free;
  CloseFile( lf );
  SetCurrentDir( InitialCurrentDir );
end.
