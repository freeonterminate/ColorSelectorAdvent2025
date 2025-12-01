(*
 * Digital Differential Analyzer Rootines
 *
 * PLATFORMS
 *   All
 *
 * LICENSE
 *   Copyright (c) 2003 HOSOKAWA Jun
 *   Released under the MIT license
 *   http://opensource.org/licenses/mit-license.php
 *
 * 2003/10/21 Version 1.0.0
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Graphic.DDA;

interface

uses
  System.Types;

type
  TCircleSubProc =
    reference to procedure(const iX, iY: Integer; var ioValue: Pointer);
  TDDAProc =
    reference to procedure(const iX, iY: Integer; var ioData: Pointer);

procedure DDA(
  iX1, iY1, iX2, iY2: Integer;
  iData: Pointer;
  const iOnBits: TDDAProc);

procedure Circle(
  const iDiameter: Integer;
  iValue: Pointer;
  const iCircleSubProc: TCircleSubProc);

function GetFilledCirclePoints(
  const iDiameter: Integer;
  var ioPoints: TArray<TPoint>): Single;

procedure Ellipse(
  iX1, iY1, iX2, iY2: Integer;
  iValue: Pointer;
  const iProc: TCircleSubProc);

implementation

uses
  System.Classes
  , PK.Math.AdjustUtils
  ;

procedure DDA(
  iX1, iY1, iX2, iY2: Integer;
  iData: Pointer;
  const iOnBits: TDDAProc);
(*
 * 概要  DDA を行う
 * 引数  iX1, iY1  始点
 *       iX2, iY2  終点
 *       iOnBits   DDA の計算上の点で呼ばれる
 *       iData     iOnBits に渡したいデータ
 *)
var
  Flag: Integer;
  X, Y: Integer;
  Sign: Integer;
  XSize, YSize: Integer;
begin
  XSize := abs(iX2 - iX1);
  YSize := abs(iY2 - iY1);

  if (XSize > YSize) then
  begin
    Flag := XSize shr 1;

    if (iX1 < iX2) then
    begin
      if (iY1 < iY2) then
        Sign := +1
      else
        Sign := -1;

      Y := iY1;

      for X := iX1 to iX2 do
      begin
        iOnBits(X, Y, iData);

        Dec(Flag, YSize);
        if (Flag < 0) then
        begin
          Inc(Flag, XSize);
          Inc(Y, Sign);
        end;
      end;
    end
    else
    begin
      Y := iY1;
      iY1 := iY2;
      iY2 := Y;

      if (iY1 > iY2) then
        Sign := +1
      else
        Sign := -1;

      for X := iX1 downto iX2 do
      begin
        iOnBits(X, Y, iData);

        Dec(Flag, YSize);
        if (Flag < 0) then
        begin
          Inc(Flag, XSize);
          Inc(Y, Sign);
        end;
      end;
    end;
  end
  else
  begin
    Flag := YSize shr 1;

    if (iY1 < iY2) then
    begin
      if (iX1 < iX2) then
        Sign := +1
      else
        Sign := -1;

      X := iX1;

      for Y := iY1 to iY2 do
      begin
        iOnBits(X, Y, iData);

        Dec(Flag, XSize);
        if (Flag < 0) then
        begin
          Inc(Flag, YSize);
          Inc(X, Sign);
        end;
      end;
    end
    else
    begin
      X := iX1;
      iX1 := iX2;
      iX2 := X;

      if (iX1 > iX2) then
        Sign := +1
      else
        Sign := -1;

      for Y := iY1 downto iY2 do
      begin
        iOnBits(X, Y, iData);

        Dec(Flag, XSize);
        if (Flag < 0) then
        begin
          Inc(Flag, YSize);
          Inc(X, Sign);
        end;
      end;
    end;
  end;
end;

procedure Circle(
  const iDiameter: Integer;
  iValue: Pointer;
  const iCircleSubProc: TCircleSubProc);
(*
 * 概要  円を計算する
 * 引数  iDiameter   直径
 *       vCircleSub  円周上の点を処理する手続き
 *       iValue      vCircleSub に渡される任意の値
 *)
var
  X, Y: Integer;
  XP, XN, YP, YN: Integer;
  OrdRadius: Integer;
  Radius: Integer;
  Even: Integer;
  Matrix: array of array of Boolean;

  procedure CallSub(vX, vY: Integer);
  var
    tmpX, tmpY: Integer;
  begin
    tmpX := vX + OrdRadius;
    tmpY := vY + OrdRadius;

    if (not Matrix[tmpX, tmpY]) then
    begin
      Matrix[tmpX, tmpY] := True;
      iCircleSubProc(vX, vY, iValue);
    end;
  end;

begin
  OrdRadius := iDiameter shr 1;
  Radius := OrdRadius;
  Even := Ord(not Odd(iDiameter));

  X := Radius;
  Y := 0;

  if (Radius > 0) then
  begin
    SetLength(Matrix, iDiameter + 1, iDiameter + 1);

    while (X >= Y) do
    begin
      XP := +X - Even;
      XN := -X + Even;
      YP := +Y - Even;
      YN := -Y + Even;

      CallSub(XP, +Y);
      CallSub(XP, YN);

      CallSub(-X, +Y);
      CallSub(-X, YN);

      CallSub(YP, +X);
      CallSub(YP, XN);

      CallSub(-Y, +X);
      CallSub(-Y, XN);

      Dec(Radius, Y shl 1 + 1);
      Inc(Y);

      if (Radius < 0) then
      begin
        Inc(Radius, (X - 1) shl 1);
        Dec(X);
      end;
    end;
  end
  else
    iCircleSubProc(0, 0, iValue);
end;

function GetFilledCirclePoints(
  const iDiameter: Integer;
  var ioPoints: TArray<TPoint>): Single;
(*
 * 概要  中身の詰まった円を返す
 * 引数  iDiameter  直径
 *       iPoints    円の全ての点を受け取る
 * 戻値  中心から最も遠い点の距離
 *)
var
  X, Y: Integer;
  XP, XN, YP, YN: Integer;
  DX: Integer;
  OrdRadius: Integer;
  Radius: Integer;
  Even: Integer;
  Longest: Single;
  Matrix: array of array of Boolean;

  procedure SetPoint(vX: Integer; const vY, vAdjustCount: Integer);
  var
    Index: Integer;
    Count: Integer;
    tmpX, tmpY: Integer;
  begin
    Index := Length(ioPoints);

    Count := Abs(vX) + vAdjustCount;

    while (Count > 0) do
    begin
      tmpX := vX + OrdRadius;
      tmpY := vY + OrdRadius;

      if (not Matrix[tmpX, tmpY]) then
      begin
        Matrix[tmpX, tmpY] := True;
        SetLength(ioPoints, Index + 1);
        ioPoints[Index] := Point(vX, vY);

        tmpX := vX * vX + vY * vY;
        if (tmpX > Longest) then
          Longest := tmpX;

        Inc(Index);
        Inc(vX, DX);
      end;

      Dec(Count);
    end;
  end;

begin
  SetLength(ioPoints, 0);

  OrdRadius := iDiameter shr 1;
  Radius := OrdRadius;
  Even := Ord(not Odd(iDiameter));
  Longest := 0;

  X := Radius;
  Y := 0;

  if (Radius > 0) then
  begin
    SetLength(Matrix, iDiameter + 1, iDiameter + 1);

    while (X >= Y) do
    begin
      XP := +X - Even;
      XN := -X + Even;
      YP := +Y - Even;
      YN := -Y + Even;

      DX := -1;
      SetPoint(XP, +Y, 1);
      SetPoint(XP, YN, 1);

      DX := +1;
      SetPoint(-X, +Y, 1);
      SetPoint(-X, YN, 1);

      DX := -1;
      SetPoint(YP, +X, 0);
      SetPoint(YP, XN, 0);

      DX := +1;
      SetPoint(-Y, +X, 1);
      SetPoint(-Y, XN, 1);

      Dec(Radius, Y shl 1 + 1);
      Inc(Y);

      if (Radius < 0) then
      begin
        Inc(Radius, (X - 1) shl 1);
        Dec(X);
      end;
    end;
  end
  else
  begin
    SetLength(ioPoints, 1);
    ioPoints[0] := Point(0, 0);
  end;

  Result := Sqrt(Longest);
end;

procedure Ellipse(
  iX1, iY1, iX2, iY2: Integer;
  iValue: Pointer;
  const iProc: TCircleSubProc);
(*
 * 概要  楕円を計算する
 * 引数  iX1, iY1  楕円に接する長方形の左上座標
 *       iX2, iY2  楕円に接する長方形の右下座標
 *       iProc     点を処理する手続き
 *       iValue    iProc に渡される任意の値
 *)
var
  RX, RY, CX, CY: Integer;
  X, Y: Integer;
  XSize, YSize: Integer;
  Flag: Integer;

  procedure Draw(const iP0, iQ0, iP1, iQ1: Integer; var ioP2, ioQ2: Integer);
  begin
    iProc(CX + iP0, CY + iQ1, iValue);
    iProc(CX + iP0, CY - iQ1, iValue);
    iProc(CX - iP0, CY + iQ1, iValue);
    iProc(CX - iP0, CY - iQ1, iValue);
    iProc(CX + iQ0, CY + iP1, iValue);
    iProc(CX + iQ0, CY - iP1, iValue);
    iProc(CX - iQ0, CY + iP1, iValue);
    iProc(CX - iQ0, CY - iP1, iValue);

    Dec(Flag, (ioQ2 shl 1) + 1);
    if (Flag < 0) then
    begin
      Inc(Flag, (ioP2 - 1) shl 1);
      Dec(ioP2);
    end;

    Inc(ioQ2);
  end;

begin
  Normalize(iX1, iY1, iX2, iY2);

  XSize := iX2 - iX1 + 1;
  YSize := iY2 - iY1 + 1;

  RX := XSize shr 1;
  RY := YSize shr 1;

  CX := iX1 + RX;
  CY := iY1 + RY;

  if (RX > 0) and (RY > 0) then
  begin
    if (XSize > YSize) then
    begin
      X := RX;
      Y := 0;
      Flag := X;

      while (X >= Y) do
        Draw(
          X, Y,
          X * RY div RX, Y * RY div RX,
          X, Y);
    end
    else
    begin
      X := 0;
      Y := RY;
      Flag := Y;

      while (Y >= X) do
        Draw(
          Y * RX div RY, X * RX div RY,
          Y, X,
          Y, X);
    end;
  end;
end;

end.
