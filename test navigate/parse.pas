unit parse;

interface

uses
  Windows, System.Character, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, IdHTTP,
  Dialogs, Grids, StdCtrls, Mask, JvExMask, JvToolEdit, StrUtils, ComCtrls,
  JvgStringGrid, JvFormPlacement, JvComponentBase, JvAppStorage,
  JvAppIniStorage;

type
  _Tag = record
    name, text: string;
    params: TStrings;
    HTML: string;
  end;

type
  _ClmnTbl = record
    name, text, URL, FotoUrl, ClassName: string;
  end;

type
  _TblParts = record
    Index: integer;
    URL, URLFoto, Firm, Name, Body, Cost, Saler, Date, num, CostType: string;
  end;

type
  _img = record
    name, URL: string;
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

type
  TParseHTML = class
  private
    function GetTag(buf, tagIn, tagOut: string; var iPos: integer;
      var Tag: _Tag): boolean;
    function FirstDelimiter(const Delimiters, S: string;
      StartPos: integer): integer;
    function GetTagName(buf: string; var pos, n1, n2, l2, len: integer): string;
    function FindTag(HTML: string; var Tag: _Tag; var iPos: integer): boolean;
    function GetTable(HTML: string; var iPos, iPosEnd: integer): boolean;
    function FindTagClose(HTML: string; var Tag: _Tag;
      var iPos: integer): integer;
    function ParserScript2(var sData: TStrings; sScript: string;
      http: TIdHTTP): boolean;
    { Private declarations }
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;

  published
    procedure GetImagesFromHTML0(http: TIdHTTP; var sHTML: string;
      var imgs: TStrings; PartNum: string);
    function ParserScript(var sData: TStrings; sScript: string;
      http: TIdHTTP): boolean;
    procedure parse(FileName: string);
    function ParseTableSR2(HTML: string; StrGrd: TStringGrid): integer;
    function ParseTable(HTML: string; StrGrd: TStringGrid): integer;
    function ParseTable0(HTML: string; StrGrd: TStringGrid): integer;
    function ParseTable2(HTML: string; StrGrd: TStringGrid): integer;
    function ParseTable3(Str: TStrings; StrGrd: TStringGrid): integer;
  end;

procedure GetImagesFromHTML(http: TIdHTTP; var sHTML: string;
  var imgs: TStrings; urlStr, PartNum: string);
function ArrayToStr(dStr: array of Byte): string;
function GenName: string;
function GetTag(buf, tagIn, tagOut: string; var iPos: integer;
  var Tag: _Tag): boolean;
function FirstDelimiter(const Delimiters, S: string; StartPos: integer)
  : integer;
function GetScript(sHTML: string): string;
// function GetImg(sHTML: string): _img;
// procedure GetImg(dImgs: _imgs);
function GetTagName(buf: string; var pos, n1, n2, l2, len: integer): string;
{ function ParseTable1(HTML: string; StrGrd: TStringGrid): integer; }
// function ParseTable2(html: string; StrGrd: TStringGrid): integer;
function GetPartsNum(sHTML: string; var StrGrd: TStrings): boolean;

procedure SaveToFile(FileName, text: string);

implementation

uses HTMLParser, HTMLObjs, StrMan, UnitSend, MainUnit;

procedure SaveToFile(FileName, text: string);
begin
  // ������ ������ � ����
end;

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

function GetTag(buf, tagIn, tagOut: string; var iPos: integer;
  var Tag: _Tag): boolean;
var
  S, sk: string;
  n0, n1, n2, len, l2: integer;
begin // <<<----------
  try
    Result := false;
    S := '';
    sk := '';
    Tag.name := '';
    Tag.text := '';
    Tag.params.Clear;
    n0 := iPos;
    // s:=buf[pos];  //test
    Tag.name := GetTagName(buf, iPos, n1, n2, l2, len); // ��� ����
    if (n1 = 0) then
      Exit;

    iPos := n2;
    // --
    if buf[iPos] <> tagOut then
      while iPos < l2 do
      begin
        n1 := iPos + 1;
        iPos := FirstDelimiter(' >"', buf, n1);
        // ����� ������� ��������� ����������
        if buf[iPos] = '"' then
        begin
          iPos := FirstDelimiter('>"', buf, iPos + 1);
          // ����� ���������� ����������� ���������
          if buf[iPos] = '"' then
            inc(iPos);
        end;
        if n2 = 0 then
          iPos := len + 1;
        S := MidStr(buf, n1, iPos - n1);
        Tag.params.Append(S); // ������� ����� �������� ����
      end;
    // pos:=n2;
    // --
    Tag.HTML := MidStr(buf, n0 + 1, iPos - n0 - 1);
    sk := '';
    S := '';
    while (S = '') or (S = 'a') or (S = '/a') or (S = 'br') or (S = 'br /') or
      (S = 'b') or (S = 'ul') or (S = '/ul') or (S = 'div') or (S = '/div') or
      (S = '/b') or (S = '/td') or (S = '/tr') or (S = 'font') or
      (S = '/font') do
    // span /span , i /i , br /br
    begin
      n1 := PosEx(tagOut, buf, iPos);
      if n1 = 0 then
        break;
      inc(n1);
      n2 := PosEx(tagIn, buf, n1);
      sk := sk + MidStr(buf, n1, n2 - n1); // ������ ����� > <
      iPos := n2;
      S := GetTagName(buf, iPos, n1, n2, l2, len);
      if pos('br', S) > 0 then // ������� ������ �� ������
        sk := sk + ' ';
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

function TParseHTML.ParseTableSR2(HTML: string; StrGrd: TStringGrid): integer;
var
  ht: THTMLParser;
  iDiv, iTable, iTD, iTH, iTR, n, j, I, P, grdCol, grdRow: integer;
  htag, htag2: TTagObject;
  sTagClass, sTag, sTagText, sCellText, sText, sUrl: string;
  strHTML: TStrings;

  td, tr, th, table, sNum: string;
  iLine, iBlock, iPos, iColumn, iNum: integer;
  fParse, fParseNum, fTable: boolean;
begin // <<<<<<<<<<<<<<<<<<<<<<<<<<<<
  strHTML := TStringList.Create;
  ht := THTMLParser.Create;
  strHTML.text := HTML;
  ht.LoadFromStrings(strHTML);
  htag := ht.First;
  strHTML.free;
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

  iPos := 1;
  iLine := 1; // StrGrd.RowCount;
  try
    repeat
      sTagClass := '';
      htag.Position := ht.Current; // ��� ���������� ������ innerText
      sTag := htag.TagName;
      sTagText := htag.text;
      sText := Trim(htag.innertext);
      { DONE 5 : ����� ������ �������� ����� ����� ������ }
      if htag.Properties <> nil then
        // for P := 0 to htag.Properties.Count - 1 do
        sTagClass := AnsiDequotedStr(htag.Properties.Values['class'], '"');

      // GetTag(HTML, '<', '>', iPos, Tag);
      Application.ProcessMessages;
      if sTag = 'table' then
      begin
        if sTagClass = 'texts' then
          fParse := true; // ���� ������� � ������� texts
      end;
      if sTagClass = 'textn' then
      begin
        sNum := StripNonNumeric(sText);
        iNum := strtoint(sNum);
        // iNum:=StrToInt(GetNumericValue(Tag.text));
      end;
      // fParseNum := true; // ���� ������� � ������� textn � ���-��� �������
      if sTag = '/table' then
      begin
        fParse := false; // ��������� ������� - ������� �������
        fParseNum := false;
      end;
      if fParseNum then
      begin
        if (sTag = td) or (sTag = th) then
        begin
          if sTag <> '' then
          begin

            StrGrd.Cells[iColumn, iLine] := Trim(sText);
          end;
        end;
      end;
      if fParse then
      begin
        if sTag = tr then
        begin
          inc(iLine);
          iColumn := 0;
        end;
        if (sTag = td) or (sTag = th) then
        begin
          if sTag <> '' then
          begin

            StrGrd.Cells[iColumn, iLine] := Trim(sText);
            inc(iColumn);
            if iColumn >= StrGrd.ColCount then
              StrGrd.ColCount := iColumn;
          end;
        end;
      end;
      StrGrd.RowCount := iLine + 1;
      StrGrd.FixedRows := 1;

      htag := ht.Next;
    until htag = nil;
  except
    on e: Exception do
      FormMain.Log('Error sending message: ' + e.message, 3);
  end;
  Result := iNum;
  ht.free;
end;

procedure TParseHTML.GetImagesFromHTML0(http: TIdHTTP; var sHTML: string;
  var imgs: TStrings; PartNum: string);
var
  Tag: _Tag;
  P, I: integer;
  gm: array of Byte;
  dImgs: _Imgs;
  sm: string;
  ST: TMemoryStream;
  ls: TListItem;

  m: TMemoryStream;
  // Buff: array of byte;
  { DONE : �������� �������� ����������� }
  { TODO : �������� �������� �� ���������� ����������� }
begin
  P := 1;
  I := 0;
  sm := ExtractFilePath(Application.ExeName) + 'img\';

  // http.Request.Accept:='image/png, image/svg+xml, image/*;q=0.8, */*;q=0.5';
  // http.Request.Referer:='http://www.bl-recycle.jp/servlet/EW3SAS_WEB_PS?E_WORKID=ID1510&AD9500=40255073&AD3000=2000';
  Tag.params := TStringList.Create;
  // ������ ��� �������� �������� � �������
  while P > 0 do // ���� �� ����� ������ ��� ���� �� �������� ���� ��������
  begin
    P := PosEx('<img', sHTML, P); // ����� ��������
    ST := TMemoryStream.Create;
    try
      if P > 0 then
      begin
        SetLength(dImgs, I + 1);
        // ������� ������ ��� ����� ������
        GetTag(sHTML, '<', '>', P, Tag);
        dImgs[I].URL := AnsiDequotedStr(Tag.params.Values['src'], '"');
        if not AnsiStartsText('http', dImgs[I].URL) then
        begin
          dImgs[I].URL := 'http://' + http.Request.Host + dImgs[I].URL;
          { TODO 4 : ���������!! }
        end; // 'http://' + http.Request.Host +
        // ������ �� ��������
        // dImgs[i].name  := Copy(dImgs[i].url,  LastDelimiter('/', dImgs[i].url)+ 1, MaxInt);
        dImgs[I].name := sm + GenName + '.gif'; // ����� ��� �������� (ID)
        { TODO : �������� ������ ���������� ����� �������� }
        imgs.Add(dImgs[I].name);
        // ������ ����� ������ �������� ��� �������� � �������
        sHTML := StringReplace(sHTML, dImgs[I].URL, dImgs[I].name,
          [rfIgnoreCase]);
        // ������ URL �� ���� � ����� ��������
        ST.Clear;
        try
          { TODO 666: ��������� ���������!! ������ ������� ��� ��������� ���������� }
          GetImg(dImgs[I].URL, ST); // �������� �������� � ������
          // http.Get(dImgs[i].URL, ST); // �������� �������� � ������
        except
          on e: Exception do
            FormMain.Log('Error sending message: ' + e.message, 3);
          // on e: EIdHTTPProtocolException do FormMain.Log('������: ' + e.Message + '. URL:' + dImgs[i].URL, 3);
        end;
        SetLength(dImgs[I].img, ST.Size);
        // �������� ������ � ������� ��� ��������
        ST.Position := 0;
        ST.Read(dImgs[I].img[0], ST.Size);
        // �������� � ������ �� ������
        inc(I);
      end;
    finally
      ST.free;
    end;
  end;

  for I := Low(dImgs) to High(dImgs) do
  begin
    { ls := ListView2.Items.Add;
      ls.Caption := PartNum;
      ls.SubItems.Add(dImgs[i].Name);
      ls.SubItems.Add(dImgs[i].URL);
      // setlength(sm,Length(dImgs[i].img));
      ls.SubItems.Add(ArrayToStr(dImgs[i].img)); }

    m := TMemoryStream.Create;
    try
      { DONE 3 :  ������ �������� ����������� ��������!
        � ������ �������� ����������!!! }

      { TODO 3 : ���������, ��� �������� ������������� ������� � �� ����������� }
      m.write(dImgs[I].img[0], Length(dImgs[I].img));
      if not DirectoryExists(sm) then
        ForceDirectories(sm);
      if not FileExists(dImgs[I].name) then
        m.SaveToFile(dImgs[I].name);
    finally
      m.free;
    end;

  end;

  Tag.params.free;
end;

procedure GetImagesFromHTML(http: TIdHTTP; var sHTML: string;
  var imgs: TStrings; urlStr, PartNum: string);
var
  Tag: _Tag;
  P, I, r: integer;
  gm: array of Byte;
  dImgs: _Imgs;
  sm, S, extimg: string;
  ST: TMemoryStream;
  ls: TListItem;
  m: TMemoryStream;
begin
  P := 1; // ���������� ������� � ������
  I := 0; // ������ ������� ��������
  sm := ExtractFilePath(Application.ExeName) + 'img\';
  Tag.params := TStringList.Create;
  ST := TMemoryStream.Create; // ������ ��� �������� �������� � �������
  { TODO : ������� ������� �� ��������� ����� }
  // --- ������� ����� �� ������ ---
  // <link rel="stylesheet" href="/psnet/com/tsubasa-adc.css">
  while P > 0 do // ���� �� ����� ������ ��� ���� �� �������� ���� ��������
  begin
    P := PosEx('<link', sHTML, P);
    if P > 0 then
    begin
      GetTag(sHTML, '<', '>', P, Tag);
      if Tag.params <> nil then
      begin
        S := Tag.params.Values['href'];
        if AnsiContainsText(S, '.css') then
        begin
          r := pos('http', S);
          if r = 0 then
            S := urlStr + AnsiDequotedStr(S, '"');
          S := GetHTTP(http, S);
          sHTML := StringReplace(sHTML, '<' + Tag.HTML + '>',
            '<style>' + S + '</style>', [rfIgnoreCase]);
        end;
      end;
    end;
  end;

  // -----
  // http.Request.Accept:='image/png, image/svg+xml, image/*;q=0.8, */*;q=0.5';
  // http.Request.Referer:='http://www.bl-recycle.jp/servlet/EW3SAS_WEB_PS?E_WORKID=ID1510&AD9500=40255073&AD3000=2000';
  P := 1; { TODO 111: ���������! ������ ��� ��� ����� ��������� ������ ����� � href � <a }
  while P > 0 do // ���� �� ����� ������ ��� ���� �� �������� ���� ��������
  begin
    P := PosEx('<a', sHTML, P); // ����� �������� � �������
    if P > 0 then
    begin
      GetTag(sHTML, '<', '>', P, Tag);
      S := Tag.params.Values['href'];
      if AnsiContainsText(S, 'JavaScript') then
      begin
        r := pos('http', S);
        S := MidStr(S, r, FirstDelimiter('''")', S, r) - r);
        // <a href="JavaScript:photoViewXX('http://rf01.recycle7.com/317601/265999/317601265999010103.jpg')">}
        SetLength(dImgs, I + 1); // ������� ������ ��� ����� ������
        // GetTag(sHTML, '<', '>', p, Tag);
        dImgs[I].URL := S; // AnsiDequotedStr(Tag.params.Values['src'], '"');
        // S := dImgs[i].URL;
        r := Length(S);
        extimg := '';
        repeat
          extimg := S[r] + extimg;
          dec(r);
        until S[r] = '.';
        // ������ �� ��������
        // dImgs[i].name  := Copy(dImgs[i].url,  LastDelimiter('/', dImgs[i].url)+ 1, MaxInt);
        dImgs[I].name := sm + GenName() + '.' + extimg;
        // ����� ��� �������� (ID)
        imgs.Add(dImgs[I].name);
        // ������ ����� ������ �������� ��� �������� � �������
        // sHTML :=StringReplace(sHTML,Tag.params.Values['href'],S,  [rfIgnoreCase]);
        sHTML := StringReplace(sHTML, Tag.params.Values['href'],
          '"' + dImgs[I].name + '"', [rfIgnoreCase]);
        // ������ URL �� ���� � ����� ��������
        { TODO : �������� ������ ���������� ����� �������� }
        ST.Clear; { TODO : ������ ��� ������ }
        { TODO : ������� ������� ��� ��������� ���������� }
        // GetHTTP(http, dImgs[i].URL, st); // �������� �������� � ������
        GetImg(dImgs[I].URL, ST); // �������� �������� � ������
        { TODO 665: ��������� GetImg }
        // �������� ������ � ������� ��� ��������
        ST.Position := 0;
        if ST.Size > 0 then
        begin
          SetLength(dImgs[I].img, ST.Size);
          ST.Read(dImgs[I].img[0], ST.Size); // �������� � ������ �� ������
          inc(I);
        end;
      end;
    end;
  end;
  P := 1;
  while P > 0 do // ���� �� ����� ������ ��� ���� �� �������� ���� ��������
  begin
    P := PosEx('<img', sHTML, P); // ����� ��������
    if P > 0 then
    begin
      SetLength(dImgs, I + 1); // ������� ������ ��� ����� ������
      GetTag(sHTML, '<', '>', P, Tag);
      dImgs[I].URL := AnsiDequotedStr(Tag.params.Values['src'], '"');
      S := dImgs[I].URL;
      r := Length(S);
      extimg := '';
      repeat
        extimg := S[r] + extimg;
        dec(r);
      until S[r] = '.';
      // ������ �� ��������
      // dImgs[i].name  := Copy(dImgs[i].url,  LastDelimiter('/', dImgs[i].url)+ 1, MaxInt);
      dImgs[I].name := sm + GenName + '.' + extimg; // ����� ��� �������� (ID)
      imgs.Add(dImgs[I].name);
      // ������ ����� ������ �������� ��� �������� � �������
      sHTML := StringReplace(sHTML, dImgs[I].URL, dImgs[I].name, [rfIgnoreCase]
        ); // ������ URL �� ���� � ����� ��������
      { DONE : �������� ������ ���������� ����� �������� }
      ST.Clear; { TODO : ������ ��� ������ }
      { TODO : ������� ������� ��� ��������� ���������� }
      if pos('http', dImgs[I].URL) = 0 then
        dImgs[I].URL := urlStr + dImgs[I].URL;
      // GetHTTP(http, dImgs[i].URL, st); // �������� �������� � ������
      GetImg(dImgs[I].URL, ST); // �������� �������� � ������
      { TODO 665: ��������� GetImg }
      // �������� ������ � ������� ��� ��������
      ST.Position := 0;
      if ST.Size > 0 then
      begin
        SetLength(dImgs[I].img, ST.Size);
        // �������� ������ � ������� ��� ��������
        ST.Read(dImgs[I].img[0], ST.Size); // �������� � ������ �� ������
        inc(I);
      end;
    end;
  end;
  ST.free;

  for I := Low(dImgs) to High(dImgs) do
  begin
    { ls := ListView2.Items.Add;
      ls.Caption := PartNum;
      ls.SubItems.Add(dImgs[i].name);
      ls.SubItems.Add(dImgs[i].URL);
      // setlength(sm,Length(dImgs[i].img));
      ls.SubItems.Add(ArrayToStr(dImgs[i].img)); }

    m := TMemoryStream.Create;
    try
      { DONE 3 :
        ������ �������� ����������� ��������!
        � ������ �������� ����������!!! }
      { TODO 3 : ���������, ��� �������� ������������� ������� � �� ����������� }
      m.write(dImgs[I].img[0], Length(dImgs[I].img));
      { TODO 22: Range check error!!! }
      // if not DirectoryExists(s)  then
      ForceDirectories(sm);
      if not FileExists(dImgs[I].name) then
        m.SaveToFile(dImgs[I].name);
    finally
      m.free;
    end;
  end;
  Tag.params.free;
end;

function TParseHTML.ParserScript(var sData: TStrings; sScript: string;
  http: TIdHTTP): boolean; (*
  ������ ������� - ���������� ������ ��������� �� �������� ������
*)
var
  StrPage, urlStr, S: String;
  n1, P: integer;
begin
  Result := false;
  try
    if sScript <> '' then
    begin
      // Log('������ ���-������');
      { TODO : ������� ������� ��� ��������� ���������� }
      StrPage := GetHTTP(http, 'http://www.bl-recycle.jp' + sScript);
      P := pos('urlStr', StrPage);
      // Log('���� ���������� �� �������');
      if P > 0 then
      begin // ������ ������ � ����������� �� �����
        urlStr := MidStr(StrPage, P, PosEx(';', StrPage, P + 1) - P + 1);
        P := 0;
        // urlStr = '/servlet/EW3SAS_WEB_PS?E_WORKID=ID1510&AD9500=' + target + '&AD3000=' + document.sendForm.AD3000.value;
        sData.Clear;
        while P < Length(urlStr) do
        begin
          n1 := P + 1;
          // p := FirstDelimiter('=+;', urlStr, n1);
          // Log('����� ������� ����������� ����������');
          while urlStr[n1] = ' ' do
            inc(n1);
          if (urlStr[n1] = '"') or (urlStr[n1] = '''') then
          // ���������� - �������� �� ��������� � �������...
          begin
            inc(n1);
            P := FirstDelimiter('"''', urlStr, n1);
            // Log('����� ���������� ����������� ���������');
            /// if (p>0) then
            /// inc(p);
          end
          else
          begin
            P := FirstDelimiter('=+;', urlStr, n1);
            // ������� ��� - ���� ����������� � � ������..
            if P = 0 then
              P := Length(urlStr);
            // inc(p);
          end;
          S := Trim(MidStr(urlStr, n1, P - n1));
          if S <> '' then
          begin
            sData.Append(S);
            // Log('�������� ����� �������� ����:' + S);
          end;
        end;
      end;
      Result := true;
    end;
  finally
  end;
end;

function TParseHTML.ParserScript2(var sData: TStrings; sScript: string;
  http: TIdHTTP): boolean; (*
  ������ ������� - ���������� ������ ��������� �� �������� ������
*)
var
  StrPage, urlStr, S: String;
  n1, P: integer;
begin
  Result := false;
  try
    if sScript <> '' then
    begin
      Log('������ ���-������');
      { DONE : ������� ������� ��� ��������� ���������� }
      StrPage := GetHTTP(http, 'http://www.bl-recycle.jp' + sScript);
      P := pos('urlStr', StrPage);
      Log('���� ���������� �� �������');
      if P > 0 then
      begin // ������ ������ � ����������� �� �����
        urlStr := MidStr(StrPage, P, PosEx(';', StrPage, P + 1) - P + 1);
        P := 0;
        // urlStr = '/servlet/EW3SAS_WEB_PS?E_WORKID=ID1510&AD9500=' + target + '&AD3000=' + document.sendForm.AD3000.value;
        sData.Clear;
        while P < Length(urlStr) do
        begin
          n1 := P + 1;
          // p := FirstDelimiter('=+;', urlStr, n1);
          Log('����� ������� ����������� ����������');
          while urlStr[n1] = ' ' do
            inc(n1);
          if (urlStr[n1] = '"') or (urlStr[n1] = '''') then
          // ���������� - �������� �� ��������� � �������...
          begin
            inc(n1);
            P := FirstDelimiter('"''', urlStr, n1);
            Log('����� ���������� ����������� ���������');
            /// if (p>0) then
            /// inc(p);
          end
          else
          begin
            P := FirstDelimiter('=+;', urlStr, n1);
            // ������� ��� - ���� ����������� � � ������..
            if P = 0 then
              P := Length(urlStr);
            // inc(p);
          end;
          S := Trim(MidStr(urlStr, n1, P - n1));
          if S <> '' then
          begin
            sData.Append(S);
            Log('�������� ����� �������� ����:' + S);
          end;
        end;
      end;
      Result := true;
    end;
  finally
  end;
end;

function TParseHTML.ParseTable0(HTML: string; StrGrd: TStringGrid): integer;
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
    GetTag(HTML, '<', '>', iPos, Tag);
    while Tag.name <> '' do
    begin
      GetTag(HTML, '<', '>', iPos, Tag);
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
    on e: Exception do
      FormMain.Log('Error sending message: ' + e.message, 3);
  end;
  Result := iNum;
end;

function TParseHTML.ParseTable2(HTML: string; StrGrd: TStringGrid): integer;
var
  Tag: _Tag;
  td, tr, th, table, sNum: string;
  iLine, iBlock, iPos, iColumn, iNum: integer;
  fParse, fParseNum, fTable: boolean;
  sHTTP: string;
begin
  sHTTP := 'http://parts.japancar.ru';
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
    GetTag(HTML, '<', '>', iPos, Tag);
    while Tag.name <> '' do
    begin
      GetTag(HTML, '<', '>', iPos, Tag);
      Application.ProcessMessages;
      if Tag.name = 'table' then
      begin
        if pos('class="main-list"', Tag.params.text) > 0 then
          fParse := true; // ���� ������� � ������� texts
      end;
      if pos('class="comment"', Tag.params.text) > 0 then
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
            if Tag.name = 'a' then
            begin
              StrGrd.Cells[iColumn, iLine] := sHTTP + StrGrd.Cells
                [iColumn, iLine]; { TODO 5 : !!! ���������!!! }
            end;
          end;
        end;
      end;
      if fParse then
      begin
        if (Tag.name = tr) or (Tag.name = 'banner') then
        begin
          inc(iLine);
          iColumn := 0;
        end;
        if (Tag.name = td) or (Tag.name = th) then
        begin
          if Tag.name <> '' then
          begin
            if Tag.name <> 'banner' then
            begin
              StrGrd.Cells[iColumn, iLine] := Trim(Tag.text);
              inc(iColumn);
              if iColumn >= StrGrd.ColCount then
                StrGrd.ColCount := iColumn;
            end;
          end;
        end;
      end;
    end;

    StrGrd.RowCount := iLine + 1;
    StrGrd.FixedRows := 1;
  except
    on e: Exception do
      FormMain.Log('Error sending message: ' + e.message, 3);
  end;
  Result := iNum;
end;

function TParseHTML.ParseTable3(Str: TStrings; StrGrd: TStringGrid): integer;
var
  ht: THTMLParser;
  iDiv, iTable, iTD, iTH, iTR, iNum, n, j, I, P, grdCol, grdRow: integer;
  htag, htag2: TTagObject;
  sNum, sTagClass, sTag, sTagText, sCellText, sText, sUrl: string;
  {
    TagName = ��� ���� ��� �������
    Text  =  ���� ��� � ��������� � �����������
    !���� ��� ����������������( />) �� � ���������� �������� ������ /
    Position = ??������� ���� � ���������??
    Current  =  ������� ������� �������� ���� � ���������  (���������������� ��� �� ��� ����)
  }
begin
  ht := THTMLParser.Create;
  ht.LoadFromStrings(Str);
  htag := ht.First;
  Result := 0;
  StrGrd.FixedRows := 0;
  StrGrd.Cols[0].Clear;
  StrGrd.Rows[0].Clear;
  StrGrd.ColCount := 1;
  StrGrd.RowCount := 1;
  grdRow := 1; // ���������� � ������ ������ �������
  grdCol := 0;
  iDiv := 0;
  iTD := 0;
  iTR := 0;
  iTH := 0;
  iTable := 0;
  sCellText := '';
  repeat
    sTagClass := '';
    htag.Position := ht.Current; // ��� ���������� ������ innerText
    sTag := htag.TagName;
    sTagText := htag.text;
    sText := Trim(htag.innertext);
    { DONE 5 : ����� ������ �������� ����� ����� ������ }
    if htag.Properties <> nil then
      // for P := 0 to htag.Properties.Count - 1 do
      sTagClass := AnsiDequotedStr(htag.Properties.Values['class'], '"');
    if sTag = '/div' then
      if iDiv > 0 then
        dec(iDiv);
    if sTag = 'div' then
      inc(iDiv);
    if iDiv > 0 then
    begin
      if sTagClass = 'pagination' then // ���� ������ �� ���� �������
      begin
        { DONE : ������ ������ �� �������� }
        while sTag <> '/div' do // ������ �������
        begin
          sTagText := htag.text;
          sText := Trim(htag.innertext);
          { DONE 5 : ����� ������ �������� ����� ����� ������ }
          if (sTag = 'a') then
            if pos('���������', sText) > 0 then
              if htag.Properties <> nil then
              begin
                sUrl := AnsiDequotedStr(htag.Properties.Values['href'], '''');
                // ������ �� ��������
                sUrl := AnsiDequotedStr(sUrl, '"'); // ������ �� ��������
                StrGrd.Cells[1, 0] := sUrl;
              end;
          htag := ht.Next;
          sTag := htag.TagName;
          htag.Position := ht.Current; // ��� ���������� ������ innerText
        end;
      end;
      if sTagClass = 'count' then
      begin
        sText := Trim(htag.innertext);
        if pos('�������', sText) > 0 then
        begin
          sNum := StripNonNumeric(sText);
          iNum := strtoint(sNum); // ���-�� ��������� �������
          StrGrd.Cells[0, 0] := sNum;
        end;
      end;
    end;
    if sTag = '/table' then
      if iTable > 0 then
        dec(iTable);
    if sTag = 'table' then
      if sTagClass = 'main-list' then
        inc(iTable);
    if iTable > 0 then
    begin
      if (sTag = 'a') then
        if (grdCol = 0) and (iTD > 0) then
          if htag.Properties <> nil then
          begin
            sUrl := AnsiDequotedStr(htag.Properties.Values['href'], '''');
            // ������ �� ��������
            sUrl := AnsiDequotedStr(sUrl, '"'); // ������ �� ��������
          end;
      if (grdCol = 0) and (grdRow > 1) then
        sCellText := sUrl;
      if (sTag = '/th') or (sTag = '/td') then
      begin
        if sTag = '/th' then
          dec(iTH);
        if sTag = '/td' then
          dec(iTD);
        StrGrd.Cells[grdCol, grdRow] := Trim(sCellText + ' ' + sText);
        inc(grdCol); // �������
        if StrGrd.ColCount < grdCol then
          StrGrd.ColCount := grdCol + 1;
        sCellText := '';
      end;
      if (sTag = 'th') or (sTag = 'td') then // ��������� �������
      begin
        if sTag = 'th' then
          inc(iTH);
        if sTag = 'td' then
          inc(iTD);
        sCellText := sText;
      end;
      if sTag = '/tr' then
      begin
        dec(iTR);
        inc(grdRow); // �������
        if StrGrd.RowCount < grdRow then
          StrGrd.RowCount := grdRow + 1;
        grdCol := 0;
        sUrl := '';
      end;
      if sTag = 'tr' then
        inc(iTR); // ����� ������ �������
    end;
    htag := ht.Next;
    // sTag := htag.TagName;
    // htag.Position := ht.Current; // ��� ���������� ������ innerText
  until htag = nil;
  ht.free;
  Result := grdRow - 2;
end;

function GetImgs(sHTML: string; var dImgs: _Imgs): integer;
var
  Tag: _Tag;
  P, I: integer;
  // gm: array of Byte;
begin
  P := 1;
  I := 0;
  Tag.params := TStringList.Create;
  while P > 0 do
  begin
    P := PosEx('<img', sHTML, P);
    if P > 0 then
    begin
      SetLength(dImgs, I + 1);
      GetTag(sHTML, '<', '>', P, Tag);
      dImgs[I].URL := AnsiDequotedStr(Tag.params.Values['src'], '"');
      dImgs[I].name := GenName;
      { TODO : �������� ������ ���������� ����� �������� }
      // GetImg(dImgs[i]);
      inc(I);
    end;
  end;
  Tag.params.free;
end;

function ArrayToStr(dStr: array of Byte): string;
var
  I: integer;
begin
  Result := '';
  // if dstr = nil then
  // Exit;
  for I := low(dStr) to high(dStr) do
    Result := Result + IntToHex(dStr[I], 2);
end;


// ==========================================

procedure TParseHTML.parse(FileName: string);
var
  buf: String;
  Str: TStrings;
  StringGrd: TStringGrid;

begin
  { if Button1.Tag=1 then
    begin
    Button1.Caption:='Parse';
    Button1.Tag:=0; //stop
    Exit;
    end;
    Button1.Tag:=1; //start
    Button1.Caption:='Stop';
  }
  Str := TStringList.Create;
  Str.LoadFromFile(FileName);
  buf := Str.text;
  Str.free;
  StringGrd := TStringGrid.Create(nil);

  // StrGrd.Assign(ParseTable(Buf));
  ParseTable2(buf, StringGrd);
  /// ...,...  form1.StrGrd0.Assign(StringGrd);
  // ParseTable(buf, StrGrd);
  {
    Button1.Caption:='Parse';
    Button1.Tag:=0; //stop
  }

  StringGrd.free;
end;

function TParseHTML.GetTagName(buf: string;
  var pos, n1, n2, l2, len: integer): string;
// var

// pos=�������� ������� � ������
// n1 = ������ �����������(�����) ����
// n2 = ����� ����� ����
// l2 = ����� ����������� ����
// len = ����� ����������� ����

// n1,n2,len,l2: integer;
begin
  n1 := PosEx('<', buf, pos);
  if n1 = 0 then
    Abort;
  inc(n1);
  n2 := PosEx('>', buf, n1);
  // if buf[n2-1]='/' then
  l2 := n2;
  len := n2 - n1;
  n2 := FirstDelimiter(' >', buf, n1); // first word after <
  Result := MidStr(buf, n1, n2 - n1);
end;

function TParseHTML.FirstDelimiter(const Delimiters, S: string;
  StartPos: integer): integer;
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

function TParseHTML.GetTag(buf, tagIn, tagOut: string; var iPos: integer;
  var Tag: _Tag): boolean;
{ ������� �������� ���, ��������� ���� � ��� �����, ��������� ��������� ��������� ���� �� ������ ����� ����.
  ��� �� ������ ���� ����� ������ ���� � ��� ��������� � ����� �� ������ � �� ����� .
}
var
  S, sk: string;
  iCountTag, iStartTag, n1, n2, len, l2: integer;
begin // <<<----------
  try
    Result := false;
    S := '';
    sk := '';
    iCountTag := 0; // ���-�� ��������� ����� �� �����
    iStartTag := iPos; // ������ ����
    Tag.name := '';
    Tag.text := '';
    Tag.params.Clear;
    // s:=buf[pos];  //test
    Tag.name := GetTagName(buf, iPos, n1, n2, l2, len); // ��� ����
    if (n1 = 0) then
      Exit;

    iPos := n2;
    // --
    if buf[iPos] <> '>' then
      while iPos < l2 do // ������ ��������� �� ����� ������ ����
      begin
        n1 := iPos + 1;
        iPos := FirstDelimiter(' >"', buf, n1);
        // ����� ������� ����������� ����������
        if buf[iPos] = '"' then
        begin
          iPos := FirstDelimiter('>"', buf, iPos + 1);
          // ����� ���������� ����������� ���������
          if buf[iPos] = '"' then
            inc(iPos);
        end;
        if n2 = 0 then
          iPos := len + 1;
        S := MidStr(buf, n1, iPos - n1);
        Tag.params.Append(S); // �������� ����� �������� ����
      end;
    // pos:=n2;
    // --
    sk := '';
    S := ''; // ������ ����� ������ ���� ����� ��������� �����
    while (S = '') or (S = 'a') or (S = '/a') or (S = 'br') or (S = 'br /') or
      (S = 'b') or (S = 'ul') or (S = '/ul') or (S = 'div') or (S = '/div') or
      (S = '/b') or (S = '/td') or (S = '/tr') or (S = 'font') or (S = '/font')
      or (S = 'span') or (S = '/span') do
    // span /span , i /i , br /br
    begin
      n1 := PosEx('>', buf, iPos);
      /// ���� ����������� ����
      if n1 = 0 then // �������� > �����
        break;
      inc(n1);
      n2 := PosEx('<', buf, iPos);
      sk := sk + MidStr(buf, n1, n2 - n1); // ������ ����� > <
      iPos := n2;
      S := GetTagName(buf, iPos, n1, n2, l2, len);
      if buf[l2 - 1] = '/' then // ��� ������������� ����� ��� ������������ ����
        break; // !!! { TODO : �������������!!! ������ ������� ����� }
      if S = Tag.name then
      begin
        inc(iCountTag); // ��������� ��������� ����������� ��� = ����� ���
        S := '';
      end;
      if S = '/' + Tag.name then
      begin
        if iCountTag = 0 then
          break; // ������ ����������� ��� = �����
        dec(iCountTag);
      end;
      if pos('br', S) > 0 then // ������� ������ �� ������
        sk := sk + ' ';
      if pos('span', S) > 0 then // ������� ������ �� ������
        sk := sk + ' ';
    end;
    Tag.text := sk;
    Tag.HTML := MidStr(buf, iStartTag, l2 - iStartTag + 1);
    // �������� ��� ���������� ���� � ��� ������
    Result := true;
  except
    on e: Exception do
      FormMain.Log('Error sending message: ' + e.message, 3);
  end;
end;

function TParseHTML.ParseTable(HTML: string; StrGrd: TStringGrid): integer;
var
  Tag: _Tag;

  td, tr, table: string;
  Index, iPos, posEnd: integer;
begin // <<<<<<<<<<<<<<<<<<<<<<<<<<<<

  td := 'td'; // ������
  tr := 'tr'; // ������
  table := 'table';
  Tag.params := TStringList.Create;
  iPos := 1;
  index := 0;
  StrGrd.FixedRows := 0;
  StrGrd.Cols[0].Clear;
  StrGrd.Rows[0].Clear;
  StrGrd.ColCount := 1;
  StrGrd.RowCount := 1;
  try
    Tag.name := 'table';
    Tag.params.Add('class="main-list"'); // �������
    if FindTag(HTML, Tag, iPos) then
    begin
      posEnd := FindTagClose(HTML, Tag, iPos); // ����� ������������ ����
      Tag.name := 'tr';
      Tag.params.Values['class'] := '"  "';
      if FindTag(HTML, Tag, iPos) then // ������ ������
      begin
        GetTable(HTML, iPos, posEnd);
        // ����� ��������� ������ � ������ � �� ����� �������
      end;
    end;
  finally

  end;
end;

function TParseHTML.GetTable(HTML: string; var iPos, iPosEnd: integer): boolean;
var
  row, clm: integer;
  Tag: _Tag;
  TagName, TagClass: string;
  NewLine: boolean;
begin
  Tag.params := TStringList.Create;
  Result := false;
  row := 0;
  clm := 0;
  while (GetTag(HTML, '<', '>', iPos, Tag)) and (iPos < iPosEnd) do
  begin
    if Tag.name = 'tr' then
      if Tag.params.Values['class'] = '"  "' then
      begin
        inc(row);
        clm := 0;
        // Form1.StrGrd0.RowCount := row + 1;
        { DONE : ������ �������� �� ����� ������ � ����� , �������� ���������� �������. ����� ���. ������ � html ������� }
      end;
    if Tag.name = 'td' then
    begin
      // Form1.StrGrd0.Cells[clm, row] := Trim(Tag.text);
      inc(clm);
      // Form1.StrGrd0.ColCount := clm + 1;
    end;
  end;
end;

function TParseHTML.FindTag(HTML: string; var Tag: _Tag;
  var iPos: integer): boolean;
var
  // Tag: _Tag;
  TagName, TagClass: string;
begin
  TagName := Tag.name;
  TagClass := Tag.params.Values['class'];
  Result := false;
  while GetTag(HTML, '<', '>', iPos, Tag) do
  begin
    if Tag.name = TagName then
      if Tag.params.Values['class'] = TagClass then
      begin
        Result := true;
        Exit;
      end;
  end;
end;

function TParseHTML.FindTagClose(HTML: string; var Tag: _Tag;
  var iPos: integer): integer;
var
  // Tag: _Tag;
  TagName, TagClass: string;
begin
  TagName := Tag.name;
  TagClass := Tag.params.Values['class'];
  Result := -1;
  while GetTag(HTML, '<' + Tag.name, '/' + Tag.name + '>', iPos, Tag) do
  begin
    if Tag.name = TagName then { TODO : ���������! }
      if Tag.params.Values['class'] = TagClass then
      begin
        Result := iPos;
        Exit;
      end;
  end;
end;

{ function ParseTable1(HTML: string; StrGrd: TStringGrid): integer;
  var
  Tag: _Tag;
  td, tr, table: string;
  Index, pos: integer;
  begin // <<<<<<<<<<<<<<<<<<<<<<<<<<<<
  td := 'td'; // ������
  tr := 'tr'; // ������
  table := 'table';
  Tag.params := TStringList.Create;
  pos := 1;
  index := 0;
  StrGrd.FixedRows := 0;
  StrGrd.Cols[0].Clear;
  StrGrd.Rows[0].Clear;
  StrGrd.ColCount := 4;
  StrGrd.RowCount := 0;
  try
  while Tag.name <> '' do
  begin
  if Tag.name = td then      { TODO : ������� ������!!! }
{ if Tag.params.Values['class'] = 'N' then StrGrd.Cells[0, index] := Tag.text;
  if Tag.params.Values['class'] = 'N3' then
  begin
  StrGrd.Cells[1, index] := Tag.text;
  inc(index);
  end;
  end;
  Result := index; // ���-�� ����� !!!
  except
  end;

  end;
}

constructor TParseHTML.Create;
begin
  inherited Create;
end;

destructor TParseHTML.Destroy;
begin
  inherited Destroy;
end;

end.
