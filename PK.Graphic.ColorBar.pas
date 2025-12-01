(*
 * Color 指定用スライダー
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
 *   2025/12/01 Version 1.0.0  First Release
 *
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Graphic.ColorBar;

interface

uses
  System.SysUtils
  , System.Classes
  , System.UITypes
  , System.Types
  , FMX.Controls
  , FMX.Graphics
  , FMX.StdCtrls
  , FMX.Objects
  , FMX.Types
  ;

type
  TColorChangeEvent =
    procedure(Sender: TObject; const AColor: TAlphaColor) of object;

  TCustomColorBar = class(TControl)
  private const
    VALUE_MIN = 0;
    VALUE_MAX = 255;
    VALUE_RANGE = VALUE_MAX - VALUE_MIN;

    MARGIN_NAME = 2;
    MARGIN_VALUE = 4;

    DELTA_KEY_UPDOW = 8;
  private var
    FValue: Integer;
    FColorName: TLabel;
    FValueText: TLabel;
    FBarBase: TPanel;
    FBack: TRectangle;
    FBar: TRectangle;
    FOnChange: TNotifyEvent;
  private
    procedure SetValue(const AValue: Integer);
    procedure CalcPos(const AX: Single);
    function CalcBarMaxWidth: Single;
    procedure CalcBarCorner;
    procedure UpdateSize;
    procedure BarBaseApplyStyleLookupHandler(Sender: TObject);
  protected
    procedure Resize; override;
    procedure SetVisible(const AValue: Boolean); override;
    function GetColor: TAlphaColor; virtual; abstract;
    function GetColorName: String; virtual; abstract;
    procedure KeyDown(
      var AKey: Word;
      var AKeyChar: WideChar;
      AShift: TShiftState); override;
    procedure MouseDown(
      AButton: TMouseButton;
      AShift: TShiftState;
      AX, AY: Single); override;
    procedure MouseMove(AShift: TShiftState; AX, AY: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetNewScene(AScene: IScene); override;
    procedure SetValueWithoutEvent(const AValue: Integer);
    property Value: Integer read FValue write SetValue;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TRBar = class(TCustomColorBar)
  protected
    function GetColor: TAlphaColor; override;
    function GetColorName: String; override;
  end;

  TGBar = class(TCustomColorBar)
  protected
    function GetColor: TAlphaColor; override;
    function GetColorName: String; override;
  end;

  TBBar = class(TCustomColorBar)
  protected
    function GetColor: TAlphaColor; override;
    function GetColorName: String; override;
  end;

  TABar = class(TCustomColorBar)
  private const
    A_MIN = $40_00_00_00;
  protected
    function GetColor: TAlphaColor; override;
    function GetColorName: String; override;
  end;

  TRGBBars = class(TControl)
  private var
    FABar: TABar;
    FRBar: TRBar;
    FGBar: TGBar;
    FBBar: TBBar;
    FColor: TAlphaColor;
    FOnChange: TColorChangeEvent;
  private
    procedure SetColor(const AColor: TAlphaColor);
    procedure BarChangeHandler(Sender: TObject);
    function GetAlphaEnabled: Boolean;
    procedure SetAlphaEnabled(const AValue: Boolean);
  protected
    procedure Resize; override;
    function CreateBar<T: TCustomColorBar>(const AAlign: TAlignLayout): T;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetColorWithoutEvent(const AColor: TAlphaColor);
  published
    property Color: TAlphaColor read FColor write SetColor;
    property AlphaEnabled: Boolean read GetAlphaEnabled write SetAlphaEnabled;
    property OnChange: TColorChangeEvent read FOnChange write FOnChange;
  end;

implementation

uses
  System.Math
  , PK.Utils.Font
  ;

{ TCustomColorBar }

procedure TCustomColorBar.BarBaseApplyStyleLookupHandler(Sender: TObject);
begin
  UpdateSize;
end;

procedure TCustomColorBar.CalcBarCorner;
begin
  var PL := FBarBase.Padding.Left;
  var PR := FBarBase.Padding.Right;

  var D := FBarBase.Width - FBar.Width - PL - PR;
  var C: TCorners := [TCorner.TopLeft, TCorner.BottomLeft];

  if D < (FBar.XRadius / 2) then
    C := C + [TCorner.TopRight, TCorner.BottomRight];

  FBar.Corners := C;
end;

function TCustomColorBar.CalcBarMaxWidth: Single;
begin
  Result := FBarBase.Width - FBarBase.Padding.Right - FBarBase.Padding.Left;
end;

procedure TCustomColorBar.CalcPos(const AX: Single);
begin
  var W := CalcBarMaxWidth;
  if W = 0 then
    Exit;

  var V := EnsureRange(AX - FBarBase.Position.X + FBarBase.Padding.Left, 0, W);
  SetValue(Trunc(V * VALUE_RANGE / W));
end;

constructor TCustomColorBar.Create(AOwner: TComponent);
begin
  inherited;

  SetSize(160, 16);

  AutoCapture := True;
  CanFocus := True;

  FColorName := TLabel.Create(Self);
  FColorName.Align := TAlignLayout.Left;
  FColorName.HitTest := False;
  FColorName.WordWrap := False;
  FColorName.Text := GetColorName;

  FValueText := TLabel.Create(Self);
  FValueText.Align := TAlignLayout.Right;
  FValueText.HitTest := False;
  FValueText.WordWrap := False;
  FValueText.TextSettings.HorzAlign := TTextAlign.Trailing;
  FValueText.Font.Family := TFontUtils.GetMonospaceFont;
  FValueText.StyledSettings := [TStyledSetting.Style, TStyledSetting.FontColor];

  FBarBase := TPanel.Create(Self);
  FBarBase.Align := TAlignLayout.Client;
  FBarBase.HitTest := False;
  FBarBase.ClipChildren := True;
  FBarBase.OnApplyStyleLookup := BarBaseApplyStyleLookupHandler;

  FBack := TRectangle.Create(Self);
  FBack.Align := TAlignLayout.Contents;
  FBack.HitTest := False;
  FBack.Stroke.Kind := TBrushKind.None;
  FBack.Fill.Color := TAlphaColors.White;
  FBack.Parent := FBarBase;

  FBar := TRectangle.Create(Self);
  FBar.Align := TAlignLayout.Left;
  FBar.HitTest := False;
  FBar.Stroke.Kind := TBrushKind.None;
  FBar.Fill.Color := GetColor;
  FBar.Parent := FBarBase;

  FColorName.Parent := Self;
  FValueText.Parent := Self;
  FBarBase.Parent := Self;
end;

procedure TCustomColorBar.KeyDown(
  var AKey: Word;
  var AKeyChar: WideChar;
  AShift: TShiftState);
begin
  inherited;

  case AKey of
    vkLeft:
      SetValue(FValue - 1);
    vkUp:
      SetValue(FValue + DELTA_KEY_UPDOW);
    vkRight:
      SetValue(FValue + 1);
    vkDown:
      SetValue(FValue - DELTA_KEY_UPDOW);
  end;
end;

procedure TCustomColorBar.MouseDown(
  AButton: TMouseButton;
  AShift: TShiftState;
  AX, AY: Single);
begin
  inherited;

  CalcPos(AX);
  SetFocus;
end;

procedure TCustomColorBar.MouseMove(AShift: TShiftState; AX, AY: Single);
begin
  inherited;

  if Pressed then
    CalcPos(AX);
end;

procedure TCustomColorBar.Resize;
begin
  inherited;
  UpdateSize;
end;

procedure TCustomColorBar.SetNewScene(AScene: IScene);
begin
  inherited;
  UpdateSize;
end;

procedure TCustomColorBar.SetValue(const AValue: Integer);
begin
  if FValue = AValue then
    Exit;

  SetValueWithoutEvent(AValue);

  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TCustomColorBar.SetValueWithoutEvent(const AValue: Integer);
begin
  FValue := EnsureRange(AValue, VALUE_MIN, VALUE_MAX);

  var W := CalcBarMaxWidth;
  FBar.Width:= W * FValue / VALUE_RANGE;
  CalcBarCorner;

  FValueText.Text := Format('%2d/%.2x', [FValue, FValue]);

  FBar.Fill.Color := GetColor;
end;

procedure TCustomColorBar.SetVisible(const AValue: Boolean);
begin
  inherited;
  SetValueWithoutEvent(FValue);
end;

procedure TCustomColorBar.UpdateSize;

  function FindBack(const AObject: TFmxObject): TRectangle;
  begin
    Result := nil;
    if AObject = nil then
      Exit;

    if AObject is TRectangle then
      Result := TRectangle(AObject)
    else
    begin
      for var C in AObject.Children do
      begin
        var Res := FindBack(C);
        if Res <> nil then
        begin
          Result := Res;
          Break;
        end;
      end;
    end;
  end;

begin
  if (Canvas = nil) or (Scene = nil) then
    Exit;

  FColorName.Width := Canvas.TextWidth('W') + MARGIN_NAME;

  {$IFDEF ANDROID}
  FValueText.Width := Canvas.TextWidth('0000000') + MARGIN_VALUE;
  {$ELSE}
  FValueText.Width := Canvas.TextWidth('000000') + MARGIN_VALUE;
  {$ENDIF}

  var MTop := (Height - Canvas.TextHeight('H')) / 2;
  FColorName.Margins.Top := MTop;
  FValueText.Margins.Top := MTop;

  var S := Scene.GetSceneScale;
  var R := RectF(S, S, S, S);
  FBarBase.Padding.Rect := R;
  FBack.Margins.Rect := R;

  var BackR := FindBack(FBarBase);

  if BackR <> nil then
  begin
    FBack.XRadius := BackR.XRadius;
    FBack.YRadius := BackR.YRadius;

    FBar.XRadius := BackR.XRadius;
    FBar.YRadius := BackR.YRadius;
  end;

  SetValue(FValue);
end;

{ TRBar }

function TRBar.GetColorName: String;
begin
  Result := 'R';
end;

function TRBar.GetColor: TAlphaColor;
begin
  Result := TAlphaColors.Red;
end;

{ TGBar }

function TGBar.GetColorName: String;
begin
  Result := 'G';
end;

function TGBar.GetColor: TAlphaColor;
begin
  Result := TAlphaColors.Green;
end;

{ TBBar }

function TBBar.GetColorName: String;
begin
  Result := 'B';
end;

function TBBar.GetColor: TAlphaColor;
begin
  Result := TAlphaColors.Blue;
end;

{ TABar }

function TABar.GetColor: TAlphaColor;
begin
  Result := Max(A_MIN, UInt32($ff * FValue div VALUE_RANGE) shl 24);
end;

function TABar.GetColorName: String;
begin
  Result := 'A';
end;

{ TRGBBars }

procedure TRGBBars.BarChangeHandler(Sender: TObject);
var
  C: TAlphaColor;
  Rec: TAlphaColorRec absolute C;
begin
  Rec.A := FABar.Value;
  Rec.R := FRBar.Value;
  Rec.G := FGBar.Value;
  Rec.B := FBBar.Value;

  SetColor(C);
end;

constructor TRGBBars.Create(AOwner: TComponent);
begin
  inherited;

  SetSize(180, 80);

  FABar := CreateBar<TABar>(TAlignLayout.MostTop);
  FRBar := CreateBar<TRBar>(TAlignLayout.Top);
  FGBar := CreateBar<TGBar>(TAlignLayout.Bottom);
  FBBar := CreateBar<TBBar>(TAlignLayout.MostBottom);

  FABar.Visible := False;

  SetColorWithoutEvent($ff_00_00_00);
end;

function TRGBBars.CreateBar<T>(const AAlign: TAlignLayout): T;
begin
  Result := T.Create(Self);
  Result.Align := AAlign;
  Result.OnChange := BarChangeHandler;
  Result.Parent := Self;
end;

destructor TRGBBars.Destroy;
begin
  FBBar.Free;
  FGBar.Free;
  FRBar.Free;
  FABar.Free;

  inherited;
end;

function TRGBBars.GetAlphaEnabled: Boolean;
begin
  Result := FABar.Visible;
end;

procedure TRGBBars.Resize;
begin
  inherited;

  if FABar = nil then
    Exit;

  var H := Height - FRBar.Height - FGBar.Height - FBBar.Height;
  var Denom := 2;

  if FABar.Visible then
  begin
    H := H - FABar.Height;
    Inc(Denom);
  end;

  var DH := H / Denom;

  FABar.Margins.Bottom := DH;
  FBBar.Margins.Top := DH;
end;

procedure TRGBBars.SetAlphaEnabled(const AValue: Boolean);
begin
  if FABar.Visible = AValue then
    Exit;

  FABar.Visible := AValue;

  Resize;
end;

procedure TRGBBars.SetColor(const AColor: TAlphaColor);
begin
  if FColor = AColor then
    Exit;

  SetColorWithoutEvent(AColor);

  if Assigned(FOnChange) then
    FOnChange(Self, FColor);
end;

procedure TRGBBars.SetColorWithoutEvent(const AColor: TAlphaColor);
var
  Rec: TAlphaColorRec absolute AColor;
begin
  FColor := AColor;

  FABar.SetValueWithoutEvent(Rec.A);
  FRBar.SetValueWithoutEvent(Rec.R);
  FGBar.SetValueWithoutEvent(Rec.G);
  FBBar.SetValueWithoutEvent(Rec.B);
end;

end.
