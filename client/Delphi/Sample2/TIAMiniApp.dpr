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

program TIAMiniApp;

uses
  Vcl.Forms,
  MiniApp.MainForm in 'MiniApp.MainForm.pas' {MiniAppMainForm},
  MiniApp.Model in 'MiniApp.Model.pas',
  MiniApp.Storage in 'MiniApp.Storage.pas',
  MiniApp.Service in 'MiniApp.Service.pas',
  MiniApp.InvoiceBuilder in 'MiniApp.InvoiceBuilder.pas';

// Wird beim IDE-/MSBuild-Projektbuild aus der .dproj erzeugt.
{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMiniAppMainForm, MiniAppMainForm);
  Application.Run;
end.
