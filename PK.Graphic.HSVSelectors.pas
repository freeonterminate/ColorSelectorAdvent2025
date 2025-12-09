(*
 * HSV Color Selector クラス
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
 *   2025/12/08 Version 1.1.0  FMX ColorPanel Support
 *   2025/12/09 Version 1.1.1  HSL Support / Circle Speedup
 *
 * USAGE
 *   // Create Selector
 *   FSelector := TCircleSelector.Create(Self);
 *   FSelector.OnChange := ChangeHandler;
 *   FSelector.Parent := AParent;
 *
 *   // Selector Color Change Event
 *   procedure ChangeHandler(Sender: TObject; const AColor: TAlphaColor);
 *   begin
 *     Label1.TextSettings.FontColor := AColor;
 *   end;
 *
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Graphic.HSVSelectors;

interface

uses
  System.Classes
  , System.Types
  , System.SysUtils
  , System.UITypes
  , FMX.Graphics
  , FMX.Types
  , PK.Graphic.ColorSelectors
  ;

type
  THueCursor = class;
  TSVCursor = class;
  TRectCursor = class;

  THSVSelector = class(TCustomSelector)
  private var
    FHue: Single;
    FSaturation: Single;
    FValue: Single;
  private
    procedure SetHue(const AValue: Single);
    procedure SetValue(const AValue: Single);
    procedure SetSaturation(const AValue: Single);
  protected
    procedure Resize; override;
    procedure ResizeImpl; virtual; abstract;

    procedure CalcColor;
    procedure SetHSV(const AHue, ASaturation, AValue: Single);

    procedure Draw(const ACanvas: TCanvas); override;
    procedure DrawImpl(
      const ACanvas: TCanvas;
      const AData: TBitmapData); virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    property Hue: Single read FHue write SetHue;
    property Saturation: Single read FSaturation write SetSaturation;
    property Value: Single read FValue write SetValue;
  end;

  TCircleSelector = class(THSVSelector)
  private const
    MARGIN = 8;
    DOUBLE_MARGIN = MARGIN * 2;
    OUTER_CIRCLE_RATIO = 7;
    INNER_CIRCLE_RATIO = OUTER_CIRCLE_RATIO - 2;
    // アンチエイリアスの幅
    AA_WIDTH = 1;
    // 枠線の太さ
    LINE_WIDTH = 1.0;
  private var
    FDiameter: Integer;
    FRadius: Integer;
    FInnerDiameter: Integer;
    FInnerRadius: Integer;
    FInnerDelta: Integer;
    FHueRadius: Integer;
    FLeftMargin: Integer;
    FTopMargin: Integer;
    FCX: Integer;
    FCY: Integer;
    FTriP0: TPoint;
    FTriP1: TPoint;
    FTriP2: TPoint;
    FTriRect: TRect;
    FTriDenom: Integer;
    FHueCursor: THueCursor;
    FSVCursor: TSVCursor;
    FInHueCircle: Boolean;
    FInSVTriangle: Boolean;
  private
    function CalcBarycentric(
      const AX, AY: Single;
      out AW0, AW1, AW2: Single): Boolean;
    function IsInHueCircle(const AX, AY: Single): Boolean;
    function IsInSVTriangle(const AX, AY: Single): Boolean;

    function GetColorByPos(const AX, AY: Integer): TAlphaColor;

    procedure DrawCircle(const ACanvas: TCanvas; const AData: TBitmapData);
    procedure DrawTriangle(const ACanvas: TCanvas; const AData: TBitmapData);
    procedure RedrawTriangle;
  protected
    procedure ResizeImpl; override;

    procedure DrawImpl(
      const ACanvas: TCanvas;
      const AData: TBitmapData); override;

    procedure SetColor(const AColor: TAlphaColor); override;

    procedure MouseDown(
      AButton: TMouseButton;
      AShift: TShiftState;
      AX, AY: Single); override;
    procedure MouseEventImpl(const AX, AY: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TRectSelector = class(THSVSelector)
  private const
    CURSOR_SIZE = 14;
  private var
    FCursor: TRectCursor;
  protected
    procedure ResizeImpl; override;

    procedure DrawImpl(
      const ACanvas: TCanvas;
      const AData: TBitmapData); override;

    procedure SetColor(const AColor: TAlphaColor); override;

    procedure MouseEventImpl(const AX, AY: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // カーソル
  THueCursor = class(TSelectorCursor)
  private const
    CURSOR_MARGIN = 2;
  protected
    procedure MoveTo(const AX, AY: Single); override;
  end;

  TSVCursor = class(TSelectorCursor)
  protected
    procedure MoveTo(const AX, AY: Single); override;
  end;

  TRectCursor = class(TSelectorCursor)
  protected
    procedure MoveTo(const AX, AY: Single); override;
  end;

implementation

uses
  System.Math
  , System.Threading
  , PK.Graphic.ColorConverter
  ;

{ THSVSelector }

procedure THSVSelector.CalcColor;
begin
  FColor := HSV2RGB(FHue, FSaturation, FValue);
  DoChange;
end;

constructor THSVSelector.Create(AOwner: TComponent);
begin
  inherited;

  AutoCapture := True;

  FHue := 0;
  FSaturation := 1;
  FValue := 1;

  CalcColor;
end;

procedure THSVSelector.Draw(const ACanvas: TCanvas);
begin
  inherited;

  var Data: TBitmapData;

  Base.Map(TMapAccess.ReadWrite, Data);
  try
    DrawImpl(ACanvas, Data);
  finally
    Base.Unmap(Data);
  end;
end;

procedure THSVSelector.Resize;
begin
  inherited;

  ResizeImpl;
  StartDraw;
end;

procedure THSVSelector.SetHSV(const AHue, ASaturation, AValue: Single);
begin
  FHue := AHue;
  FSaturation := ASaturation;
  FValue := AValue;
  CalcColor;
end;

procedure THSVSelector.SetHue(const AValue: Single);
begin
  if FHue = AValue then
    Exit;

  SetHSV(AValue, FSaturation, FValue);
end;

procedure THSVSelector.SetSaturation(const AValue: Single);
begin
  if FSaturation = AValue then
    Exit;

  SetHSV(FHue, AValue, FValue);
end;

procedure THSVSelector.SetValue(const AValue: Single);
begin
  if FValue = AValue then
    Exit;

  SetHSV(FHue, FSaturation, AValue);
end;

{ TCircleSelector }

function TCircleSelector.CalcBarycentric(
  const AX, AY: Single;
  out AW0, AW1, AW2: Single): Boolean;
begin
  // 三角形が成立していない場合
  if FTriDenom = 0 then
  begin
    AW0 := -1;
    AW1 := -1;
    AW2 := -1;
    Exit(False);
  end;

  // バリセントリック計算 (P2を基準点とした式)
  AW0 :=
    (
      (FTriP1.Y - FTriP2.Y) * (AX - FTriP2.X) +
      (FTriP2.X - FTriP1.X) * (AY - FTriP2.Y)
    ) / FTriDenom;

  AW1 :=
    (
      (FTriP2.Y - FTriP0.Y) * (AX - FTriP2.X) +
      (FTriP0.X - FTriP2.X) * (AY - FTriP2.Y)
    ) / FTriDenom;

  AW2 := 1 - AW0 - AW1;

  Result := True;
end;

constructor TCircleSelector.Create(AOwner: TComponent);
begin
  inherited;

  FHueCursor := THueCursor.Create(Self);
  FSVCursor := TSVCursor.Create(Self);

  FHueCursor.Parent := Self;
  FSVCursor.Parent := Self;
end;

destructor TCircleSelector.Destroy;
begin
  FSVCursor.Free;
  FHueCursor.Free;

  inherited;
end;

procedure TCircleSelector.DrawCircle(
  const ACanvas: TCanvas;
  const AData: TBitmapData);
begin
  var W := AData.Width;
  var H := AData.Height;

  for var Y := 0 to H - 1 do
  begin
    for var X := 0 to W - 1 do
    begin
      var DX := X - FCX;
      var DY := Y - FCY;
      var D := Sqrt(DX * DX + DY * DY); // 中心からの距離

      // 1. 色相環の本体領域外のピクセルは背景色を塗る
      if (D >= FRadius + AA_WIDTH) or (D <= FInnerRadius - AA_WIDTH) then
      begin
        AData.SetPixel(X, Y, BaseColor);
        Continue;
      end;

      // 2. 色相環の色と背景色を取得
      var FRC := TAlphaColorRec(GetColorByPos(DX, DY));

      var OuterBlend := 1.0; // 0.0 (外側) から 1.0 (内側)
      var InnerBlend := 1.0; // 0.0 (穴の内側) から 1.0 (色相環の内側)

      // 3. 外周のアンチエイリアス処理
      if D > FRadius - AA_WIDTH then // 外周のブレンド領域内
      begin
        // D = FRadius + AA_WIDTH で 0.0 (完全に外側)
        // D = FRadius - AA_WIDTH で 1.0 (完全に内側)
        OuterBlend :=
          EnsureRange((FRadius + AA_WIDTH - D) / (AA_WIDTH * 2), 0, 1);
      end;

      // 4. 内周のアンチエイリアス処理
      if D < FInnerRadius + AA_WIDTH then // 内周のブレンド領域内
      begin
        // D = R_inner - AA_WIDTH で 0.0 (穴の内側、色が塗られない)
        // D = R_inner + AA_WIDTH で 1.0 (色相環の内側、完全に色が塗られる)
        InnerBlend :=
          EnsureRange((D - (FInnerRadius - AA_WIDTH)) / (AA_WIDTH * 2), 0, 1);
      end;

      // 5. アルファ値の計算 (両方の境界の影響を受ける)
      var Alpha := OuterBlend * InnerBlend;

      if Alpha > 0.001 then // ほぼ 0 でなければ描画
      begin
        var A := Trunc(Alpha * 255);

        // 背景色 (FBaseColor) と HueColor をブレンド
        var BackR :=  TAlphaColorRec(BaseColor).R;
        var BackG :=  TAlphaColorRec(BaseColor).G;
        var BackB :=  TAlphaColorRec(BaseColor).B;

        var ForeR := FRC.R;
        var ForeG := FRC.G;
        var ForeB := FRC.B;

        // アルファブレンド計算: C_final = C_fore * alpha + C_back * (1 - alpha)
        var R := (ForeR * A + BackR * (255 - A)) div 255;
        var G := (ForeG * A + BackG * (255 - A)) div 255;
        var B := (ForeB * A + BackB * (255 - A)) div 255;

        var FinalColor: TAlphaColorRec;
        FinalColor.R := R;
        FinalColor.G := G;
        FinalColor.B := B;
        FinalColor.A := 255;

        AData.SetPixel(X, Y, TAlphaColor(FinalColor));
      end;
    end;
  end;
end;

procedure TCircleSelector.DrawImpl(
  const ACanvas: TCanvas;
  const AData: TBitmapData);
begin
  DrawCircle(ACanvas, AData);
  DrawTriangle(ACanvas, AData);
end;

procedure TCircleSelector.DrawTriangle(
  const ACanvas: TCanvas;
  const AData: TBitmapData);
type
  TAlphaColorArray = packed array [0.. 0] of TAlphaColor;
  PAlphaColorArray = ^TAlphaColorArray;
  TDrawX = reference to procedure (const AY: Integer);
var
  TriArea: Single;
  D: Single;
  DH: Single;
  BorderColor: TAlphaColor;
  SY: Integer;
  EY: Integer;
  SX: Integer;
  EX: Integer;
  Base: PByte;
begin
  const DrawX: TDrawX =
    procedure (const AY: Integer)
    var
      // ループ内で使う変数
      W0, W1, W2: Single;
      MinDist: Single;
      V, S: Single;
      BorderRatio: Single;
      Alpha: Single;
      FinalColor: TAlphaColor;

      // カラーブレンド用
      function BlendColor(
        const AC1, AC2: TAlphaColor;
        const AT: Single): TAlphaColor; inline;
      var
        R1: TAlphaColorRec absolute AC1;
        R2: TAlphaColorRec absolute AC2;
        Res: TAlphaColorRec absolute Result;
      begin
        if AT <= 0 then
          Exit(AC1);

        if AT >= 1 then
          Exit(AC2);

        var InvT := 1 - AT;

        Res.R := Round(R1.R * InvT + R2.R * AT);
        Res.G := Round(R1.G * InvT + R2.G * AT);
        Res.B := Round(R1.B * InvT + R2.B * AT);
        Res.A := 255;
      end;

    begin
      var Line := PAlphaColorArray(Base + AY * AData.Pitch);

      for var X := SX to EX do
      begin
        if not CalcBarycentric(X, AY, W0, W1, W2) then
          Continue;

        // ピクセル単位でのエッジからの距離を計算
        MinDist := MinValue([W0 * DH, W1 * DH, W2 * DH]);

        // エッジから AA_WIDTH 分だけ外側(-AA_WIDTH)までを描画対象とする
        if MinDist > -AA_WIDTH then
        begin
          // 中身の色（HSV）を決定
          V := EnsureRange(W0 + W1, 0, 1);
          S := 0.0;
          if V > 0 then
            S := EnsureRange(W0 / V, 0, 1);

          FinalColor := $ff_00_00_00 or HSV2RGB(FHue, S, V);

          // 枠線と中身の合成
          if MinDist < LINE_WIDTH then
          begin
            // 枠線領域
            BorderRatio := EnsureRange((LINE_WIDTH - MinDist) * 2, 0, 1);
            FinalColor := BlendColor(FinalColor, BorderColor, BorderRatio);
          end;

          // 最外周のアンチエイリアス (背景との合成用アルファ値決定)
          if MinDist < 0.5 then
          begin
            // MinDist が -0.5 ～ 0.5 の範囲を 0.0 ～ 1.0 にマップ
            Alpha := EnsureRange(MinDist + 0.5, 0, 1);
            FinalColor := BlendColor(BaseColor, FinalColor, Alpha);
          end;

          // ピクセル描画
          {$R-}
          Line[X] := FinalColor;
          {$R+}
        end;
      end;
    end;

  // 重心座標(W)をピクセル距離に変換するための係数を計算する
  TriArea := 0.5 * Abs(
    FTriP0.X * (FTriP1.Y - FTriP2.Y) +
    FTriP1.X * (FTriP2.Y - FTriP0.Y) +
    FTriP2.X * (FTriP0.Y - FTriP1.Y)
  );

  // 面積が極端に小さい場合は描画しない
  if TriArea < 1 then
    Exit;

  // 各頂点に対応する辺（対辺）からの高さ H = 2 * Area / 底辺長
  // これにより、距離(px) = W * H となる
  D := Sqrt(Sqr(FTriP1.X - FTriP2.X) + Sqr(FTriP1.Y - FTriP2.Y));
  DH := (2 * TriArea) / Max(1.0, D);

  // 枠線の色
  BorderColor := BaseColor xor $00_ff_ff_ff;

  SY := Max(FTriRect.Top, 0);
  EY := Min(FTriRect.Bottom, AData.Height - 1);

  SX := Max(FTriRect.Left, 0);
  EX := Min(FTriRect.Right, AData.Width - 1);

  Base := AData.Data;

  if
    TOSVersion.Platform in [
      TOSVersion.TPlatform.pfWindows,
      TOSVersion.TPlatform.pfMacOS
    ]
  then
  begin
    TParallel.For(
      SY,
      EY,
      procedure(AY: Integer)
      begin
        DrawX(AY);
      end
    );
  end
  else
  begin
    for var Y := SY to EY do
      DrawX(Y);
  end;
end;

function TCircleSelector.GetColorByPos(const AX, AY: Integer): TAlphaColor;
begin
  var Hue: Single;
  if (AX = 0) and (AY = 0) then
    Hue := 0.0
  else
    Hue := RadToDeg(ArcTan2(AY, AX));

  Result := HSV2RGB(Hue, 1, 1);
end;

function TCircleSelector.IsInHueCircle(const AX, AY: Single): Boolean;
begin
  // 中心からの相対座標
  var DX := AX - FCX;
  var DY := AY - FCY;

  var Dist2 := DX * DX + DY * DY;

  // 半径の2乗
  var Inner2 := FInnerRadius * FInnerRadius;
  var Outer2 := FRadius * FRadius;

  // 内側の円の外、かつ外側の円の内側 → 色相環上
  Result := (Dist2 >= Inner2) and (Dist2 <= Outer2);
end;

function TCircleSelector.IsInSVTriangle(const AX, AY: Single): Boolean;
begin
  var W0, W1, W2: Single;
  if CalcBarycentric(AX, AY, W0, W1, W2) then
    Result := (W0 >= 0) and (W1 >= 0) and (W2 >= 0)
  else
    Result := False;
end;

procedure TCircleSelector.MouseDown(
  AButton: TMouseButton;
  AShift: TShiftState;
  AX, AY: Single);
begin
  FInHueCircle := IsInHueCircle(AX, AY);
  FInSVTriangle := IsInSVTriangle(AX, AY);

  inherited;
end;

procedure TCircleSelector.MouseEventImpl(const AX, AY: Single);
begin
  if not Pressed then
    Exit;

  if FInHueCircle then
    FHueCursor.MoveTo(AX, AY);

  if FInSVTriangle then
    FSVCursor.MoveTo(AX, AY);
end;

procedure TCircleSelector.RedrawTriangle;
begin
  // Triangle のみを再描画
  var Data: TBitmapData;
  Base.Map(TMapAccess.ReadWrite, Data);
  try
    DrawTriangle(Base.Canvas, Data);
  finally
    Base.Unmap(Data);
  end;

  Invalidate;
end;

procedure TCircleSelector.ResizeImpl;

  function CalcTriPos(const AAngle: Single): TPoint;
  begin
    var S, C: Single;
    SinCos(DegToRad(AAngle), S, C);

    Result.X := FCX + Trunc(FInnerRadius * C);
    Result.Y := FCY + Trunc(FInnerRadius * S);
  end;

begin
  inherited;

  var W := Base.Width;
  var H := Base.Height;

  FDiameter := Min(W, H) - DOUBLE_MARGIN;
  FRadius := FDiameter div 2;

  FLeftMargin := Trunc((Width - FDiameter) / 2) - MARGIN;
  FTopMargin := Trunc((Height - FDiameter) / 2) - MARGIN;

  FCX := MARGIN + FRadius + FLeftMargin;
  FCY := MARGIN + FRadius + FTopMargin;

  // 円と三角形のパラメータ
  FInnerDelta := FDiameter div OUTER_CIRCLE_RATIO;
  FInnerDiameter := FInnerDelta * INNER_CIRCLE_RATIO;
  FInnerRadius := FInnerDiameter div 2;

  // 頂点定義: P0=純色(右), P1=白(左下), P2=黒(左上)
  FTriP0 := CalcTriPos(0);
  FTriP1 := CalcTriPos(-120);
  FTriP2 := CalcTriPos(120);

  // 三角形に外接する四角形 (描画範囲)
  FTriRect.Left := Min(FTriP1.X, FTriP2.X);
  FTriRect.Right := FTriP0.X;
  FTriRect.Top := Min(FTriP1.Y, FTriP2.Y);
  FTriRect.Bottom := Max(FTriP1.Y, FTriP2.Y);

  // 分母の計算
  FTriDenom :=
    (FTriP1.Y - FTriP2.Y) * (FTriP0.X - FTriP2.X) +
    (FTriP2.X - FTriP1.X) * (FTriP0.Y - FTriP2.Y);

  // カーソル
  FHueRadius := FInnerRadius + FInnerDelta div 2;

  FHueCursor.Update(FInnerDelta / 2);
  FSVCursor.Update(FInnerDelta / 3);
end;

procedure TCircleSelector.SetColor(const AColor: TAlphaColor);
begin
  if FColor = AColor then
    Exit;

  FColor := AColor;
  RGB2HSV(FColor, FHue, FSaturation, FValue);
  RedrawTriangle;

  var Theta := DegToRad(FHue);

  var S, C: Single;
  SinCos(Theta, S, C);

  // 色相環カーソル位置
  var X := FCX + FHueRadius * C;
  var Y := FCY + FHueRadius * S;

  FHueCursor.MoveTo(X, Y);

  var W0: Single;
  var W1: Single;
  var W2: Single;

  if FValue = 0 then
  begin
    W0 := 0;
    W1 := 0;
    W2 := 1;
  end
  else
  begin
    W0 := FSaturation * FValue;
    W1 := FValue - W0;
    W2 := 1 - FValue;
  end;

  var SX :=
    FTriP0.X * W0 +
    FTriP1.X * W1 +
    FTriP2.X * W2;

  var SY :=
    FTriP0.Y * W0 +
    FTriP1.Y * W1 +
    FTriP2.Y * W2;

  FSVCursor.MoveTo(SX, SY);
end;

{ TRectSelector }

constructor TRectSelector.Create(AOwner: TComponent);
begin
  inherited;

  FCursor := TRectCursor.Create(Self);
  FCursor.Parent := Self;
end;

destructor TRectSelector.Destroy;
begin
  FCursor.Free;
  inherited;
end;

procedure TRectSelector.DrawImpl(
  const ACanvas: TCanvas;
  const AData: TBitmapData);
begin
  var W := AData.Width;
  var H := AData.Height;

  for var Y := 0 to H - 1 do
  begin
    var NY := Y / H;
    var S, V: Single;

    if NY <= 0.5 then
    begin
      V := 1;
      S := EnsureRange(NY * 2, 0, 1);
    end
    else
    begin
      S := 1;
      V := EnsureRange(1 - (NY - 0.5) * 2, 0, 1);
    end;

    for var X := 0 to W - 1 do
    begin
      var Hdeg := EnsureRange(X / W, 0, 1) * 360;
      AData.SetPixel(X, Y, HSV2RGB(Hdeg, S, V));
    end;
  end;
end;

procedure TRectSelector.MouseEventImpl(const AX, AY: Single);
begin
  if Pressed then
    FCursor.MoveTo(AX, AY);
end;

procedure TRectSelector.ResizeImpl;
begin
  FCursor.Update(CURSOR_SIZE);
end;

procedure TRectSelector.SetColor(const AColor: TAlphaColor);
begin
  if FColor = AColor then
    Exit;

  FColor := AColor;
  RGB2HSV(FColor, FHue, FSaturation, FValue);

  var R := LocalRect.Round;
  var InnerW := Max(1.0, R.Width  - 1);
  var InnerH := Max(1.0, R.Height - 1);

  // X : Hue
  var X  := R.Left + InnerW * FHue / 360;

  var Y: Single;
  if Abs(FValue - 1) < Abs(FSaturation - 1) then
  begin
    // 上半分: V=1, S=0→1
    Y := R.Top + FSaturation * (InnerH * 0.5);
  end
  else
  begin
    // 下半分: S=1, V=1→0
    Y := R.Top + (InnerH * 0.5) + (1 - FValue) * (InnerH * 0.5);
  end;

  FCursor.SetBounds(
    X - FCursor.Width  / 2,
    Y - FCursor.Height / 2,
    FCursor.Width,
    FCursor.Height);
end;

{ THueCursor }

procedure THueCursor.MoveTo(const AX, AY: Single);
begin
  var X, Y: Single;

  with TCircleSelector(Selector) do
  begin
    var Theta := ArcTan2(AY - FCY, AX - FCX);
    var S, C: Single;
    SinCos(Theta, S, C);

    X := FCX + FHueRadius * C;
    Y := FCY + FHueRadius * S;

    FHue := RadToDeg(Theta);
    if (FHue < 0) then
      FHue := FHue + 360;

    CalcColor;
    RedrawTriangle;
  end;

  var S: Single;
  if Scene = nil then
    S := 1.0
  else
    S := Scene.GetSceneScale;

  SetBounds(
    X - Width / 2 + CURSOR_MARGIN * S,
    Y - Height / 2,
    Width,
    Height);
end;

{ TSVCursor }

procedure TSVCursor.MoveTo(const AX, AY: Single);
begin
  var P: TPointF;

  with TCircleSelector(Selector) do
  begin
    var W0, W1, W2: Single;

    if not CalcBarycentric(AX, AY, W0, W1, W2) then
      Exit;

    if W0 < 0 then
      W0 := 0;

    if W1 < 0 then
      W1 := 0;

    if W2 < 0 then
      W2 := 0;

    var Sum := W0 + W1 + W2;
    if Sum <= 0 then
      Exit;

    W0 := W0 / Sum;
    W1 := W1 / Sum;
    W2 := W2 / Sum;

    P :=
      PointF(
        FTriP0.X * W0 + FTriP1.X * W1 + FTriP2.X * W2,
        FTriP0.Y * W0 + FTriP1.Y * W1 + FTriP2.Y * W2
      );

    var V := EnsureRange(W0 + W1, 0, 1);
    var S: Single;
     if V > 0 then
       S := EnsureRange(W0 / V, 0, 1)
     else
       S := 0.0;

    SetHSV(FHue, S, V);

    CalcColor;
  end;

  SetBounds(P.X - Width / 2, P.Y - Height / 2, Width, Height);
end;

{ TRectCursor }

procedure TRectCursor.MoveTo(const AX, AY: Single);
begin
  var X, Y: Single;

  with TRectSelector(Selector) do
  begin
    var R := LocalRect.Round;

    X := EnsureRange(AX, R.Left, R.Right);
    Y := EnsureRange(AY, R.Top, R.Bottom);

    var W := Max(1.0, R.Width  - 1);
    var H := Max(1.0, R.Height - 1);

    // 0..1 に正規化
    var NX := (X - R.Left) / W;
    var NY := (Y - R.Top)  / H;

    // 横軸 : Hue
    var NH := EnsureRange(NX, 0, 1) * 360;
    var S, V: Single;

    // 縦軸 : 中央で S=1,V=1
    if NY < 0.5 then
    begin
      // 上半分 : V=1, S=0→1
      V := 1;
      S := EnsureRange(NY * 2, 0, 1);
    end
    else
    begin
      // 下半分 : S=1, V=1→0
      S := 1;
      V := EnsureRange(1 - (NY - 0.5) * 2, 0, 1);
    end;

    SetHSV(NH, S, V);
  end;

  SetBounds(
    X - Width / 2,
    Y - Height / 2,
    Width,
    Height);
end;

end.
