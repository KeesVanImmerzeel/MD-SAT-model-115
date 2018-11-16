unit uHlpDsModel115;

interface

uses
  Windows, Forms, SysUtils, StdCtrls, Controls, Classes,  uModel115ProgramSettings,
  FileCtrl, Vcl.Dialogs, uError, Vcl.ComCtrls;

type
  TMainForm = class(TForm)
    EditDirName: TEdit;
    StaticText1: TStaticText;
    SaveDialog1: TSaveDialog;
    Button1: TButton;
    ProgressBar1: TProgressBar;
    Memo1: TMemo;
    Edit1: TEdit;
    Label1: TLabel;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure EditDirNameClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Edit1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation
{$R *.DFM}


procedure TMainForm.Button1Click(Sender: TObject);
Const
 cNrOfCrops = 14;
 cNrOfSoils = 72;
var
  f: TextFile;
  i, j, k, TableID: Integer;
  InputFileName: String;
  Function AddInfoOfFile( const InputFileName: TFileName; const TableID: Integer ): Boolean;
  var
    AscInfo: TStringList;
    nRows, nCols, i: Integer;
  begin
    Result := false;
    AscInfo := TStringList.Create;
    AscInfo.LoadFromFile( InputFileName );
    Try
      Try
        NCols := AscInfo.Strings[ 0 ].Substring( 14 ).ToInteger;
        NRows := AscInfo.Strings[ 1 ].Substring( 14 ).ToInteger;
        Writeln( f, '0     ***table ', TableID, ': table-type 0 (no interpolation)' );
        Writeln( f, NRows, ' ', NCols );
        for i:= 6 to AscInfo.Count-1  do
          Writeln( f, AscInfo.Strings[ i ] );
        Result := true;
      Except
      End;
    Finally
      AscInfo.Free;
    End;
  end;
  Function CopyInfoFromPart1ToOutputFile: Boolean;
  var
    Part1Info: TStringList;
    i: Integer;
  begin
    Result := false;
    Try
      Try
        Part1Info := TStringList.Create;
        Part1Info.LoadFromFile( ExpandFileName(Edit1.Text) );
        for i:=0 to Part1Info.Count-1 do begin
          Writeln( f, Part1Info.strings[ i ] );
          Writeln( lf, 'Written from Part1 file: ' + Part1Info.strings[ i ] );
        end;
        Writeln( lf, 'Nr of lines written: ', Part1Info.Count-1 );
      Except
      End;
      Result := true;
    Finally
       Part1Info.Free;
    End;
  end;

begin
  if SaveDialog1.Execute then begin
    Try
      Try
        if not FileExists( Edit1.Text ) then
          Raise Exception.CreateFmt('File [%s] does not exist.', [ExpandFileName(Edit1.Text)] );
        if not DirectoryExists( EditDirName.Text ) then
          Raise Exception.CreateFmt('Input Folder %s does not exist.', [EditDirName.Text] );
        AssignFile( f, SaveDialog1.FileName ); Rewrite( f );

        if not CopyInfoFromPart1ToOutputFile then
          Raise Exception.CreateFmt('Input from file [%s] could not be read.', [EditDirName.Text] );
        TableID := 3;
        ProgressBar1.Max :=  cNrOfCrops * cNrOfSoils * 2;
        ProgressBar1.Visible := true;
        for i := 1 to cNrOfCrops do begin
          for j := 1 to cNrOfSoils do begin
            for k := 1 to 2 do begin
              InputFileName := EditDirName.Text + '\hlp' + IntToStr( i ) + '-' + IntToStr( j ) + '-' + IntToStr( k ) + '.asc';
              if not FileExists( InputFileName ) then
                Raise Exception.CreateFmt('Input File %s does not exist.', [InputFileName] );
              Writeln( lf, 'Add info of file: [ ' + InputFileName + ']'  );
              if not AddInfoOfFile( InputFileName, TableID ) then
                raise Exception.CreateFmt('Cannot add info of input File %s does not exist.', [InputFileName] );
              Inc( TableID );
              ProgressBar1.StepIt;
            end; {-for k}
          end; {-for j}
        end; {-for i}
        Writeln( f, '0             Aantal tijdsafhankelijk (xy)-tabellen **********************************' );
        MessageDlg('Finished.', mtConfirmation, [mbYes], 0, mbYes)
      except
        On E: Exception do begin
          HandleError( E.Message, true );
        end;
      End;
    Finally
      {$I-} CloseFile( f ); {$I+}
      ProgressBar1.Visible := false;
    End;
  end; {-if}
end;

procedure TMainForm.Edit1Click(Sender: TObject);
begin
  if OpenDialog1.Execute then begin
    Edit1.Text := ExpandFileName( OpenDialog1.filename );
  end;

end;

procedure TMainForm.EditDirNameClick(Sender: TObject);
var
  Dir: String;
begin
  Dir := GetCurrentDir;
  if FileCtrl.SelectDirectory( Dir, [], 0 ) then
    EditDirName.Text := ExpandFileName( Dir );
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption :=  ChangeFileExt( ExtractFileName( Application.ExeName ), '' );
  
end;

end.
