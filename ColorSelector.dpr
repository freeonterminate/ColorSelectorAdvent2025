program ColorSelector;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas' {frmSelector},
  PK.Graphic.ColorSelectors in 'PK.Graphic.ColorSelectors.pas',
  PK.Graphic.DDA in 'Lib\PK.Graphic.DDA.pas',
  PK.Graphic.ColorConverter in 'Lib\PK.Graphic.ColorConverter.pas',
  PK.Math.AdjustUtils in 'Lib\PK.Math.AdjustUtils.pas',
  PK.Graphic.HSVSelectors in 'PK.Graphic.HSVSelectors.pas',
  PK.Graphic.CellSelectors in 'PK.Graphic.CellSelectors.pas',
  PK.Graphic.ColorBar in 'PK.Graphic.ColorBar.pas',
  PK.Utils.Font in 'Lib\PK.Utils.Font.pas',
  PK.Graphic.FMXColorPanelWrapper in 'PK.Graphic.FMXColorPanelWrapper.pas',
  PK.Graphic.HSLColorSelector in 'PK.Graphic.HSLColorSelector.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmSelector, frmSelector);
  Application.Run;
end.
