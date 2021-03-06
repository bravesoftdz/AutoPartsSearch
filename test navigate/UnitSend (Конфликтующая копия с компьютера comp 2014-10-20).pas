unit UnitSend;

interface

uses SysUtils, System.IOUtils,   IdUserPassProvider, IdExplicitTLSClientServerBase,  httpsend,
  IdMessageClient, IdSMTPBase, IdSMTP, IdSASLPlain, IdSASL, IdSASLUserPass,   IdSSL, IdSSLOpenSSL  ,
  IdSASLLogin, IdMessage, IdLogBase, IdAntiFreeze, IdAttachment,
  IdAttachmentFile, IdText, IdLogDebug, IdCoder, IdCoderQuotedPrintable,
  IdIntercept, IdHTTP, StrUtils,  Mshtml, SHDocVw,    System.Variants,
     ActiveX,Windows, Winapi.Messages,  Vcl.Forms,  IdCharsets,
  Classes;

type
  dt = string; // ������ ����������� ��� ���������� ������� ����!
  // �������� �������, �� ��������! :)

procedure Log(Txt: string; debuglevel: Integer = 0; ToConsole: boolean = true);
function SendMail(idMsg: TIdMessage):boolean;
procedure SendMail1(idMsg: TIdMessage);
function SendMail2(sFrom, sTo, sHost, sPort, sSubject, sLogin, sPass,
  sBody: string; slAttachments: tstrings): boolean;
// function sSendMail(aHost: String): Boolean;
//procedure TestMail;
procedure mIdMessageInitializeISO(var VHeaderEncoding: Char;
  var VCharSet: string);

// procedure SendAtach;
// procedure SendHTMLMail;
procedure AttacheFiles(var mIdMessage: TIdMessage; BodyHTML: string;
  sAttacheFilesPath: tstrings; sCharset: string);
function GetHTTP(idHTTPvar: TIdHTTP; sURL: string): string; overload;
procedure GetHTTP(idHTTPvar: TIdHTTP; sURL: string;
  AResponseContent: TStream); overload;
function PostHTTP(sMethod: string; idHTTPvar: TIdHTTP; sURL: string; PostData: tstrings): string;

//procedure SendData(sListData: tstrings);
function ValidData: boolean;
 procedure TextToWebBrowser(Text: string; var WB: tWebBrowser);

var
Cookies: string;

implementation


uses MainUnit, settings;

function ProxyHttpPostURL(const URL, URLData: string;
  const Data: TStream): boolean;
var
  sgHTTP: THTTPSend;
begin
  sgHTTP := THTTPSend.Create;
  try
    sgHTTP.Document.Write(Pointer(URLData)^, Length(URLData));
    sgHTTP.MimeType := 'application/x-www-form-urlencoded';
    Result := sgHTTP.HTTPMethod('POST', URL);
    Data.CopyFrom(sgHTTP.Document, 0);
  finally
    sgHTTP.Free;
  end;
end;

procedure Log(Txt: string; debuglevel: Integer = 0; ToConsole: boolean = true);
begin
  // MainTest.Log(Txt, debuglevel, ToConsole);
  FormMain.Log(Txt, debuglevel);
end;

function SendMail(idMsg: TIdMessage): boolean;
{ DONE : Sendmail ��������. �������� �������� �������� �� ������� � ���������� �������� �������� }

 // EdMailLogin: string = 'artem-xp@yandex.ru';
 ///. EdMailPass: string = 'prepare5swine';
var
  IdSMTP: TIdSMTP;
  IdMessage: TIdMessage;
  IdUserPassProvider: TIdUserPassProvider;
  IdSASL: TIdSASLLogin;
 // IdAntiFreeze: TidAntiFreeze;
begin
result:=false;
SendMail2(idMsg.From.Text,idMsg.Recipients.EMailAddresses,FormSettings.EdSMTPHost.Text,FormSettings.edSMTPport.Text,idMsg.Subject,FormSettings.EdMailLogin.Text,FormSettings.EdMailPass.Text,idMsg.Body.Text,nil);
Exit;
  IdSMTP := TIdSMTP.Create(nil);
  // IdMessage := TIdMessage.Create(nil);
  IdUserPassProvider := TIdUserPassProvider.Create(nil);
  IdSASL := TIdSASLLogin.Create(nil);

  Log('Attempting to send mail');

  with IdSMTP do
  begin
    // Caption := 'Trying to sendmail via: ' + aHost;
    Host := FormSettings.EdSMTPHost.Text;
    Log('Trying to sendmail via: ' + Host);
    AuthType := satDefault;
    Port := StrToInt(FormSettings.edSMTPport.Text);
    Username := FormSettings.EdMailLogin.Text;
    Password := FormSettings.EdMailPass.Text;

    IdUserPassProvider.Username := Username;
    IdUserPassProvider.Password := Password;
    IdSASL.UserPassProvider := IdUserPassProvider;

    try
      // IdEncoderQuotedPrintable1.Encode(IdMessage1.);
      Log('Attempting connect');
      Connect;
      Log('Successful connect ... sending message');
      Send(idMsg);
      Log('Attempting disconnect');
      Disconnect;
      Log('Successful disconnect');
      result:=true;
      Log('Messege successfule send!');
    except
      on E: Exception do
      begin
      result:=false;
        if connected then
          try
            Disconnect;
          except
          end;
        Log('Error sending message!' + E.Message);

      end;
    end;
  end;

  IdUserPassProvider.Free;
  IdSMTP.Free;
  IdSASL.Free;
  // IdMessage.free;
end;


 {
procedure TestMail;
var
  IdMessage: TIdMessage;
  EdSender, EdRecipients: string;
begin
  IdMessage := TIdMessage.Create(nil);
  with IdMessage do
  begin
    Log('Assigning mail test message properties');
    From.Text := 'Delphi Indy Client <' + 'artemxp@yandex.ru' + '>';
    Sender.Text := 'artemxp@yandex.ru';
    Recipients.EMailAddresses := 'artemxp@gmail.com';
    Subject := '����� ������������� �� ���������� (TEST MESSAGE)';
    ContentType := 'text/plain';
    CharSet := 'Windows-1251';
    ContentTransferEncoding := '8bit';
    IsEncoded := true;
    Body.Text := '����� ������������� �� ���������� ' + #$D + #$A +
      'TEST MESSAGE!'
  end;
  Log('SendMail test.');
  SendMail(IdMessage);
  // ShowMessage('�������� ������ ����������.');
  IdMessage.Free;
end;
       }
procedure AttacheFiles(var mIdMessage: TIdMessage; BodyHTML: string;
  sAttacheFilesPath: tstrings; sCharset: string);
var
  i: Integer;
begin

  with TIdText.Create(mIdMessage.MessageParts, nil) do
  begin // ������� HTML ������, ����� ��������
    ContentType:= 'text/html;';
    CharSet := sCharset;  // !!!!!!!!!!!!!
    // ContentTransferEncoding := '8bit';
      Body.Text := BodyHTML; //  AnsiToUtf8(
  end;
  if sAttacheFilesPath<>nil  then
  begin
   i := 0;
  while i < sAttacheFilesPath.Count do
  begin
    if FileExists(sAttacheFilesPath.Strings[i]) then
    begin
      // ������ ���� ����� � ������ �� cid:filename
      BodyHTML := StringReplace(BodyHTML, sAttacheFilesPath.Strings[i],
        'cid:' + TPath.GetFileNameWithoutExtension
        (sAttacheFilesPath.Strings[i]), []);
      inc(i);
    end
    else
      sAttacheFilesPath.Delete(i);
    // ������� �������������� ���� � ����� ��������
  end;

  for i := 0 to sAttacheFilesPath.Count - 1 do
    with TIdAttachmentFile.Create(mIdMessage.MessageParts,
      sAttacheFilesPath.Strings[i]) do
    begin // ������������� ������ � ������
      ContentDisposition := 'inline';
      ContentID := TPath.GetFileNameWithoutExtension
        (sAttacheFilesPath.Strings[i]);
      ContentType := 'image/' + StringReplace
        (ExtractFileExt(sAttacheFilesPath.Strings[i]), '.', '', []);
      FileName := ExtractFileName(sAttacheFilesPath.Strings[i]);
      { DONE : ��������!! ))) }
    end;
 end;
  mIdMessage.ContentType := 'multipart/related; type="text/html"';
   mIdMessage.CharSet:=  sCharset;
  mIdMessage.ContentTransferEncoding:= 'base64';    /// ?????
  mIdMessage.Encoding := meMIME;
  mIdMessage.GenerateHeader;
  // =====
end;

procedure SendMail1(idMsg: TIdMessage);
{ DONE : Sendmail ��������. �������� �������� �������� �� ������� � ���������� �������� �������� }
const
  EdMailLogin: string = 'artem-xp@yandex.ru';
  EdMailPass: string = 'prepare5swine';
var
  IdSMTP: TIdSMTP;
  IdMessage: TIdMessage;
  IdUserPassProvider: TIdUserPassProvider;
  IdSASL: TIdSASLLogin;
  IdAntiFreeze1: TidAntiFreeze;
  idSSL: TIdSSLIOHandlerSocketOpenSSL;
begin
  IdSMTP := TIdSMTP.Create(nil);
  // IdMessage := TIdMessage.Create(nil);
  IdUserPassProvider := TIdUserPassProvider.Create(nil);
  IdSASL := TIdSASLLogin.Create(nil);
  IdAntiFreeze1 := TidAntiFreeze.Create(nil);
   idSSL:=TIdSSLIOHandlerSocketOpenSSL.Create(nil);
   IdSMTP.IOHandler:=idSSL;
  Log('Attempting to send mail');
  try
    with IdSMTP do
    begin
      // Caption := 'Trying to sendmail via: ' + aHost;
      Host := 'smtp.yandex.ru';
      Log('Trying to sendmail via: ' + Host);
      AuthType := satDefault;
      Port := 465;
      Username := EdMailLogin;
      Password := EdMailPass;
       UseTLS:=utUseRequireTLS;
      IdUserPassProvider.Username := EdMailLogin;
      IdUserPassProvider.Password := EdMailPass;
      IdSASL.UserPassProvider := IdUserPassProvider;

      try
        // IdEncoderQuotedPrintable1.Encode(IdMessage1.);
        Log('Attempting connect');
        Connect;

        Log('Successful connect ... sending message');
        Send(idMsg);
        Log('Attempting disconnect');
        Disconnect;
        Log('Successful disconnect');

        Log('Messege successfule send!');
      except
        on E: Exception do
        begin
          if connected then
            try
              Disconnect;
            except
            end;
          Log('Error sending message!' + E.Message);

        end;
      end;
    end;
  finally
    IdAntiFreeze1.Free;
    IdUserPassProvider.Free;
    IdSMTP.Free;
    IdSASL.Free;
  end;
  // IdMessage.free;
end;

procedure mIdMessageInitializeISO(var VHeaderEncoding: Char;
  var VCharSet: string);
begin
 VCharSet := IdCharsetNames[idcs_EUC_JP];
 VHeaderEncoding := 'B';
end;

function SendMail2(sFrom, sTo, sHost, sPort, sSubject, sLogin, sPass,
  sBody: string; slAttachments: tstrings): boolean;
var
  msg: TIdMessage;
  IdSMTP1: TIdSMTP;
  att: TIdAttachmentFile;
  i: Integer;
  sl: tstrings;
  s, b: string;
  str: tstrings;
  Metod:Tmethod;
    IdUserPassProvider: TIdUserPassProvider;
  IdSASL: TIdSASLLogin;
 // IdAntiFreeze1: TidAntiFreeze;
  idSSL: TIdSSLIOHandlerSocketOpenSSL;

begin
result:=false;
  Log('Start SMTP Client...');
  IdSMTP1 := TIdSMTP.Create(nil);
  IdUserPassProvider := TIdUserPassProvider.Create(nil);
  IdSASL := TIdSASLLogin.Create(nil);
 // IdAntiFreeze1 := TidAntiFreeze.Create(nil);
   idSSL:=TIdSSLIOHandlerSocketOpenSSL.Create(nil);
   IdSMTP1.IOHandler:=idSSL;
    IdUserPassProvider.Username := sLogin;
      IdUserPassProvider.Password := sPass;
   IdSASL.UserPassProvider := IdUserPassProvider;
   try
    IdSMTP1.AuthType := satDefault;
    IdSMTP1.Host := sHost; // 'smtp.yandex.ru';
    IdSMTP1.Port := StrToInt(sPort); // 25;
    IdSMTP1.Username := sLogin; // 'a.cia';
    IdSMTP1.Password := sPass; // 'Ferdy4to)';
    IdSMTP1.UseTLS:=utUseRequireTLS;
    Log('SMTP connect...');
      IdSMTP1.Connect;

  except
    on E: Exception do
      Log('Error init smtp:' + E.Message);
  end;
  Log('SMTP connected.');
  try
    Log('Init mail body...');
    msg := TIdMessage.Create(nil);
    // msg.Body.Add(sBody);
 Metod.Data := msg;
  Metod.Code := @mIdMessageInitializeISO;
 // msg.OnInitializeISO := TIdInitializeISOEvent(Metod);
    msg.Subject := AnsiToUtf8(sSubject); // 'header email';
    msg.From.Address := AnsiToUtf8(sFrom); // 'a.cia@yandex.ru';
    msg.From.Name := 'delphi'; // 'Artem';
    msg.Recipients.EMailAddresses := AnsiToUtf8(sTo); // 'artemxp@gmail.com';
  //  msg.Encoding:=meMIME;
       { TODO 10: ��������� ��������� � ������ �� ??????????? �� �������� }
  //  msg.ContentType:= 'text/html; charset=Windows-1251';  //...charset=EUC-JP';
  //  msg.ContentTransferEncoding:= 'base64';
   // msg.CharSet := 'UTF-8';        //   'EUC-JP';
   //  msg.ContentTransferEncoding := '8bit';
   //  msg.IsEncoded := true;
    { TODO 5 : �������� �������� ����� � ���� ������� }
   // if slAttachments<>nil then
    //msg.ContentType := 'text/plain';
    //  if slAttachments<>nil then
    AttacheFiles(msg, sBody, slAttachments,'Windows-1251');
 // msg.CharSet := 'Windows-1251';
  //  msg.ContentTransferEncoding := '8bit';
 //
    if IdSMTP1.connected = true then
    begin
      IdSMTP1.Send(msg);
      Log('Send mail OK');
      result:=true;
    end;
    msg.Free;
  except
    on E: Exception do
    begin
      msg.Free;
      IdSMTP1.Disconnect;
      Log('Error send mail:' + E.Message);
      result:=false;
    end;
  end;
  idSSL.Free;
  IdUserPassProvider.Free;
  IdSASL.Free;
//  IdAntiFreeze1.Free;
  IdSMTP1.Free;
end;

function GetHTTP(idHTTPvar: TIdHTTP; sURL: string): string;
var
  iNumTimeout: Integer; // ���-�� ��������
  iRT: Integer;
    str: tstrings;
const
  iRetry = 3; // ���-�� ������� ������
begin
       str := TStringList.Create;
   result := PostHTTP('GET',idHTTPvar, sURL, str);
   str.Free;
{  iNumTimeout := iRetry;
  Result := '';
  iRT := idHTTPvar.ReadTimeout;
  while (iNumTimeout > 0) and (Result = '') do
  begin
    try
      Log('��������#' + inttostr(iRetry - iNumTimeout) + ' URL:' + sURL, 1);
      // Application.ProcessMessages;
      Result := idHTTPvar.get(sURL);
    except
      on E: Exception do
      begin
        Log('������: ' + E.Message + ' URL:' + sURL, 3);
        Result := '';
        idHTTPvar.ReadTimeout := idHTTPvar.ReadTimeout + 10000;
      end;
    end;
    dec(iNumTimeout);
  end;
  idHTTPvar.ReadTimeout := iRT;
  if Result = '' then
    Log('������: ������ ����� �������!');
   }
end;

procedure GetHTTP(idHTTPvar: TIdHTTP; sURL: string;
  AResponseContent: TStream); overload;
var
  iNumTimeout: Integer; // ���-�� ��������
  iRT: Integer;
    str: tstrings;
const
  iRetry = 3; // ���-�� ������� ������
begin
     { str := TStringList.Create;
   Str.Text := PostHTTP('GET',idHTTPvar, sURL, Str);
   Str.SaveToStream(AResponseContent); }
  iNumTimeout := iRetry;
  iRT := idHTTPvar.ReadTimeout;
  while (iNumTimeout > 0) and (AResponseContent.Size = 0) do
  begin
    try
      Log('��������#' + inttostr(iRetry - iNumTimeout) + ' URL:' + sURL, 1);
      // Application.ProcessMessages;
      idHTTPvar.get(sURL, AResponseContent);
    except
      on E: Exception do
      begin
        Log('������: ' + E.Message + ' URL:' + sURL, 3);
        idHTTPvar.ReadTimeout := idHTTPvar.ReadTimeout + 10000;
      end;
    end;
    dec(iNumTimeout);
  end;
  idHTTPvar.ReadTimeout := iRT;
  if AResponseContent.Size = 0 then
    Log('������: ������ ����� �������!');

end;

{ **** UBPFD *********** by delphibase.endimus.com ****
>> ������� ������ (���������� ��������������� HTML-��������) � TWebBrowser
(�� �� �����, � �� ��������� ����������)

������� ��������� ���������� ����� ����� � TWebBrowser ��� TWebBrowser_V1.
� �� ������� ����� �������� ��� html-������ � ���������� html-���������,
��������� �� ����������. ����������� ����� � ����� ���������� ����� ������
� ������ ��������� ��������� ���������� � ������� HTML.
��� ������ ������� ���������� ������������� � ������� Internet Explorer.
����� � ��������� ���������� ������ ������ - TWebBrowser_V1, ��� �������������
����� �������� ��� �� TWebBrowser (������ ���������� ��� ������� ���������� WB),
�� ��� ���� ��������� � ���� �������� ����� �������� ������ �� ��������
� IE ������ 5.0 � ����, � �� ����� ��� TWebBrowser_V1 ������������ ������
������� � ������ 4.0.

�����������: ActiveX, SHDocVw, MSHTML, Forms, ������������� Internet Explorer
�����:       lipskiy, lipskiy@mail.ru, ICQ:51219290, �����-���������
Copyright:   ����� �� FAQ � �������������� lipskiy � Donal_Graeme
����:        14 ������� 2002 �.
***************************************************** }


procedure TextToWebBrowser(Text: string; var WB: TWebBrowser);
var
  Document: IHTMLDocument2;
  V: OleVariant;
begin
  // �������� ���������� ������� ������ ���� ��� �� ������� ������ ������
  if WB.Document = nil then
    WB.Navigate('about:blank',EmptyParam,EmptyParam,EmptyParam,EmptyParam);
  // ������� �������� ��������� � ��������� ������������ ��� ���������
  while WB.Document = nil do
    Application.ProcessMessages;
  Document := WB.Document as IHtmlDocument2;
  // ��������� ����� (�� 2��)
  {��������� ������� ������� ������� - ������ ������� ������� �� ������� ��� XP}
  V := VarArrayCreate([0, 0], varVariant);
  V[0] := Text;
  Document.Write(PSafeArray(TVarData(v).VArray));
  Document.Close;
end;

function PostHTTP(sMethod: string; idHTTPvar: TIdHTTP; sURL: string; PostData: tstrings): string;
var
  iNumTimeout: Integer; // ���-�� ��������
  iRT: Integer;
  sgHTTP: THTTPSend;
  Data: TStream;
  stm: TMemoryStream;
  str: tstrings;
  URLData: AnsiString;
begin
  iNumTimeout := 3;
  Result := '';
  iRT := idHTTPvar.ReadTimeout;
  while (iNumTimeout > 0) and (Result = '') do
  begin
    try
      stm := TMemoryStream.Create;
      str := TStringList.Create;
      sgHTTP := THTTPSend.Create;
      PostData.Delimiter:='&';
      URLData:=PostData.DelimitedText;
      try
        sgHTTP.Document.Write(Pointer(URLData)^, Length(URLData));
        sgHTTP.TargetHost:= idHTTPvar.Request.Host;
        sgHTTP.UserAgent:= idHTTPvar.Request.UserAgent;
        sgHTTP.MimeType := 'application/x-www-form-urlencoded';
        //sgHTTP.MimeType :=idHTTPvar.Request.Accept;// 'application/x-www-form-urlencoded';
        sgHTTP.Headers.Add('Referer: '+idHTTPvar.Request.Referer);
        sgHTTP.Cookies.Text:=Cookies;
        sgHTTP.HTTPMethod('POST', sURL);
          Cookies:=sgHTTP.Cookies.Text;//idHTTPvar.CookieManager.CookieCollection.Cookies[0].CookieText;
         // if idHTTPvar.CookieManager.CookieCollection.Count>1 then
         //  sgHTTP.Cookies.Text:=sgHTTP.Cookies.Text+','+idHTTPvar.CookieManager.CookieCollection.Cookies[1].CookieText;
        stm.CopyFrom(sgHTTP.Document, 0);
        stm.Seek(0, soFromBeginning);
        str.LoadFromStream(stm);
        Result := str.Text;
      finally
        sgHTTP.Free;
        str.Free;
        stm.Free;
      end;
//       Result := idHTTPvar.Post(sURL, PostData);   { TODO : Invalid code page }
    except
      // on E: EIDHttpProtocolException do
      // FormMain.Log('������: ' + E.Message, 3);
      on E: Exception do
      begin
        Log('������: ' + E.Message + ' URL:' + sURL + ' Post:' +
          PostData.Text, 3);
        Result := '';
        idHTTPvar.ReadTimeout := idHTTPvar.ReadTimeout + 10000;
      end;
    end;
    dec(iNumTimeout);
  end;
  idHTTPvar.ReadTimeout := iRT;
  if Result = '' then
    Log('������: ������ ����� �������!');
end;

function ValidData: boolean;
var
  ErrString: string;
begin
  Result := true;
  { ErrString := '';
    if StringGrid1.RowCount<1 then
    ErrString := '����� ������ ���. ������ ��������.';
    if Length(trim(StringGrid1.Rows[0].Text)) < 10 then
    ErrString := '����� ������ ���. ������ ��������.';
    if trim(FormSettings.EdSMTPHost.Text)
    = '' then { TODO : ���������� �������� ���������� �� �� �����! }
  { ErrString := ErrString + #13 + #187 + 'DNS server not filled in';
    if trim(FormSettings.EdRecipients.Text) = '' then
    ErrString := ErrString + #13 + #187 + 'Recipients email not filled in';
    if trim(FormSettings.EdSender.Text) = '' then
    ErrString := ErrString + #13 + #187 + 'Sender email not filled in';
    if trim(FormSettings.edSMTPport.Text) = '' then
    ErrString := ErrString + #13 + #187 + 'SMTPport not filled in';
    if ErrString <> '' then
    begin
    FormMain.Log('Cannot proceed due to the following errors:' + EOL +
    ErrString);
    Result := false;
    end; }
end;
 {
procedure SendData(sListData: tstrings);
  function GetStrGrd(): UnicodeString;
  var
    r, c: Integer;
    s: string;

  begin
    { Result := '<html><head>'
      +'<meta http-equiv="Content-Type" content="text/html; charset=windows-1251" />'
      +'<title>Japancar.ru - ����� ������������� �� ����������</title></head>'
      +'<body><table width="100%" border="1"><tr>'
      +'<th scope="col">�</th>'
      +'<th scope="col">����� ����������</th>'
      +'<th scope="col">�����</th>'
      +'<th scope="col">���</th>'
      +'<th scope="col">����� ������, ���������</th>'
      +'<th scope="col">N</th>'
      +'<th scope="col">&nbsp;</th>'
      +'<th scope="col">����</th>'
      +'<th scope="col">����� ��������</th>'
      +'<th scope="col">����</th>'
      +'</tr>'; }
 {   for r := 0 to -1 do
    begin
      s := sListData.Strings[c];
      Result := Result + s;
      for c := 2 to sListData.Count - 1 do
      begin

        if s = '' then
          s := '<br>';
        if c = 1 then
          s := '<a href="' + s + '">' + s + '</a>';
        Result := Result + '<td>' + s + '</td>';
      end;
      // result := result + '</tr>';
    end;
    { Result := '> ';
      for r := 0 to StringGrid1.RowCount - 1 do
      begin
      Result := Result+' ' + StringGrid1.Rows[r].DelimitedText;
      if r < (StringGrid1.RowCount - 1) then
      Result := Result + EOL + '> ';
      end; }
    // result := result + '</table></body></html>';
 { end;

var
  IdMessage: TIdMessage;
  EdSender, EdRecipients: string;
begin
  Log('SendMail.Check...');

  IdMessage := TIdMessage.Create();
  EdSender := 'artemxp@gmail.com';
  EdRecipients := 'artemxp@gmail.com';
  with IdMessage do
  begin
    Log('Assigning mail message properties');
    From.Text := 'Delphi Indy Client <' + EdSender + '>';
    Sender.Text := EdSender;
    Recipients.EMailAddresses := EdRecipients;
    Subject := 'Japancar.ru - ����� ������������� �� ����������';
    ContentType := 'text/html';
    CharSet := 'Windows-1251';
    ContentTransferEncoding := '8bit';
    IsEncoded := true;
    Body.Text := GetStrGrd();
  end;
  Log('SendMail.');
  SendMail(IdMessage);

  // end;
end;   }

end.
