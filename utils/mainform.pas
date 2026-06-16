unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, EditBtn, StdCtrls, ComCtrls, Menus, ExtCtrls, spamfilter
  ;

type

  { TFrmMain }

  TVisualSpamFilter = class(TSpamFilter)
  public
    property Words;
    property SpamCount;
    property HamCount;
    property TotalSpamWords;
    property TotalHamWords;
  end;

  TFrmMain = class(TForm)
    BtnClassify: TButton;
    BtnSpam: TButton;
    BtnHam: TButton;
    BtnSave: TButton;
    DrctryEdtWords: TDirectoryEdit;
    GrpBxMessage: TGroupBox;
    GrpBxBase: TGroupBox;
    miDeleteRow: TMenuItem;
    MmMessage: TMemo;
    ppmnWords: TPopupMenu;
    Spltr: TSplitter;
    SttsBrMessage: TStatusBar;
    StrngGrdWordBase: TStringGrid;
    procedure BtnClassifyClick({%H-}Sender: TObject);
    procedure BtnHamClick({%H-}Sender: TObject);
    procedure BtnSpamClick({%H-}Sender: TObject);
    procedure BtnSaveClick({%H-}Sender: TObject);
    procedure DrctryEdtWordsAcceptDirectory({%H-}Sender: TObject; var Value: String);
    procedure FormClose({%H-}Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormDestroy({%H-}Sender: TObject);
    procedure miDeleteRowClick({%H-}Sender: TObject);
    procedure MmMessageChange({%H-}Sender: TObject);
    procedure StrngGrdWordBaseCompareCells(Sender: TObject; ACol, ARow, {%H-}BCol, BRow: Integer; var Result: integer);
    procedure StrngGrdWordBaseSetEditText({%H-}Sender: TObject; ACol, aRow: Integer; const Value: string);
  private
    FSpamFilter: TVisualSpamFilter;
    FCol1Asc: Boolean;
    FCol2Asc: Boolean;
    procedure OpenBase(const aDir: String);
  public

  end;

var
  FrmMain: TFrmMain;

implementation

uses
  Math
  ;

{$R *.lfm}

{ TFrmMain }

procedure TFrmMain.DrctryEdtWordsAcceptDirectory(Sender: TObject; var Value: String);
begin
  OpenBase(Value);
end;

procedure TFrmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if CloseAction=caFree then
  begin
    if StrngGrdWordBase.Modified then
      FSpamFilter.Save;
  end;
end;

procedure TFrmMain.BtnClassifyClick(Sender: TObject);
var
  aSpamProbability, aHamProbability: Double;
begin
  FSpamFilter.Classify(MmMessage.Lines.Text, aHamProbability, aSpamProbability);
  SttsBrMessage.SimpleText:=Format('Spam prob.: %n, Ham prob. %n. Factor: %n', [aSpamProbability, aHamProbability,
    aSpamProbability-aHamProbability]);
end;

procedure TFrmMain.BtnHamClick(Sender: TObject);
begin 
  FSpamFilter.Train(MmMessage.Lines.Text, False);
  FSpamFilter.Save;
  StrngGrdWordBase.Modified:=False;
  OpenBase(DrctryEdtWords.Directory);
end;

procedure TFrmMain.BtnSpamClick(Sender: TObject);
begin
  FSpamFilter.Train(MmMessage.Lines.Text, True);
  FSpamFilter.Save;                
  StrngGrdWordBase.Modified:=False;
  OpenBase(DrctryEdtWords.Directory);
end;

procedure TFrmMain.BtnSaveClick(Sender: TObject);
begin
  FSpamFilter.StorageDir:=IncludeTrailingPathDelimiter(DrctryEdtWords.Directory);
  FSpamFilter.Save;     
  StrngGrdWordBase.Modified:=False;
end;

procedure TFrmMain.FormCreate(Sender: TObject);
begin
  FSpamFilter:=TVisualSpamFilter.Create;
  OpenBase(EmptyStr);
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  FSpamFilter.Free;
end;

procedure TFrmMain.miDeleteRowClick(Sender: TObject);
var
  aRow: Integer;
  aWord: String;
begin
  aRow:=StrngGrdWordBase.Row;
  if aRow>=StrngGrdWordBase.FixedRows then
  begin
    aWord:=StrngGrdWordBase.Cells[0, aRow];
    if FSpamFilter.DeleteWord(aWord) then
    begin
      StrngGrdWordBase.DeleteRow(aRow);
      StrngGrdWordBase.Modified:=True;
    end
    else
      MessageDlg(Caption, Format('Can''t remove word %s', [aWord]), mtError, [mbClose], '');
  end;
end;

procedure TFrmMain.MmMessageChange(Sender: TObject);
begin
  SttsBrMessage.Panels.Clear;
end;

procedure TFrmMain.StrngGrdWordBaseCompareCells(Sender: TObject; ACol, ARow, BCol, BRow: Integer; var Result: integer);
var
  aGrid: TStringGrid;
  a, b: Integer;
begin
  if ACol <= 0 then Exit;

  aGrid := TStringGrid(Sender);

  a := StrToIntDef(aGrid.Cells[ACol, ARow], 0);
  b := StrToIntDef(aGrid.Cells[ACol, BRow], 0);

  Result := CompareValue(a, b);

  case ACol of
    1: if not FCol1Asc then Result := -Result;
    2: if not FCol2Asc then Result := -Result;
  end;
end;

procedure TFrmMain.StrngGrdWordBaseSetEditText(Sender: TObject; ACol, aRow: Integer; const Value: string);
var
  aValue: Longint;
  aWord: String;
  aCounterRec: TCountRec;
begin
  if ACol>0 then
    if TryStrToInt(Value, aValue) then
    begin
      aWord:=StrngGrdWordBase.Cells[0, aRow];
      aCounterRec:=FSpamFilter.WordCounters[aWord];
      aCounterRec.Ham:=StrngGrdWordBase.Cells[1, aRow].ToInteger;
      aCounterRec.Spam:=StrngGrdWordBase.Cells[2, aRow].ToInteger;
      FSpamFilter.WordCounters[aWord]:=aCounterRec;
    end;
end;

procedure TFrmMain.OpenBase(const aDir: String);
var
  i: Integer;
begin
  StrngGrdWordBase.Clear;
  FSpamFilter.StorageDir:=IncludeTrailingPathDelimiter(aDir);
  FSpamFilter.LoadJSON(True);
  StrngGrdWordBase.RowCount:=FSpamFilter.Words.Count+1;
  for i:=0 to FSpamFilter.Words.Count-1 do
  begin
    StrngGrdWordBase.Cells[0, i+1]:=FSpamFilter.Words.Keys[i];
    StrngGrdWordBase.Cells[1, i+1]:=FSpamFilter.Words.Data[i].Ham.ToString;
    StrngGrdWordBase.Cells[2, i+1]:=FSpamFilter.Words.Data[i].Spam.ToString;
  end;
  StrngGrdWordBase.Modified := False;
end;

end.

