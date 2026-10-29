{
License Open-TRAFFIQX-Client-for-Delphi

Copyright (C) 2026 Landrix Software GmbH & Co. KG
Sven Harazim, info@landrix.de
Version 0.1

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
}

unit MiniApp.Model;

interface

uses
  Winapi.Windows, System.Generics.Collections, System.JSON;

type
  TMiniAppEnvironment = (meSandbox, meProduction);

  TMiniAppSeller = record
    Name: string;
    Street: string;
    PostalCode: string;
    City: string;
    CountryCode: string;
    VatID: string;
    TaxNumber: string;
    ContactName: string;
    Phone: string;
    Email: string;
    ElectronicAddress: string;
    IBAN: string;
    BIC: string;
    BankName: string;
  end;

  TMiniAppCustomer = record
    CustomerNumber: string;
    Name: string;
    Street: string;
    PostalCode: string;
    City: string;
    CountryCode: string;
    VatID: string;
    DeliveryChannel: string;
    BuyerReference: string;
    ElectronicAddress: string;
    ElectronicAddressScheme: string;
    ContactEmail: string;
    TraffiqxID: string;
  end;

  TMiniAppPosition = record
    Description: string;
    UnitCode: string;
    Quantity: Currency;
    NetUnitPrice: Currency;
    VatRate: Currency;
  end;

  // Eine Instanz hält die Dateisperre bis zur Freigabe. Aufruf im Hauptthread.
  TMiniAppData = class
  private
    FFileName: string;
    FLockHandle: THandle;
    FNextInvoiceSequence: Int64;
    FCustomers: TList<TMiniAppCustomer>;
    FPositions: TList<TMiniAppPosition>;
    procedure CreateExamples;
    procedure ReadJson(const AObject: TJSONObject);
    function ToJson: TJSONObject;
    function GetPendingInvoiceNumber: string;
  public
    Seller: TMiniAppSeller;
    Environment: TMiniAppEnvironment;
    constructor Create;
    destructor Destroy; override;
    // Einmalig laden; bei fehlender Datei Beispieldaten sofort speichern.
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string = '');
    // Erst dauerhaft reservieren, dann zurückgeben. Lücken sind beabsichtigt.
    function NextInvoiceNumber: string;
    procedure Validate;
    property Customers: TList<TMiniAppCustomer> read FCustomers;
    property Positions: TList<TMiniAppPosition> read FPositions;
    property PendingInvoiceNumber: string read GetPendingInvoiceNumber;
  end;

procedure ValidateCustomer(const ACustomer: TMiniAppCustomer);
procedure ValidatePosition(const APosition: TMiniAppPosition);

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, MiniApp.Storage;

function JsonString(const AObject: TJSONObject; const AKey: string): string;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AKey);
  if not (LValue is TJSONString) then
    raise EConvertError.CreateFmt('Textfeld "%s" fehlt oder ist ungültig.', [AKey]);
  Result := LValue.Value;
end;

function JsonCurrency(const AObject: TJSONObject; const AKey: string): Currency;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AKey);
  if not (LValue is TJSONNumber) then
    raise EConvertError.CreateFmt('Zahlenfeld "%s" fehlt oder ist ungültig.', [AKey]);
  if not TryStrToCurr(LValue.Value, Result, TFormatSettings.Invariant) then
    raise EConvertError.CreateFmt('Zahlenfeld "%s" liegt außerhalb des Wertebereichs.', [AKey]);
end;

function JsonObject(const AValue: TJSONValue): TJSONObject;
begin
  if not (AValue is TJSONObject) then
    raise EConvertError.Create('In den Stammdaten wurde ein JSON-Objekt erwartet.');
  Result := TJSONObject(AValue);
end;

function JsonArray(const AObject: TJSONObject; const AKey: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AKey);
  if not (LValue is TJSONArray) then
    raise EConvertError.CreateFmt('Liste "%s" fehlt oder ist ungültig.', [AKey]);
  Result := TJSONArray(LValue);
end;

procedure ValidateCountryCode(const ACode: string);
begin
  if (Length(ACode) <> 2) or not CharInSet(ACode[1], ['A'..'Z']) or
    not CharInSet(ACode[2], ['A'..'Z']) then
    raise EConvertError.Create('Land bitte als zweistelligen ISO-Code eingeben, z. B. DE.');
end;

procedure ValidateCustomer(const ACustomer: TMiniAppCustomer);
begin
  if (Trim(ACustomer.CustomerNumber) = '') or (Trim(ACustomer.Name) = '') then
    raise EConvertError.Create('Kundennummer und Kundenname dürfen nicht leer sein.');
  ValidateCountryCode(ACustomer.CountryCode);
  if (ACustomer.DeliveryChannel <> 'email') and (ACustomer.DeliveryChannel <> 'leitwegid') and
    (ACustomer.DeliveryChannel <> 'traffiqx') and (ACustomer.DeliveryChannel <> 'peppol') then
    raise EConvertError.Create('Unbekannter Versandweg.');
  if (ACustomer.DeliveryChannel = 'leitwegid') and (Trim(ACustomer.BuyerReference) = '') then
    raise EConvertError.Create('Für diesen Versandweg fehlt die Leitweg-ID (BT-10).');
  if (ACustomer.DeliveryChannel = 'traffiqx') and (Trim(ACustomer.TraffiqxID) = '') then
    raise EConvertError.Create('Für diesen Versandweg fehlt die TRAFFIQX-ID.');
  if (ACustomer.DeliveryChannel = 'email') and (Trim(ACustomer.ContactEmail) = '') then
    raise EConvertError.Create('Für den E-Mail-Versand fehlt die Kontakt-E-Mail.');
  if (ACustomer.DeliveryChannel = 'peppol') and
    ((Trim(ACustomer.ElectronicAddress) = '') or (Trim(ACustomer.ElectronicAddressScheme) = '')) then
    raise EConvertError.Create('Für Peppol fehlen elektronische Adresse oder Schema (BT-49).');
end;

procedure ValidatePosition(const APosition: TMiniAppPosition);
begin
  if (Trim(APosition.Description) = '') or (Trim(APosition.UnitCode) = '') then
    raise EConvertError.Create('Positionstext und Einheit dürfen nicht leer sein.');
  if (APosition.Quantity <= 0) or (APosition.NetUnitPrice < 0) or
    (APosition.VatRate < 0) or (APosition.VatRate > 100) then
    raise EConvertError.Create('Menge muss positiv sein, Preis nicht negativ und USt. zwischen 0 und 100.');
end;

constructor TMiniAppData.Create;
begin
  inherited Create;
  FLockHandle := INVALID_HANDLE_VALUE;
  FCustomers := TList<TMiniAppCustomer>.Create;
  FPositions := TList<TMiniAppPosition>.Create;
  FNextInvoiceSequence := 1;
  Environment := meSandbox;
end;

destructor TMiniAppData.Destroy;
begin
  if FLockHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(FLockHandle);
  FPositions.Free;
  FCustomers.Free;
  inherited;
end;

procedure TMiniAppData.CreateExamples;
var
  LCustomer: TMiniAppCustomer;
  LPosition: TMiniAppPosition;
begin
  // Ausschließlich fiktive Testdaten; keine gültigen Steuer- oder Bankkennungen.
  Seller := Default(TMiniAppSeller);
  Seller.Name := 'Muster Handwerk GmbH';
  Seller.Street := 'Beispielweg 1';
  Seller.PostalCode := '00000';
  Seller.City := 'Musterstadt';
  Seller.CountryCode := 'DE';
  Seller.VatID := 'DE123456788'; // Dummywerte aus XRechnung-for-Delphi (gueltige Pruefziffern)
  Seller.TaxNumber := '222/111/4444';
  Seller.ContactName := 'Testkontakt';
  Seller.Phone := '+49 000 000000';
  Seller.Email := 'kontakt@example.invalid';
  Seller.ElectronicAddress := 'rechnung@example.invalid';
  Seller.IBAN := 'DE75512108001245126199'; // nicht existierend, aber gueltig
  Seller.BIC := '';
  Seller.BankName := 'Fiktive Testbank';
  FCustomers.Clear;
  LCustomer := Default(TMiniAppCustomer);
  LCustomer.CustomerNumber := 'K-001';
  LCustomer.Name := 'Beispielkunde E-Mail';
  LCustomer.Street := 'Testgasse 2';
  LCustomer.PostalCode := '00000';
  LCustomer.City := 'Musterstadt';
  LCustomer.CountryCode := 'DE';
  LCustomer.DeliveryChannel := 'email';
  LCustomer.ElectronicAddress := 'kunde1@example.invalid';
  LCustomer.ElectronicAddressScheme := 'EM';
  LCustomer.ContactEmail := 'kunde1@example.invalid';
  FCustomers.Add(LCustomer);
  LCustomer.CustomerNumber := 'K-002';
  LCustomer.Name := 'Beispielstelle Leitweg-ID';
  LCustomer.DeliveryChannel := 'leitwegid';
  LCustomer.BuyerReference := '04011000-1234512345-06';
  LCustomer.ElectronicAddress := 'kunde2@example.invalid';
  LCustomer.ContactEmail := 'kunde2@example.invalid';
  FCustomers.Add(LCustomer);
  LCustomer.CustomerNumber := 'K-003';
  LCustomer.Name := 'Beispielkunde TRAFFIQX';
  LCustomer.DeliveryChannel := 'traffiqx';
  LCustomer.BuyerReference := '';
  LCustomer.TraffiqxID := '0000000000000';
  LCustomer.ElectronicAddress := 'kunde3@example.invalid';
  LCustomer.ContactEmail := 'kunde3@example.invalid';
  FCustomers.Add(LCustomer);
  LCustomer.CustomerNumber := 'K-004';
  LCustomer.Name := 'Beispielkunde Peppol';
  LCustomer.DeliveryChannel := 'peppol';
  LCustomer.TraffiqxID := '';
  LCustomer.ElectronicAddress := 'DE123456788';
  LCustomer.ElectronicAddressScheme := '9930';
  LCustomer.ContactEmail := 'kunde4@example.invalid';
  FCustomers.Add(LCustomer);
  FPositions.Clear;
  LPosition := Default(TMiniAppPosition);
  LPosition.Description := 'Testmaterial';
  LPosition.Quantity := 2;
  LPosition.UnitCode := 'H87';
  LPosition.NetUnitPrice := 12.50;
  LPosition.VatRate := 19;
  FPositions.Add(LPosition);
  LPosition.Description := 'Test-Arbeitsstunde';
  LPosition.Quantity := 1.5;
  LPosition.UnitCode := 'HUR';
  LPosition.NetUnitPrice := 65;
  FPositions.Add(LPosition);
  FNextInvoiceSequence := 1;
  Environment := meSandbox;
end;

function TMiniAppData.ToJson: TJSONObject;
var
  LObject: TJSONObject;
  LCustomers, LPositions: TJSONArray;
  LCustomer: TMiniAppCustomer;
  LPosition: TMiniAppPosition;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('version', TJSONNumber.Create(1));
    Result.AddPair('next_invoice_number', PendingInvoiceNumber);
    if Environment = meProduction then
      Result.AddPair('environment', 'production')
    else
      Result.AddPair('environment', 'sandbox');
    LObject := TJSONObject.Create;
    Result.AddPair('seller', LObject);
    LObject.AddPair('name', Seller.Name);
    LObject.AddPair('street', Seller.Street);
    LObject.AddPair('postal_code', Seller.PostalCode);
    LObject.AddPair('city', Seller.City);
    LObject.AddPair('country_code', Seller.CountryCode);
    LObject.AddPair('vat_id', Seller.VatID);
    LObject.AddPair('tax_number', Seller.TaxNumber);
    LObject.AddPair('contact_name', Seller.ContactName);
    LObject.AddPair('phone', Seller.Phone);
    LObject.AddPair('email', Seller.Email);
    LObject.AddPair('electronic_address', Seller.ElectronicAddress);
    LObject.AddPair('iban', Seller.IBAN);
    LObject.AddPair('bic', Seller.BIC);
    LObject.AddPair('bank_name', Seller.BankName);
    LCustomers := TJSONArray.Create;
    Result.AddPair('customers', LCustomers);
    for LCustomer in FCustomers do
    begin
      LObject := TJSONObject.Create;
      LCustomers.AddElement(LObject);
      LObject.AddPair('customer_number', LCustomer.CustomerNumber);
      LObject.AddPair('name', LCustomer.Name);
      LObject.AddPair('street', LCustomer.Street);
      LObject.AddPair('postal_code', LCustomer.PostalCode);
      LObject.AddPair('city', LCustomer.City);
      LObject.AddPair('country_code', LCustomer.CountryCode);
      LObject.AddPair('vat_id', LCustomer.VatID);
      LObject.AddPair('delivery_channel', LCustomer.DeliveryChannel);
      LObject.AddPair('buyer_reference', LCustomer.BuyerReference);
      LObject.AddPair('electronic_address', LCustomer.ElectronicAddress);
      LObject.AddPair('electronic_address_scheme', LCustomer.ElectronicAddressScheme);
      LObject.AddPair('contact_email', LCustomer.ContactEmail);
      LObject.AddPair('traffiqx_id', LCustomer.TraffiqxID);
    end;
    LPositions := TJSONArray.Create;
    Result.AddPair('positions', LPositions);
    for LPosition in FPositions do
    begin
      LObject := TJSONObject.Create;
      LPositions.AddElement(LObject);
      LObject.AddPair('description', LPosition.Description);
      LObject.AddPair('unit_code', LPosition.UnitCode);
      LObject.AddPair('quantity', TJSONNumber.Create(CurrToStr(LPosition.Quantity, TFormatSettings.Invariant)));
      LObject.AddPair('net_unit_price', TJSONNumber.Create(CurrToStr(LPosition.NetUnitPrice, TFormatSettings.Invariant)));
      LObject.AddPair('vat_rate', TJSONNumber.Create(CurrToStr(LPosition.VatRate, TFormatSettings.Invariant)));
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TMiniAppData.ReadJson(const AObject: TJSONObject);
var
  LObject: TJSONObject;
  LItem: TJSONValue;
  LNumber, LEnvironment: string;
  LCustomer: TMiniAppCustomer;
  LPosition: TMiniAppPosition;
begin
  if JsonCurrency(AObject, 'version') <> 1 then
    raise EConvertError.Create('Unbekannte Version der Stammdaten.');
  LNumber := JsonString(AObject, 'next_invoice_number');
  if (Copy(LNumber, 1, 5) <> 'TEST-') or
    not TryStrToInt64(Copy(LNumber, 6, MaxInt), FNextInvoiceSequence) or
    (FNextInvoiceSequence < 1) then
    raise EConvertError.Create('Ungültiger Rechnungszähler; kein automatisches Zurücksetzen.');
  if LNumber <> PendingInvoiceNumber then
    raise EConvertError.Create('Rechnungsnummer muss dem Muster TEST-0001 entsprechen.');
  LEnvironment := JsonString(AObject, 'environment');
  if LEnvironment = 'sandbox' then
    Environment := meSandbox
  else if LEnvironment = 'production' then
    Environment := meProduction
  else
    raise EConvertError.Create('Unbekannte Umgebung in den Stammdaten.');
  LObject := JsonObject(AObject.GetValue('seller'));
  Seller.Name := JsonString(LObject, 'name');
  Seller.Street := JsonString(LObject, 'street');
  Seller.PostalCode := JsonString(LObject, 'postal_code');
  Seller.City := JsonString(LObject, 'city');
  Seller.CountryCode := JsonString(LObject, 'country_code');
  Seller.VatID := JsonString(LObject, 'vat_id');
  Seller.TaxNumber := JsonString(LObject, 'tax_number');
  Seller.ContactName := JsonString(LObject, 'contact_name');
  Seller.Phone := JsonString(LObject, 'phone');
  Seller.Email := JsonString(LObject, 'email');
  Seller.ElectronicAddress := JsonString(LObject, 'electronic_address');
  Seller.IBAN := JsonString(LObject, 'iban');
  Seller.BIC := JsonString(LObject, 'bic');
  Seller.BankName := JsonString(LObject, 'bank_name');
  FCustomers.Clear;
  for LItem in JsonArray(AObject, 'customers') do
  begin
    LObject := JsonObject(LItem);
    LCustomer := Default(TMiniAppCustomer);
    LCustomer.CustomerNumber := JsonString(LObject, 'customer_number');
    LCustomer.Name := JsonString(LObject, 'name');
    LCustomer.Street := JsonString(LObject, 'street');
    LCustomer.PostalCode := JsonString(LObject, 'postal_code');
    LCustomer.City := JsonString(LObject, 'city');
    LCustomer.CountryCode := JsonString(LObject, 'country_code');
    LCustomer.VatID := JsonString(LObject, 'vat_id');
    LCustomer.DeliveryChannel := JsonString(LObject, 'delivery_channel');
    LCustomer.BuyerReference := JsonString(LObject, 'buyer_reference');
    LCustomer.ElectronicAddress := JsonString(LObject, 'electronic_address');
    LCustomer.ElectronicAddressScheme := JsonString(LObject, 'electronic_address_scheme');
    LCustomer.ContactEmail := JsonString(LObject, 'contact_email');
    LCustomer.TraffiqxID := JsonString(LObject, 'traffiqx_id');
    FCustomers.Add(LCustomer);
  end;
  FPositions.Clear;
  for LItem in JsonArray(AObject, 'positions') do
  begin
    LObject := JsonObject(LItem);
    LPosition := Default(TMiniAppPosition);
    LPosition.Description := JsonString(LObject, 'description');
    LPosition.UnitCode := JsonString(LObject, 'unit_code');
    LPosition.Quantity := JsonCurrency(LObject, 'quantity');
    LPosition.NetUnitPrice := JsonCurrency(LObject, 'net_unit_price');
    LPosition.VatRate := JsonCurrency(LObject, 'vat_rate');
    FPositions.Add(LPosition);
  end;
  Validate;
end;

procedure TMiniAppData.Validate;
var
  I, J: Integer;
  LPosition: TMiniAppPosition;
begin
  if Trim(Seller.Name) = '' then
    raise EConvertError.Create('Der Name des Rechnungsstellers darf nicht leer sein.');
  ValidateCountryCode(Seller.CountryCode);
  for I := 0 to FCustomers.Count - 1 do
  begin
    ValidateCustomer(FCustomers[I]);
    for J := 0 to I - 1 do
      if SameText(FCustomers[I].CustomerNumber, FCustomers[J].CustomerNumber) then
        raise EConvertError.Create('Kundennummern müssen eindeutig sein.');
  end;
  for LPosition in FPositions do
    ValidatePosition(LPosition);
end;

procedure TMiniAppData.LoadFromFile(const AFileName: string);
var
  LJson: TJSONValue;
  LAttributes, LError: DWORD;
begin
  if FFileName <> '' then
    raise EInvalidOperation.Create('Stammdaten wurden bereits geladen.');
  FFileName := ExpandFileName(AFileName);
  try
    if not ForceDirectories(ExtractFileDir(FFileName)) then
      raise EInOutError.Create('Der Stammdatenordner konnte nicht angelegt werden.');
    // Separate Sperrdatei: Die JSON-Datei selbst wird beim Speichern ersetzt.
    FLockHandle := CreateFile(PChar(FFileName + '.lock'), GENERIC_READ or GENERIC_WRITE,
      0, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if FLockHandle = INVALID_HANDLE_VALUE then
      raise EInOutError.CreateFmt('Stammdaten sind gesperrt oder nicht beschreibbar: %s (%s)',
        [FFileName, SysErrorMessage(GetLastError)]);
    LAttributes := GetFileAttributes(PChar(FFileName));
    if LAttributes = INVALID_FILE_ATTRIBUTES then
    begin
      LError := GetLastError;
      // Nur eine tatsächlich fehlende Datei erlaubt neue Beispieldaten.
      if LError <> ERROR_FILE_NOT_FOUND then
        RaiseLastOSError(LError);
    end;
    if LAttributes <> INVALID_FILE_ATTRIBUTES then
    begin
      LJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFileName, TEncoding.UTF8));
      try
        ReadJson(JsonObject(LJson));
      finally
        LJson.Free;
      end;
    end
    else
    begin
      CreateExamples;
      SaveToFile;
    end;
  except
    if FLockHandle <> INVALID_HANDLE_VALUE then
      CloseHandle(FLockHandle);
    FLockHandle := INVALID_HANDLE_VALUE;
    FFileName := '';
    raise;
  end;
end;

procedure TMiniAppData.SaveToFile(const AFileName: string);
var
  LJson: TJSONObject;
begin
  if (FFileName = '') or (FLockHandle = INVALID_HANDLE_VALUE) then
    raise EInvalidOperation.Create('Stammdaten müssen vor dem Speichern geladen werden.');
  if (AFileName <> '') and not SameFileName(ExpandFileName(AFileName), FFileName) then
    raise EInvalidOperation.Create('Stammdaten dürfen nur in die gesperrte Quelldatei geschrieben werden.');
  Validate;
  LJson := ToJson;
  try
    AtomicWriteText(FFileName, LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TMiniAppData.GetPendingInvoiceNumber: string;
var
  LDigits: string;
begin
  LDigits := IntToStr(FNextInvoiceSequence);
  while Length(LDigits) < 4 do
    LDigits := '0' + LDigits;
  Result := 'TEST-' + LDigits;
end;

function TMiniAppData.NextInvoiceNumber: string;
begin
  if (FFileName = '') or (FLockHandle = INVALID_HANDLE_VALUE) then
    raise EInvalidOperation.Create('Vor der Nummernvergabe müssen die Stammdaten geladen sein.');
  if FNextInvoiceSequence = High(Int64) then
    raise ERangeError.Create('Der Rechnungsnummernbereich ist ausgeschöpft.');
  Result := PendingInvoiceNumber;
  Inc(FNextInvoiceSequence);
  // Auch bei Speicherfehler nicht zurückdrehen; keine Nummer wurde zurückgegeben.
  SaveToFile;
end;

end.
