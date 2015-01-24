unit parse;

interface

uses
  Windows, System.Character, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, Grids, StdCtrls, Mask, JvExMask, JvToolEdit, StrUtils, ComCtrls,
  JvgStringGrid, JvFormPlacement, JvComponentBase, JvAppStorage,
  JvAppIniStorage;

type
  _Tag = record
    name, text: string;
    params: TStrings;
  end;

type
  _img = record
    name, url: string;
    img: array of Byte;
  end;

type
  _Imgs = array of _img;

type
  _Part = record
    number: string;
    imgs: _Imgs;
    sHTML: string;
  end;

type
  TCharSet = set of Char;

function ArrayToStr(dStr: array of Byte): string;
function GenName: string;
function GetTag(buf, tagIn, tagOut: string; var pos: integer;
  var Tag: _Tag): boolean;
function FirstDelimiter(const Delimiters, S: string; StartPos: integer)
  : integer;
function GetScript(sHTML: string): string;
// function GetImg(sHTML: string): _img;
// procedure GetImg(dImgs: _imgs);
function GetTagName(buf: string; var pos, n1, n2, l2, len: integer): string;
function ParseTable(html: string; StrGrd: TStringGrid): integer;
function GetPartsNum(sHTML: string; var StrGrd: TStrings): boolean;

implementation

function FirstDelimiter(const Delimiters, S: string; StartPos: integer)
  : integer;
var
  P: PChar;
begin
  Result := StartPos; // Length(S);
  P := PChar(Delimiters);
  while Result < Length(S) do
  begin
    if (S[Result] <> #0) and (StrScan(P, S[Result]) <> nil) then
      if (ByteType(S, Result) = mbTrailByte) then
        inc(Result)
      else
        Exit;
    inc(Result);
  end;
end;

function GetTagName(buf: string; var pos, n1, n2, l2, len: integer): string;
// var                    { TODO : ��������� �������� ��������� �� ���������� }
// n1,n2,len,l2: integer;
begin
  n1 := PosEx('<', buf, pos);
  if n1 = 0 then
    Exit;
  inc(n1);
  n2 := PosEx('>', buf, n1);
  l2 := n2;
  len := n2 - n1;
  n2 := FirstDelimiter(' >', buf, n1); // first word after <
  Result := MidStr(buf, n1, n2 - n1);
end;

function GetTag(buf, tagIn, tagOut: string; var pos: integer;
  var Tag: _Tag): boolean;
var
  S, sk: string;
  n1, n2, len, l2: integer;
begin // <<<----------
  try
    Result := false;
    S := '';
    sk := '';
    Tag.name := '';
    Tag.text := '';
    { if not Assigned(Tag.params) then
      begin
      Tag.params := TStringList.Create;
      end; }
    Tag.params.Clear;
    // s:=buf[pos];  //test
    Tag.name := GetTagName(buf, pos, n1, n2, l2, len); // ��� ����
    if (n1 = 0) then
      Exit;

    pos := n2;
    // --
    if buf[pos] <> '>' then
      while pos < l2 do
      begin
        n1 := pos + 1;
        pos := FirstDelimiter(' >"', buf, n1);
        // ����� ������� ��������� ����������
        if buf[pos] = '"' then
        begin
          pos := FirstDelimiter('>"', buf, pos + 1);
          // ����� ���������� ����������� ���������
          if buf[pos] = '"' then
            inc(pos);
        end;
        if n2 = 0 then
          pos := len + 1;
        S := MidStr(buf, n1, pos - n1);
        Tag.params.Append(S); // ������� ����� �������� ����
      end;
    // pos:=n2;
    // --
    sk := '';
    S := '';
    while (S = '') or (S = 'b') or (S = '/b') or (S = '/td') or (S = '/tr') or
      (S = 'font') or (S = '/font') do
    begin
      n1 := PosEx(tagOut, buf, pos);
      if n1 = 0 then
        break;
      inc(n1);
      n2 := PosEx(tagIn, buf, n1);
      sk := sk + MidStr(buf, n1, n2 - n1); // ������ ����� > <
      pos := n2;
      S := GetTagName(buf, pos, n1, n2, l2, len);
      // if n1=0 then Break;
    end;
    Tag.text := sk;
    Result := true;
  except
  end;
end;

function GetScript(sHTML: string): string;
var // parse HTML and get url java-script
  Tag: _Tag;
  P: integer;
begin
  P := 1;
  Tag.params := TStringList.Create;
  while P > 0 do
  begin
    P := PosEx('<script', sHTML, P);
    GetTag(sHTML, '<', '>', P, Tag);
    if AnsiContainsStr(Tag.params.Values['LANGUAGE'], 'JavaScript') then
      Result := AnsiDequotedStr(Tag.params.Values['src'], '"');
  end;
  Tag.params.free;
end;

function GetPartsNum(sHTML: string; var StrGrd: TStrings): boolean;
var // parse HTML and get java-script params
  Tag: _Tag; // <a href="JavaScript:selectParts('45545479')"
  S: string;
  P, n1, n2: integer;
begin
  P := 1;
  if Assigned(StrGrd) then
  begin
    Tag.params := TStringList.Create;
    StrGrd.Clear;
    while P > 0 do
    begin
      P := PosEx('<a', sHTML, P);
      GetTag(sHTML, '<', '>', P, Tag);
      S := Tag.params.Values['href'];
      if AnsiContainsStr(S, 'selectParts') then
      begin
        // S:=FloatToStr(GetNumericValue(S, PosEx('(',S)));
        // n1:=PosEx('(',S);
        // n2:=PosEx(')',S,n1+1);
        // S := MidStr(S,n1+1,n2-n1-1);
        n1 := 1;
        while not(S[n1] in ['0' .. '9']) do
          inc(n1);
        n2 := n1;
        while S[n2] in ['0' .. '9'] do
          inc(n2);
        // n1:=PosEx('"',S);
        // n2:=PosEx('"',S,n1+1);
        S := MidStr(S, n1, n2 - n1);
        if S <> '' then
          StrGrd.Add(S);
      end;

    end;
    Tag.params.free;
    Result := (StrGrd.Count > 0);
  end;
end;

function GenName: string;
var
  G: TGUID;
begin
  G.D1 := DateTimeToTimeStamp(now).Date + DateTimeToTimeStamp(now).Time;
  G.D2 := random(65534);
  G.D3 := random(65534);
  Result := IntToHex(G.D1, 8) + IntToHex(G.D2, 4) + IntToHex(G.D3, 4);
end;

function StripNonConforming(const S: string;
  const ValidChars: TCharSet): string;
var
  DestI: integer;
  SourceI: integer;
begin
  SetLength(Result, Length(S));
  DestI := 0;
  for SourceI := 1 to Length(S) do
    if S[SourceI] in ValidChars then
    begin
      inc(DestI);
      Result[DestI] := S[SourceI]
    end;
  SetLength(Result, DestI)
end;

function StripNonNumeric(const S: string): string;
begin
  Result := StripNonConforming(S, ['0' .. '9'])
end;

function ParseTable(html: string; StrGrd: TStringGrid): integer;
var
  Tag: _Tag;
  td, tr, th, table, sNum: string;
  iLine, iBlock, iPos, iColumn, iNum: integer;
  fParse, fParseNum, fTable: boolean;
begin // <<<<<<<<<<<<<<<<<<<<<<<<<<<<
  fParse := false; // ������ �������� ������� � ��������
  fTable := false; // ----v
  iNum := 0; // ���-�� ���������
  fParseNum := false; // ������ ���-�� ���������
  iBlock := 0; // ������ �������� ����� � ��������
  iColumn := 0; // ������� ������� �������
  td := 'td'; // ������
  tr := 'tr'; // ������
  th := 'th';
  table := 'table';
  Tag.params := TStringList.Create;
  iPos := 1;
  iLine := 1; // StrGrd.RowCount;
  try
    GetTag(html, '<', '>', iPos, Tag);
    while Tag.name <> '' do
    begin
      GetTag(html, '<', '>', iPos, Tag);
      Application.ProcessMessages;
      if Tag.name = 'table' then
      begin
        if pos('class="texts"', Tag.params.text) > 0 then
          fParse := true; // ���� ������� � ������� texts
      end;
      if pos('class="textn"', Tag.params.text) > 0 then
      begin
        sNum := StripNonNumeric(Tag.text);
        iNum := strtoint(sNum);
        // iNum:=StrToInt(GetNumericValue(Tag.text));
      end;
      // fParseNum := true; // ���� ������� � ������� textn � ���-��� �������
      if Tag.name = '/table' then
      begin
        fParse := false; // ��������� ������� - ������� �������
        fParseNum := false;
      end;
      if fParseNum then
      begin
        if (Tag.name = td) or (Tag.name = th) then
        begin
          if Tag.name <> '' then
          begin

            StrGrd.Cells[iColumn, iLine] := Trim(Tag.text);
          end;
        end;
      end;
      if fParse then
      begin
        if Tag.name = tr then
        begin
          inc(iLine);
          iColumn := 0;
        end;
        if (Tag.name = td) or (Tag.name = th) then
        begin
          if Tag.name <> '' then
          begin

            StrGrd.Cells[iColumn, iLine] := Trim(Tag.text);
            inc(iColumn);
            if iColumn >= StrGrd.ColCount then
              StrGrd.ColCount := iColumn;
          end;
        end;
      end;
    end;

    StrGrd.RowCount := iLine + 1;
    StrGrd.FixedRows := 1;
  except
  end;
  Result := iNum;
end;

function GetImgs(sHTML: string; var dImgs: _Imgs): integer;
var
  Tag: _Tag;
  P, i: integer;
  // gm: array of Byte;
begin
  P := 1;
  i := 0;
  Tag.params := TStringList.Create;
  while P > 0 do
  begin
    P := PosEx('<img', sHTML, P);
    if P > 0 then
    begin
      SetLength(dImgs, i + 1);
      GetTag(sHTML, '<', '>', P, Tag);
      dImgs[i].url := AnsiDequotedStr(Tag.params.Values['src'], '"');
      dImgs[i].name := GenName;
      { TODO : �������� ������ ���������� ����� �������� }
      // GetImg(dImgs[i]);
      inc(i);
    end;
  end;
  Tag.params.free;
end;

function ArrayToStr(dStr: array of Byte): string;
var
  i: integer;
begin
  Result := '';
  // if dstr = nil then
  // Exit;
  for i := low(dStr) to high(dStr) do
    Result := Result + IntToHex(dStr[i], 2);
end;

end.
