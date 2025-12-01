unit PK.Graphic.ColorConverter;

interface

uses
  System.UITypes;

// 概要  CMY 系から RGB 系へ変換する
// 引数  AC  Cyan
//       AM  Magenta
//       AY  Yellow
// 戻値  RGB 値
function CMY2RGB(const AC, AM, AY: Integer): TAlphaColor;

// 概要  CMY 系から RGB 系へ変換する
// 引数  AColor  ARGB 値
//       AC  Cyan
//       AM  Magenta
//       AY  Yellow
procedure RGB2CMY(const AColor: TAlphaColor; var AC, AM, AY: Integer);

// 概要  HSV 系から RGB 系へ変換する
// 引数  AHue  色相角度（Deg 0-360°）
//       ASaturation  彩度
//       AValue  強度
// 戻値  RGB 値
function HSV2RGB(AHue, ASaturation, AValue: Single): TAlphaColor;

// 概要  RGB 系から HSV 系へ変換する
// 引数  vValue  ARGB 値
//       vH      色相角度（Deg 0-360°）
//       vS      彩度
//       vV      強度
procedure RGB2HSV(
  const AColor: TAlphaColor;
  var AHue, ASaturation, AValue: Single);

// 概要  HLS 系を RGB 系に変換する
// 引数  vH  色相角度
//       vL  明度
//       vS  彩度
// 戻値  RGB 値
function HLS2RGB(AHue, ALightness, ASaturation: Single): TAlphaColor;

// 概要  RGB 系を HLS 系に変換する
// 引数  vValue  ARGB 値
//       vH      色相角度
//       vL      明度
//       vS      彩度
procedure RGB2HLS(
  const AColor: TAlphaColor;
  var AHue, ALightness, ASaturation: Single);

// 概要  CIE 系を RGB 系に変換する
// 引数  vX  色度 X
//       vY  色度 Y
//       vZ  輝度
// 戻値  RGB 値
function CIE2RGB(AX, AY, AZ: Single): TAlphaColor;

// 概要  RGB 系を CIE 系に変換する
// 引数  AColor  ARGB 値
//       AX      色度 X
//       AY      色度 Y
//       AZ      輝度
// 戻値  RGB 値
procedure RGB2CIE(const AColor: TAlphaColor; var AX, AY, AZ: Single);

implementation

uses
  System.Classes
  , System.Math
  , System.UIConsts
  , System.SysUtils
  , PK.Math.AdjustUtils
  ;

// 概要  R, G, B の最小値、最大値、差分を返す
// 引数  AMin   最小値を受け取る
//       AMax   最大値を受け取る
//       ADiff  Max - Min
//       AR     R
//       AG     G
//       AB     B
procedure GetMinMaxDiff(
  var AMin, AMax, ADiff: Integer;
  const AR, AG, AB: Integer);
begin
  AMin := MinIntValue([AR, AG, AB]);
  AMax := MaxIntValue([AR, AG, AB]);
  ADiff := AMax - AMin;
end;

function CMY2RGB(const AC, AM, AY: Integer): TAlphaColor;
begin
  Result :=
    MakeColor(
      $ff - AC,
      $ff - AM,
      $ff - AY
    );
end;

procedure RGB2CMY(const AColor: TAlphaColor; var AC, AM, AY: Integer);
begin
  AC := $ff - TAlphaColorRec(AColor).R;
  AM := $ff - TAlphaColorRec(AColor).G;
  AY := $ff - TAlphaColorRec(AColor).B;
end;

function HSV2RGB(AHue, ASaturation, AValue: Single): TAlphaColor;
var
  R, G, B: Integer;
begin
  Adjust360(AHue);
  ASaturation := EnsureRange(ASaturation, 0, 1);
  AValue := EnsureRange(AValue, 0, 1);

  if (ASaturation = 0) then begin
    var P0 := EnsureRange(Round(AValue * $ff), 0, $ff);

    R := P0;
    G := P0;
    B := P0;
  end
  else begin
    AHue := AHue / 60;

    var Hi := Trunc(AHue);
    var Hf := Frac(AHue);

    var P0 := Round(AValue * $ff);
    var P1 := Round(P0 * (1 - ASaturation));
    var P2 := Round(P0 * (1 - (ASaturation * Hf)));
    var P3 := Round(P0 * (1 - (ASaturation * (1 - Hf))));

    R := 0;
    G := 0;
    B := 0;
    
    case Hi of
      0: begin
        R := P0;
        G := P3;
        B := P1;
      end;

      1: begin
        R := P2;
        G := P0;
        B := P1;
      end;

      2: begin
        R := P1;
        G := P0;
        B := P3;
      end;

      3: begin
        R := P1;
        G := P2;
        B := P0;
      end;

      4: begin
        R := P3;
        G := P1;
        B := P0;
      end;

      5: begin
        R := P0;
        G := P1;
        B := P2;
      end;
    end;
  end;

  Result := MakeColor(R, G, B);
end;

procedure RGB2HSV(
  const AColor: TAlphaColor;
  var AHue, ASaturation, AValue: Single);
begin
  var R := TAlphaColorRec(AColor).R;
  var G := TAlphaColorRec(AColor).G;
  var B := TAlphaColorRec(AColor).B;

  var Max, Min, Diff: Integer;
  GetMinMaxDiff(Min, Max, Diff, R, G, B);

  AValue := Max / 256;

  ASaturation := 0;
  if (Max <> 0) then
    ASaturation := Diff / Max;

  AHue := 0;
  if (ASaturation <> 0) then begin
    if (R = Max) then
      AHue := 0 + (G - B) / Diff;
    if (G = Max) then
      AHue := 2 + (B - R) / Diff;
    if (B = Max) then
      AHue := 4 + (R - G) / Diff;
  end;

  AHue := AHue * 60;
  if (AHue < 0) then
    AHue := AHue + 360;
end;

function HLS2RGB(AHue, ALightness, ASaturation: Single): TAlphaColor;
var
  Min, Max, Diff: Single;

  function H2V(vH: Single): Integer;
  var
    V: Single;
  begin
    V := Min;

    if (vH < 60) then
      V := Min + Diff * vH / 60;

    if (vH >= 60) and (vH < 180) then
      V := Max;

    if (vH >= 180) and (vH < 240) then
      V := Min + Diff * (240 - vH) / 60;

    Result := EnsureRange(Round(V * 256), 0, $ff);
  end;

begin
  Adjust360(AHue);
  ALightness := EnsureRange(ALightness, 0, 1);
  ASaturation := EnsureRange(ASaturation, 0, 1);

  if (ALightness > 0.5) then begin
    Max := ALightness * (1 - ASaturation) + ASaturation;
    Min := 2 * ALightness - Max;
  end
  else begin
    Min := ALightness * (1 - ASaturation);
    Max := 2 * ALightness - Min;
  end;

  Diff := Max - Min;

  var R := H2V(AHue + 120);
  var G := H2V(AHue);
  var B := H2V(AHue - 120);

  Result := MakeColor(R, G, B);
end;

procedure RGB2HLS(
  const AColor: TAlphaColor;
  var AHue, ALightness, ASaturation: Single);
begin
  var R := TAlphaColorRec(AColor).R;
  var G := TAlphaColorRec(AColor).G;
  var B := TAlphaColorRec(AColor).B;

  var Min, Max, Diff: Integer;
  GetMinMaxDiff(Min, Max, Diff, R, G, B);
  var Added := (Min + Max) / 255;

  ALightness := Added / 2;

  ASaturation := 0;
  if (ALightness > 0.5) then begin
    if (Added <> 2) then
      ASaturation := Diff / (2 - Added);
  end
  else begin
    if (Added <> 0) then
      ASaturation := Diff / Added;
  end;

  AHue := 0;
  if (Diff <> 0) then begin
    if (R = Max) then
      AHue := 0 + (G - B) * 60 / Diff;
    if (G = Max) then
      AHue := 2 + (B - R) * 60 / Diff;
    if (B = Max) then
      AHue := 4 + (R - G) * 60 / Diff;

    if (AHue < 0) then
      AHue := AHue + 360;
  end;
end;

function CIE2RGB(AX, AY, AZ: Single): TAlphaColor;
begin
  var R := 255;
  var G := 255;
  var B := 255;

  if (AY > 0) then begin
    if (AX < 0) then
      AX := 0;
    if (AZ < 0) then
      AZ := 0;

    var XZY := AX * AZ / AY;
    var XYZY := (1 - AX - AY) * AZ / AY;

    R :=
      Round(
        (
          2.739386694386690 * XZY -
          1.144708939708940 * AZ -
          0.424074844074844 * XYZY
        ) * 255
      );

    G :=
      Round(
        (
          -1.118985713198160 * XZY +
          2.028500773974170 * AZ +
          0.033144618976324 * XYZY
        ) * 255
      );

    B  :=
      Round(
        (
          0.137976247723133 * XZY +
          0.333450588949605 * AZ +
          1.104800777170610 * XYZY
        ) * 255
      );
  end;

  Result := MakeColor(R, G, B);
end;

procedure RGB2CIE(const AColor: TAlphaColor; var AX, AY, AZ: Single);
begin
  var R := TAlphaColorRec(AColor).R;
  var G := TAlphaColorRec(AColor).G;
  var B := TAlphaColorRec(AColor).B;

  AX := (0.478 * R + 0.299 * G + 0.175 * B) / 255;
  AY := (0.263 * R + 0.655 * G + 0.081 * B) / 255;
  AZ := AY;

  var Z := (0.020 * R + 0.160 * G + 0.908 * B) / 255;
  var W := AX + AY + Z;

  if (W <> 0) then
  begin
    AX := AX / W;
    AY := AY / W;
  end;
end;

end.

