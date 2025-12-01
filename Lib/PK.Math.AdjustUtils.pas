(*
 * Adjust Functions
 *
 * PLATFORMS
 *   All
 *
 * LICENSE
 *   Copyright (c) 2003, 2025 HOSOKAWA Jun
 *   Released under the MIT license
 *   http://opensource.org/licenses/mit-license.php
 *
 * 2003/10/21 Ver 1.0.0
 * 2025/11/24 Ver 2.0.0  今や不要な関数を削除
 *
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Math.AdjustUtils;

interface

procedure Normalize(var AX1, AY1, AX2, AY2: Integer); overload;
procedure Normalize(var A1, A2: Integer); overload;

function FAdjust(var AValue: Double; const AMax: Double): Double;
procedure Adjust360(var AAngle: Single);

function ValidIndex(const AIndex: Integer; const ALen: Integer)
  : Boolean; overload;

implementation

uses
  System.Math;

procedure Normalize(var AX1, AY1, AX2, AY2: Integer);
var
  tmpInt: Integer;
begin
  if (AX1 > AX2) then
  begin
    tmpInt := AX1;
    AX1 := AX2;
    AX2 := tmpInt;
  end;

  if (AY1 > AY2) then
  begin
    tmpInt := AY1;
    AY1 := AY2;
    AY2 := tmpInt;
  end;
end;

procedure Normalize(var A1, A2: Integer);
var
  tmpInt: Integer;
begin
  if (A1 > A2) then
  begin
    tmpInt := A1;
    A1 := A2;
    A2 := tmpInt;
  end;
end;

function FAdjust(var AValue: Double; const AMax: Double): Double;
begin
  if (AValue < 0) then
    AValue := 0;

  if (AValue > AMax) then
    AValue := AMax;

  Result := AValue;
end;

procedure Adjust360(var AAngle: Single);
begin
  AAngle := FMod(AAngle, 360);
  if (AAngle < 0) then
    AAngle := AAngle + 360;
end;

function ValidIndex(const AIndex: Integer; const ALen: Integer): Boolean;
begin
  Result := (AIndex > -1) and (AIndex < ALen);
end;

end.
