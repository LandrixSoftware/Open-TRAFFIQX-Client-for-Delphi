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

unit MiniApp.InvoiceBuilder;

{$Q+} // Auch im Release-Build keine stillen Überläufe bei Rechnungssummen.

interface

uses
  System.SysUtils, MiniApp.Model, intf.Invoice;

// Der Aufrufer besitzt das Ergebnis und gibt es mit Free frei.
function BuildInvoice(AData: TMiniAppData; const ACustomer: TMiniAppCustomer;
  const AInvoiceNumber: string; AIssueDate: TDate): TInvoice;
procedure SaveInvoiceXml(AInvoice: TInvoice; const AFileName: string);

implementation

uses
  System.DateUtils, intf.XRechnung, intf.TRAFFIQXInvoiceAPI;

procedure RequireText(const AValue, AField: string);
begin
  if Trim(AValue) = '' then
    raise EConvertError.Create(AField + ' fehlt. Bitte die Stammdaten ergänzen.');
end;

function RoundedProduct(const ALeft, ARight: Currency; ADivisor: Int64): Currency;
var
  LLeft, LRight, LProduct, LDivisor, LCents, LScaled: Int64;
begin
  // Currency ist ein Int64 mit vier Dezimalstellen. Erst das vollständige
  // Produkt runden, nicht zuvor auf vier Stellen und nicht mit Banker's Rounding.
  // S2 erlaubt nur nichtnegative Preise, Mengen und Steuersätze.
  Move(ALeft, LLeft, SizeOf(LLeft));
  Move(ARight, LRight, SizeOf(LRight));
  if (LLeft < 0) or (LRight < 0) then
    raise EConvertError.Create('Negative Rechnungsbeträge werden nicht unterstützt.');
  if LRight <> 0 then
    if LLeft > High(Int64) div LRight then
      raise ERangeError.Create('Menge, Preis oder Steuerbasis sind für die Berechnung zu groß.');
  LProduct := LLeft * LRight;
  LDivisor := 1000000 * ADivisor;
  LCents := LProduct div LDivisor;
  if LProduct mod LDivisor >= LDivisor div 2 then
    Inc(LCents);
  LScaled := LCents * 100;
  Move(LScaled, Result, SizeOf(Result));
end;

function BuildInvoice(AData: TMiniAppData; const ACustomer: TMiniAppCustomer;
  const AInvoiceNumber: string; AIssueDate: TDate): TInvoice;
var
  LPosition: TMiniAppPosition;
  LLine: TInvoiceLine;
  LTax: TInvoiceTaxAmount;
  LRate: Currency;
  LID, LUnitCode: string;
  I, J: Integer;
begin
  if AData = nil then
    raise EArgumentNilException.Create('Stammdaten fehlen.');
  AData.Validate;
  ValidateCustomer(ACustomer);
  RequireText(AInvoiceNumber, 'Rechnungsnummer');
  if AIssueDate <= 0 then
    raise EConvertError.Create('Ein gültiges Rechnungsdatum ist erforderlich.');
  if AData.Positions.Count = 0 then
    raise EConvertError.Create('Mindestens eine Testposition ist erforderlich.');
  RequireText(AData.Seller.City, 'Ort des Rechnungsstellers');
  RequireText(AData.Seller.PostalCode, 'Postleitzahl des Rechnungsstellers');
  RequireText(AData.Seller.ContactName, 'Kontaktname des Rechnungsstellers');
  RequireText(AData.Seller.Phone, 'Telefon des Rechnungsstellers');
  RequireText(AData.Seller.Email, 'Kontakt-E-Mail des Rechnungsstellers');
  RequireText(AData.Seller.ElectronicAddress, 'Elektronische Adresse des Rechnungsstellers (BT-34)');
  if (Trim(AData.Seller.VatID) = '') and (Trim(AData.Seller.TaxNumber) = '') then
    raise EConvertError.Create('USt-IdNr. oder Steuernummer des Rechnungsstellers fehlt.');
  RequireText(AData.Seller.IBAN, 'IBAN');
  // BIC (BT-86) ist im SEPA-Raum optional.
  RequireText(ACustomer.City, 'Ort des Kunden');
  RequireText(ACustomer.PostalCode, 'Postleitzahl des Kunden');
  if ACustomer.DeliveryChannel <> 'peppol' then
    RequireText(ACustomer.ContactEmail, 'Kontakt-E-Mail des Kunden (BT-49)');

  Result := TInvoice.Create;
  try
    // Normales Profil, auch in der Sandbox. PrepareSandboxXml folgt erst in S4.
    Result.ProfileID := 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';
    Result.InvoiceNumber := AInvoiceNumber;
    Result.InvoiceIssueDate := DateOf(AIssueDate);
    Result.InvoiceDueDate := IncDay(Result.InvoiceIssueDate, 14);
    Result.InvoiceTypeCode := itc_CommercialInvoice;
    Result.InvoiceCurrencyCode := 'EUR';
    // Der UBL-Adapter nutzt dieses Feld für currencyID an allen Beträgen;
    // ein separates cbc:TaxCurrencyCode (BT-6) schreibt er nicht.
    Result.TaxCurrencyCode := 'EUR';
    Result.BuyerReference := TInvoiceEmptyLeitwegID.NON_EXISTENT;
    if ACustomer.DeliveryChannel = 'traffiqx' then
    begin
      LID := TraffiqxNormalizeId(ACustomer.TraffiqxID);
      RequireText(LID, 'TRAFFIQX-ID des Kunden');
      for I := 1 to Length(LID) do
        if not CharInSet(LID[I], ['0'..'9']) then
          raise EConvertError.Create('Die TRAFFIQX-ID muss nach TX: ausschließlich Ziffern enthalten.');
      Result.BuyerReference := 'TX:' + LID;
    end
    else if ACustomer.DeliveryChannel = 'leitwegid' then
      Result.BuyerReference := Trim(ACustomer.BuyerReference);

    with Result.AccountingSupplierParty do
    begin
      RegistrationName := AData.Seller.Name;
      Address.StreetName := AData.Seller.Street;
      Address.City := AData.Seller.City;
      Address.PostalZone := AData.Seller.PostalCode;
      Address.CountryCode := AData.Seller.CountryCode;
      VATCompanyID := AData.Seller.VatID;
      VATCompanyNumber := AData.Seller.TaxNumber;
      ContactName := AData.Seller.ContactName;
      ContactTelephone := AData.Seller.Phone;
      ContactElectronicMail := AData.Seller.Email;
      ElectronicAddressSellerBuyer := AData.Seller.ElectronicAddress;
      ElectronicAddressSellerBuyerSchemeID := 'EM';
    end;
    with Result.AccountingCustomerParty do
    begin
      RegistrationName := ACustomer.Name;
      Address.StreetName := ACustomer.Street;
      Address.City := ACustomer.City;
      Address.PostalZone := ACustomer.PostalCode;
      Address.CountryCode := ACustomer.CountryCode;
      VATCompanyID := ACustomer.VatID;
      ContactElectronicMail := ACustomer.ContactEmail;
      if ACustomer.DeliveryChannel = 'peppol' then
      begin
        ElectronicAddressSellerBuyer := Trim(ACustomer.ElectronicAddress);
        ElectronicAddressSellerBuyerSchemeID := Trim(ACustomer.ElectronicAddressScheme);
      end
      else
      begin
        ElectronicAddressSellerBuyer := Trim(ACustomer.ContactEmail);
        ElectronicAddressSellerBuyerSchemeID := 'EM';
      end;
    end;
    Result.PaymentID := AInvoiceNumber;
    Result.PaymentTermsType := iptt_Net;
    Result.PaymentTermNetNote := 'Zahlbar innerhalb von 14 Tagen ohne Abzug.';
    with Result.PaymentTypes.AddPaymentType do
    begin
      PaymentMeansCode := ipmc_SEPACreditTransfer;
      FinancialAccount := AData.Seller.IBAN;
      FinancialAccountName := AData.Seller.Name;
      FinancialInstitutionBranch := AData.Seller.BIC;
    end;

    for I := 0 to AData.Positions.Count - 1 do
    begin
      LPosition := AData.Positions[I];
      // PercentageToStr des Adapters schreibt genau zwei Dezimalstellen.
      // Mehr Präzision dürfte nicht still eine andere Steuerbasis im XML ergeben.
      if LPosition.VatRate <> RoundedProduct(LPosition.VatRate, 1, 1) then
        raise EConvertError.CreateFmt('Der Steuersatz in Position %d darf höchstens zwei Nachkommastellen haben.', [I + 1]);
      LLine := Result.InvoiceLines.AddInvoiceLine;
      LLine.ID := IntToStr(I + 1);
      LLine.Name := LPosition.Description;
      LLine.Quantity := LPosition.Quantity;
      LUnitCode := UpperCase(Trim(LPosition.UnitCode));
      if LUnitCode = 'HAR' then
        LUnitCode := 'H18'; // Vom Adapter unterstützter Alias für Hektar.
      LLine.UnitCode := TXRechnungHelper.InvoiceUnitCodeFromStr(LUnitCode);
      // Der Adapter liefert bei unbekannten Codes still C62: Rückweg prüfen.
      if TXRechnungHelper.InvoiceUnitCodeToStr(LLine.UnitCode) <> LUnitCode then
        raise EConvertError.CreateFmt('Unbekannte Einheit "%s" in Position %d.', [LPosition.UnitCode, I + 1]);
      LLine.NetPriceAmount := LPosition.NetUnitPrice;
      LLine.GrossPriceAmount := LPosition.NetUnitPrice;
      LLine.DiscountOnTheGrossPrice := 0;
      LLine.BaseQuantity := 1;
      LLine.BaseQuantityUnitCode := LLine.UnitCode;
      LLine.LineAmount := RoundedProduct(LPosition.Quantity, LPosition.NetUnitPrice, 1);
      LLine.TaxPercent := LPosition.VatRate;
      if LPosition.VatRate = 0 then
        LLine.TaxCategory := idtfcc_Z_ZeroRatedGoods
      else
        LLine.TaxCategory := idtfcc_S_StandardRate;
      Result.LineAmount := Result.LineAmount + LLine.LineAmount;
      LTax := nil;
      for J := 0 to Result.TaxAmountSubtotals.Count - 1 do
      begin
        LRate := Result.TaxAmountSubtotals[J].TaxPercent;
        if LRate = LPosition.VatRate then
        begin
          LTax := Result.TaxAmountSubtotals[J];
          Break;
        end;
      end;
      if LTax = nil then
      begin
        LTax := Result.TaxAmountSubtotals.AddTaxAmount;
        LTax.TaxPercent := LPosition.VatRate;
        LTax.TaxCategory := LLine.TaxCategory;
      end;
      LTax.TaxableAmount := LTax.TaxableAmount + LLine.LineAmount;
    end;
    for J := 0 to Result.TaxAmountSubtotals.Count - 1 do
    begin
      LTax := Result.TaxAmountSubtotals[J];
      LRate := LTax.TaxPercent;
      LTax.TaxAmount := RoundedProduct(LTax.TaxableAmount, LRate, 100);
      Result.TaxAmountTotal := Result.TaxAmountTotal + LTax.TaxAmount;
    end;
    Result.TaxExclusiveAmount := Result.LineAmount;
    Result.TaxInclusiveAmount := Result.TaxExclusiveAmount + Result.TaxAmountTotal;
    Result.AllowanceTotalAmount := 0;
    Result.ChargeTotalAmount := 0;
    Result.PrepaidAmount := 0;
    Result.PayableRoundingAmount := 0;
    Result.PayableAmount := Result.TaxInclusiveAmount;
  except
    Result.Free;
    raise;
  end;
end;

procedure SaveInvoiceXml(AInvoice: TInvoice; const AFileName: string);
var
  LFileName: string;
begin
  if AInvoice = nil then
    raise EArgumentNilException.Create('Rechnung fehlt.');
  RequireText(AFileName, 'XML-Dateiname');
  LFileName := ExpandFileName(AFileName);
  // Der Adapter kehrt bei fehlendem Zielordner still zurück. Hier als Fehler
  // melden, damit niemals eine erfolgreiche Ablage ohne XML behauptet wird.
  if not DirectoryExists(ExtractFileDir(LFileName)) then
    raise EInOutError.Create('Der Zielordner für die XRechnung fehlt.');
  TXRechnungInvoiceAdapter.SaveToFile(AInvoice, XRechnungVersion_30x_UBL, LFileName);
end;

end.
