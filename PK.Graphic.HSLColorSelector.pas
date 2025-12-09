(*
 * FMX の機能のみで構築した HSL カラー選択
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
 *   2025/12/09 Version 1.1.1  First Release
 *   2025/12/09 Version 1.1.1  HSL Support / Circle Speedup
 *
 * USAGE
 *   // Create Selector
 *   FSelector := TFMXColorSelector.Create(Self);
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

unit PK.Graphic.HSLColorSelector;

interface

uses
  System.Classes
  , System.Types
  , System.SysUtils
  , System.UITypes
  , FMX.Colors
  , FMX.Graphics
  , FMX.Layouts
  , FMX.Types
  , PK.Graphic.ColorSelectors
  ;

type
  THSLColorSelector = class(TCustomSelector)
  private const
    HUE_WIDTH = 20;
    MARGIN = 8;
  private var
    FQuad: TColorQuad;
    FHue: TColorPicker;
    FLayout: TLayout;
  private
    procedure QuadChangeHandler(Sender: TObject);
  protected
    procedure MouseEventImpl(const AX, AY: Single); override;
    procedure SetColor(const AColor: TAlphaColor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  System.UIConsts;

{ THSLColorSelector }

constructor THSLColorSelector.Create(AOwner: TComponent);
begin
  inherited;

  FLayout := TLayout.Create(Self);
  FLayout.Padding.Rect := RectF(MARGIN, MARGIN, MARGIN, MARGIN);
  FLayout.Align := TAlignLayout.Client;

  FQuad := TColorQuad.Create(Self);
  FQuad.Align := TAlignLayout.Client;
  FQuad.ClipChildren := True;
  FQuad.Parent := FLayout;
  FQuad.OnChange := QuadChangeHandler;

  FHue := TColorPicker.Create(Self);
  FHue.Align := TAlignLayout.Right;
  FHue.Margins.Left := MARGIN;
  FHue.Width := HUE_WIDTH;
  FHue.ColorQuad := FQuad;
  FHue.ClipChildren := True;
  FHue.Parent := FLayout;

  FLayout.Parent := Self;
end;

procedure THSLColorSelector.MouseEventImpl(const AX, AY: Single);
begin
end;

procedure THSLColorSelector.QuadChangeHandler(Sender: TObject);
begin
  var Color := HSLtoRGB(FHue.Hue, FQuad.Sat, FQuad.Lum) and $00_ff_ff_ff;
  var Alpha := Trunc(FQuad.Alpha * $ff) shl 24;

  FColor := Alpha or Color;

  DoChange;
end;

procedure THSLColorSelector.SetColor(const AColor: TAlphaColor);
begin
  inherited;
  FHue.Color := AColor;
end;

end.

