(*
 * 指定済みの色から選べる Color Selector クラス
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
 *   FSelector := T16CellSelector.Create(Self);
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

unit PK.Graphic.CellSelectors;

interface

uses
  System.Classes
  , System.SysUtils
  , System.UITypes
  , System.Types
  , FMX.Graphics
  , PK.Graphic.ColorSelectors
  ;

type
  TCellCursor = class;

  TCustomCellSelector = class(TCustomSelector)
  private const
    CURSOR_RATIO = 0.65; // カーソルサイズ比（セル短辺に対する）
    CURSOR_MINIMUM_SIZE = 5;
  private
    FCols: Integer;
    FRows: Integer;
    FCellRect: TRectF;
    FCellWidth: Single;
    FCellHeight: Single;
    FSelCol: Integer;
    FSelRow: Integer;
    FCursor: TCellCursor;
  private
    procedure SetGridSize(const ACols, ARows: Integer);
  protected
    function GetCellColor(ACol, ARow: Integer): TAlphaColor; virtual; abstract;
    procedure SetCursorPosBySelected;

    procedure Resize; override;
    procedure Draw(const ACanvas: TCanvas); override;
    procedure SetColor(const AColor: TAlphaColor); override;

    procedure MouseEventImpl(const AX, AY: Single); override;

    function CellByPos(const AX, AY: Single): TPoint; virtual;

    procedure SetSelectedCell(const ACol, ARow: Integer); virtual;

    property CellRect: TRectF read FCellRect;
    property ColCount: Integer read FCols;
    property RowCount: Integer read FRows;
    property SelectedCol: Integer read FSelCol;
    property SelectedRow: Integer read FSelRow;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  T16CellSelector = class(TCustomCellSelector)
  private const
    COL_COUNT = 8;
    ROW_COUNT = 2;
  protected
    function GetCellColor(ACol, ARow: Integer): TAlphaColor; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  T128CellSelector = class(TCustomCellSelector)
  private const
    COL_COUNT = 16;
    ROW_COUNT = 8;
  protected
    function GetCellColor(ACol, ARow: Integer): TAlphaColor; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCellCursor = class(TSelectorCursor)
  protected
    procedure MoveTo(const AX, AY: Single); override;
  end;

implementation

uses
  System.Math
  ;

{ TCustomCellSelector }

constructor TCustomCellSelector.Create(AOwner: TComponent);
begin
  inherited;

  FCols := 1;
  FRows := 1;
  FSelCol := 0;
  FSelRow := 0;

  FCursor := TCellCursor.Create(Self);
  FCursor.Parent := Self;
end;

destructor TCustomCellSelector.Destroy;
begin
  FCursor.Free;

  inherited;
end;

procedure TCustomCellSelector.SetGridSize(const ACols, ARows: Integer);
begin
  FCols := Max(1, ACols);
  FRows := Max(1, ARows);

  // セルサイズを再計算して描画更新
  Resize;
end;

procedure TCustomCellSelector.Resize;
begin
  inherited;

  FCellRect := LocalRect;

  var W := Max(1.0, FCellRect.Width);
  var H := Max(1.0, FCellRect.Height);

  FCellWidth := W / FCols;
  FCellHeight := H / FRows;

  // カーソルのサイズ更新
  var Size :=
    Max(
      Min(FCellWidth, FCellHeight) * CURSOR_RATIO,
      CURSOR_MINIMUM_SIZE
    );

  FCursor.Update(Size);

  // 現在の選択セルの中心にカーソルを再配置
  SetCursorPosBySelected;

  // セル描画更新
  StartDraw;
end;

procedure TCustomCellSelector.Draw(const ACanvas: TCanvas);
begin
  inherited;

  ACanvas.BeginScene;
  try
    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Stroke.Kind := TBrushKind.Solid;
    ACanvas.Stroke.Thickness := 1;
    ACanvas.Stroke.Color := (BaseColor xor $00_ff_ff_ff) or $ff_00_00_00;

    for var Row := 0 to FRows - 1 do
    begin
      for var Col := 0 to FCols - 1 do
      begin
        var CellR :=
          RectF(
            FCellRect.Left + Col * FCellWidth,
            FCellRect.Top + Row * FCellHeight,
            FCellRect.Left + (Col + 1) * FCellWidth,
            FCellRect.Top + (Row + 1) * FCellHeight
          );

        ACanvas.Fill.Color := GetCellColor(Col, Row);
        ACanvas.FillRect(CellR, 0, 0, [], 1);
        ACanvas.DrawRect(CellR, 0, 0, [], 1);
      end;
    end;

    ACanvas.Stroke.Thickness := 2.5;
    ACanvas.DrawRect(FCellRect, 0, 0, [], 1);
  finally
    ACanvas.EndScene;
  end;
end;

function TCustomCellSelector.CellByPos(const AX, AY: Single): TPoint;
begin
  var X := EnsureRange(AX, FCellRect.Left, FCellRect.Right - 0.001);
  var Y := EnsureRange(AY, FCellRect.Top,  FCellRect.Bottom - 0.001);

  Result :=
    Point(
      Trunc((X - FCellRect.Left) / FCellWidth),
      Trunc((Y - FCellRect.Top) / FCellHeight)
    );

  Result :=
    Point(
      EnsureRange(Result.X, 0, FCols - 1),
      EnsureRange(Result.Y, 0, FRows - 1)
    );
end;

procedure TCustomCellSelector.SetSelectedCell(const ACol, ARow: Integer);
begin
  FSelCol := EnsureRange(ACol, 0, FCols - 1);
  FSelRow := EnsureRange(ARow, 0, FRows - 1);

  FColor :=
    (FColor and $ff_00_00_00) or
    (GetCellColor(FSelCol, FSelRow) and $00_ff_ff_ff);
  DoChange;

  SetCursorPosBySelected;
end;

procedure TCustomCellSelector.MouseEventImpl(const AX, AY: Single);
begin
  if Pressed then
    FCursor.MoveTo(AX, AY);
end;

procedure TCustomCellSelector.SetColor(const AColor: TAlphaColor);
begin
  if FColor = AColor then
    Exit;

  FColor := AColor;

  var Target := FColor and $00_ff_ff_ff;
  var Found := False;

  for var Row := 0 to FRows - 1 do
  begin
    for var Col := 0 to FCols - 1 do
    begin
      if (GetCellColor(Col, Row) and $00_ff_ff_ff) = Target then
      begin
        SetSelectedCell(Col, Row);
        Found := True;

        Break;
      end;
    end;
  end;

  FCursor.Visible := Found;
end;

procedure TCustomCellSelector.SetCursorPosBySelected;
begin
  var Center :=
    PointF(
      FCellRect.Left + (FSelCol + 0.5) * FCellWidth,
      FCellRect.Top + (FSelRow + 0.5) * FCellHeight
    );

  FCursor.SetBounds(
    Center.X - FCursor.Width / 2,
    Center.Y - FCursor.Height / 2,
    FCursor.Width,
    FCursor.Height);
end;

{ T16CellSelector }

constructor T16CellSelector.Create(AOwner: TComponent);
begin
  inherited;
  // 8 列 × 2 行
  SetGridSize(COL_COUNT, ROW_COUNT);
end;

function T16CellSelector.GetCellColor(ACol, ARow: Integer): TAlphaColor;
const
  COLORS:
    array [0.. ROW_COUNT - 1, 0.. COL_COUNT - 1] of TAlphaColor =
  (

    ( // 0
      ($ff_ff_ff_ff), ($ff_bb_bb_bb), ($ff_ff_ff_00), ($ff_ff_00_99),
      ($ff_33_cc_00), ($ff_00_99_ff), ($ff_33_00_99), ($ff_99_66_33)
    ),

    ( // 1
      ($ff_00_00_00), ($ff_66_66_66), ($ff_ff_66_00), ($ff_dd_00_00),
      ($ff_00_66_00), ($ff_00_00_cc), ($ff_00_00_66), ($ff_66_33_00)
    )
  );
begin
  Result := COLORS[ARow, ACol];
end;

{ T128CellSelector }

constructor T128CellSelector.Create(AOwner: TComponent);
begin
  inherited;
  // 16 列 × 8 行
  SetGridSize(16, 8);
end;

function T128CellSelector.GetCellColor(ACol, ARow: Integer): TAlphaColor;
const
  COLORS:
    array [0.. ROW_COUNT - 1, 0.. COL_COUNT - 1] of TAlphaColor =
  (
    ( // 0
      ($ff_ff_00_00), ($ff_ff_ff_00), ($ff_00_ff_00), ($ff_00_ff_ff),
      ($ff_00_00_ff), ($ff_ff_00_ff), ($ff_ff_ff_ff), ($ff_e6_e6_e6),
      ($ff_da_da_da), ($ff_cd_cd_cd), ($ff_c0_c0_c0), ($ff_b4_b4_b4),
      ($ff_a8_a8_a8), ($ff_9a_9a_9a), ($ff_8d_8d_8d), ($ff_81_81_81)
    ),

    ( // 1
      ($ff_ee_1d_24), ($ff_ff_f1_00), ($ff_00_a6_50), ($ff_00_ae_ef),
      ($ff_2f_31_92), ($ff_ed_00_8c), ($ff_74_74_74), ($ff_66_66_66),
      ($ff_59_59_59), ($ff_4b_4b_4b), ($ff_3e_3e_3e), ($ff_30_30_30),
      ($ff_21_21_21), ($ff_13_13_13), ($ff_0a_0a_0a), ($ff_00_00_00)
    ),

    ( // 2
      ($ff_f7_97_7a), ($ff_fb_ad_82), ($ff_fd_c6_8c), ($ff_ff_f7_99),
      ($ff_c6_df_9c), ($ff_a4_d4_9d), ($ff_81_ca_9d), ($ff_7b_cd_c9),
      ($ff_6c_cf_f7), ($ff_7c_a6_d8), ($ff_82_93_ca), ($ff_88_81_be),
      ($ff_a2_86_bd), ($ff_bc_8c_bf), ($ff_f4_9b_c1), ($ff_f5_99_9d)
    ),

    ( // 3
      ($ff_f1_6c_4d), ($ff_f6_8e_54), ($ff_fb_af_5a), ($ff_ff_f4_67),
      ($ff_ac_d3_72), ($ff_7d_c4_73), ($ff_39_b7_78), ($ff_17_bc_b4),
      ($ff_00_bf_f3), ($ff_43_8c_cb), ($ff_55_73_b7), ($ff_5e_5c_a7),
      ($ff_85_5f_a8), ($ff_a7_63_a9), ($ff_ef_6e_a8), ($ff_f1_6d_7e)
    ),

    ( // 4
      ($ff_ee_1d_24), ($ff_f1_65_22), ($ff_f7_94_1d), ($ff_ff_f1_00),
      ($ff_8f_c6_3d), ($ff_37_b4_4a), ($ff_00_a6_50), ($ff_00_a9_9e),
      ($ff_00_ae_ef), ($ff_00_72_bc), ($ff_00_54_a5), ($ff_2f_31_92),
      ($ff_65_2c_91), ($ff_91_27_8f), ($ff_ed_00_8c), ($ff_ee_10_5a)
    ),

    ( // 5
      ($ff_9d_0a_0f), ($ff_a1_41_0d), ($ff_a3_62_09), ($ff_ab_a0_00),
      ($ff_58_85_28), ($ff_19_7b_30), ($ff_00_72_36), ($ff_00_73_6a),
      ($ff_00_76_a4), ($ff_00_4a_80), ($ff_00_33_70), ($ff_1e_14_64),
      ($ff_45_0e_61), ($ff_62_05_5f), ($ff_9d_00_5c), ($ff_9d_00_39)
    ),

    ( // 6
      ($ff_79_00_00), ($ff_7b_30_00), ($ff_7c_49_00), ($ff_82_7a_00),
      ($ff_3e_66_17), ($ff_04_5f_20), ($ff_00_58_24), ($ff_00_59_51),
      ($ff_00_5b_7e), ($ff_00_35_62), ($ff_00_20_56), ($ff_0c_00_4b),
      ($ff_31_00_4a), ($ff_4b_00_48), ($ff_7a_00_45), ($ff_7a_00_26)
    ),

    ( // 7
      ($ff_c7_b1_98), ($ff_9a_85_75), ($ff_72_63_57), ($ff_52_48_42),
      ($ff_37_30_2d), ($ff_c6_9c_6d), ($ff_a7_7c_50), ($ff_8c_62_3a),
      ($ff_74_4b_24), ($ff_61_38_13), ($ff_00_07_43), ($ff_00_00_38),
      ($ff_27_00_37), ($ff_38_00_35), ($ff_67_00_32), ($ff_67_00_13)
    )
  );
begin
  Result := COLORS[ARow, ACol];
end;

{ TCellCursor }

procedure TCellCursor.MoveTo(const AX, AY: Single);
begin
  with TCustomCellSelector(Selector) do
  begin
    var CR := CellByPos(AX, AY);
    SetSelectedCell(CR.X, CR.Y);
  end;

  Visible := True;
end;

end.
