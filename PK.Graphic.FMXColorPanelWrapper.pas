(*
 * FMX デフォルトの TColorPanel を同じように扱えるラッパークラス
 *
 * PLATFORMS
 *   Windows / macOS / iOS / Android
 *
 * LICENSE
 *   Copyright (c) 2025 HOSOKAWA Jun
 *   Released under the MIT license
 *   http://opensource.org/licenses/mit-license.php
 *
 * HISTROY
 *   2025/12/08 Version 1.1.0  First Release
 *
 * USAGE
 *   // Create Selector
 *   FSelector := TFMXColorPanelWrapper.Create(Self);
 *   FSelector.OnChange := ChangeHandler;
 *   FSelector.Parent := Self;
 *
 *   // Selector Color Change Event
 *   procedure ChangeHandler(Sender: TObject; const AColor: TAlphaColor);
 *   begin
 *     Label1.TextSettings.FontColor := AColor;
 *   end;
 *
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Graphic.FMXColorPanelWrapper;

interface

uses
  System.Classes
  , System.Types
  , System.SysUtils
  , System.UITypes
  , FMX.Colors
  , FMX.Graphics
  , FMX.Types
  , PK.Graphic.ColorSelectors
  ;

type
  TFMXColorPanelWrapper = class(TCustomSelector)
  private var
    FColorPanel: TColorPanel;
  private
    procedure ColorPanelChangeHandler(Sender: TObject);
    function GetAlphaEnabled: Boolean;
    procedure SetAlphaEnabled(const AValue: Boolean);
  protected
    procedure MouseEventImpl(const AX, AY: Single); override;
    procedure SetColor(const AColor: TAlphaColor); override;
  public
    constructor Create(AOwner: TComponent); override;
    property AlphaEnabled: Boolean read GetAlphaEnabled write SetAlphaEnabled;
  end;


implementation

{ TFMXColorPanelWrapper }

procedure TFMXColorPanelWrapper.ColorPanelChangeHandler(Sender: TObject);
begin
  FColor := FColorPanel.Color;
  DoChange;
end;

constructor TFMXColorPanelWrapper.Create(AOwner: TComponent);
begin
  inherited;

  FColorPanel := TColorPanel.Create(Self);
  FColorPanel.UseAlpha := False;
  FColorPanel.Align := TAlignLayout.Client;
  FColorPanel.OnChange := ColorPanelChangeHandler;
  FColorPanel.Parent := Self;
end;

function TFMXColorPanelWrapper.GetAlphaEnabled: Boolean;
begin
  Result := FColorPanel.UseAlpha;
end;

procedure TFMXColorPanelWrapper.MouseEventImpl(const AX, AY: Single);
begin
end;

procedure TFMXColorPanelWrapper.SetAlphaEnabled(const AValue: Boolean);
begin
  FColorPanel.UseAlpha := AValue;
end;

procedure TFMXColorPanelWrapper.SetColor(const AColor: TAlphaColor);
begin
  inherited;

  FColorPanel.Color := AColor;
end;

end.
