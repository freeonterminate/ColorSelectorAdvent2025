unit uMain;

interface

uses
  System.SysUtils
  , System.Classes
  , System.Types
  , System.UITypes
  , FMX.Colors
  , FMX.Controls
  , FMX.Controls.Presentation
  , FMX.Edit
  , FMX.Forms
  , FMX.Graphics
  , FMX.Layouts
  , FMX.Memo
  , FMX.Memo.Types
  , FMX.Objects
  , FMX.StdCtrls
  , FMX.ScrollBox
  , FMX.TabControl
  , FMX.Types
  , SmartCoreAI.Comp.Connection
  , SmartCoreAI.Comp.Chat
  , SmartCoreAI.Types
  , SmartCoreAI.Driver.OpenAI
  , PK.Graphic.HSVSelectors
  , PK.Graphic.CellSelectors
  , PK.Graphic.ColorSelectors
  , PK.Graphic.ColorBar
  , PK.Graphic.FMXColorPanelWrapper
  , PK.Graphic.HSLColorSelector
  ;

type
  TfrmSelector = class(TForm)
    styleStellar: TStyleBook;
    tabSelectors: TTabControl;
    layRoot: TLayout;
    tabCircle: TTabItem;
    tabRect: TTabItem;
    tab16: TTabItem;
    tab128: TTabItem;
    layColors: TLayout;
    layColor: TLayout;
    layBarBase: TLayout;
    lblColor: TLabel;
    timerCopy: TTimer;
    layAIBase: TLayout;
    memoAI: TMemo;
    layMain: TLayout;
    rectWaiter: TRectangle;
    aniWaiter: TAniIndicator;
    chbxAIEnabled: TCheckBox;
    layAIOpeBase: TLayout;
    btnChat: TButton;
    chbxAlpha: TCheckBox;
    layAIMemoScroller: TLayout;
    colorBox: TColorBox;
    tabFMX: TTabItem;
    tabHSL: TTabItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure layColorClick(Sender: TObject);
    procedure timerCopyTimer(Sender: TObject);
    procedure aiOpenAIDriverChatSuccess(Sender: TObject; const ResponseText,
      FullJsonResponse: string);
    procedure chbxAIEnabledChange(Sender: TObject);
    procedure btnChatClick(Sender: TObject);
    procedure tabSelectorsChange(Sender: TObject);
    procedure chbxAlphaChange(Sender: TObject);
    procedure layAIMemoScrollerMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure layAIMemoScrollerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure layAIMemoScrollerMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure layAIMemoScrollerMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; var Handled: Boolean);
  private
    FCircleSelector: TCircleSelector;
    FRectSelector: TRectSelector;
    F16Selector: T16CellSelector;
    F128Selector: T128CellSelector;
    FColorPanelWrapper: TFMXColorPanelWrapper;
    FHSLColorSelector: THSLColorSelector;
    FRGBBars: TRGBBars;
    FColor: TAlphaColor;
    FPrevColor: TAlphaColor;
    FAIConnection: TAIConnection;
    FAIDriver: TAIOpenAIDriver;
    FAIChatReq: TAIChatRequest;
    FAIPressPos: TPointF;
    FAIPressed: Boolean;
    FAIStartY: Single;
  private
    function CreateSelector<T: TCustomSelector>(const AParent: TTabItem): T;
    procedure SelectorChangeHandler(Sender: TObject; const AColor: TAlphaColor);
    procedure RGBBarChangeHandler(Sender: TObject; const AColor: TAlphaColor);
    procedure SelectorMouseUpHandler(
      Sender: TObject;
      AButton: TMouseButton;
      AShift: TShiftState;
      AX, AY: Single);
    procedure AskAI;
    procedure AIChatReqErrorHandler(
      Sender: TObject;
      const AErrorMessage: string);
    procedure AIChatReqResponseHandler(Sender: TObject; const AText: string);
    procedure ShowWaiter;
    procedure HideWaiter;
  public
  end;

var
  frmSelector: TfrmSelector;

implementation

{$R *.fmx}

uses
  System.Math
  , FMX.Clipboard
  , FMX.MagnifierGlass
  , FMX.Platform
  , PK.Utils.Font
  ;

function TfrmSelector.CreateSelector<T>(const AParent: TTabItem): T;
begin
  Result := T.Create(Self);
  Result.Align := TAlignLayout.Client;
  Result.OnChange := SelectorChangeHandler;
  Result.OnMouseUp := SelectorMouseUpHandler;
  Result.Parent := AParent;

  AParent.TagObject := Result;
end;

procedure TfrmSelector.AIChatReqErrorHandler(
  Sender: TObject;
  const AErrorMessage: string);
begin
  HideWaiter;
  memoAI.Text := AErrorMessage;
end;

procedure TfrmSelector.AIChatReqResponseHandler(
  Sender: TObject;
  const AText: string);
begin
  HideWaiter;
  memoAI.Text := AText;
end;

procedure TfrmSelector.aiOpenAIDriverChatSuccess(
  Sender: TObject;
  const ResponseText, FullJsonResponse: string);
begin
  HideWaiter;
end;

procedure TfrmSelector.AskAI;
begin
  ShowWaiter;
  memoAI.Lines.Clear;
  FAIChatReq.Chat(lblColor.Text + 'という色について何か語ってください');
end;

procedure TfrmSelector.btnChatClick(Sender: TObject);
begin
  AskAI;
end;

procedure TfrmSelector.chbxAIEnabledChange(Sender: TObject);
begin
  btnChat.Enabled := chbxAIEnabled.IsChecked;

  if chbxAIEnabled.IsChecked then
  begin
    Height := Trunc(Height + layAIBase.Height);
    layAIBase.Visible := True;
  end
  else
  begin
    layAIBase.Visible := False;
    Height := Trunc(Height - layAIBase.Height);
  end;
end;

procedure TfrmSelector.chbxAlphaChange(Sender: TObject);
begin
  FRGBBars.AlphaEnabled := chbxAlpha.IsChecked;
  if not FRGBBars.AlphaEnabled then
    FRGBBars.SetColorWithoutEvent(FRGBBars.Color or $ff_00_00_00);

  FColorPanelWrapper.AlphaEnabled := FRGBBars.AlphaEnabled;

  SelectorChangeHandler(Self, FRGBBars.Color);
end;

procedure TfrmSelector.FormCreate(Sender: TObject);
begin
  HideWaiter;

  chbxAIEnabledChange(Self);
  layAIMemoScroller.AutoCapture := True;

  FAIConnection := TAIConnection.Create(Self);
  FAIDriver := TAIOpenAIDriver.Create(Self);
  FAIChatReq := TAIChatRequest.Create(Self);

  FAIConnection.Driver := FAIDriver;
  FAIChatReq.Connection := FAIConnection;

  FAIDriver.Params.Add('Model=gpt-4.1');
  // APIkey.inc 内に OpenAI の API キーをシングルクオートをつけて
  // 文字列として記載してください
  // 例: 'skhonyarara-nyararara'
  FAIDriver.Params.Add('APIKey=' + {$I APIkey.inc} );

  FAIChatReq.OnError := AIChatReqErrorHandler;
  FAIChatReq.OnResponse := AIChatReqResponseHandler;

  FRGBBars := TRGBBars.Create(Self);
  FRGBBars.Align := TAlignLayout.Client;
  FRGBBars.OnChange := RGBBarChangeHandler;
  FRGBBars.Parent := layBarBase;

  lblColor.Font.Family := TFontUtils.GetMonospaceFont;

  FCircleSelector := CreateSelector<TCircleSelector>(tabCircle);
  FRectSelector := CreateSelector<TRectSelector>(tabRect);

  F16Selector := CreateSelector<T16CellSelector>(tab16);
  F128Selector := CreateSelector<T128CellSelector>(tab128);
  F16Selector.BaseColor := $00_ff_ff_ff;
  F128Selector.BaseColor := $00_ff_ff_ff;

  FHSLColorSelector := CreateSelector<THSLColorSelector>(tabHSL);

  FColorPanelWrapper := CreateSelector<TFMXColorPanelWrapper>(tabFMX);

  RGBBarChangeHandler(nil, TAlphaColors.Black);
end;

procedure TfrmSelector.FormDestroy(Sender: TObject);
begin
  FCircleSelector.Free;
end;

procedure TfrmSelector.HideWaiter;
begin
  rectWaiter.Visible := False;
  aniWaiter.Enabled := False;

  chbxAIEnabled.Enabled := True;
end;

procedure TfrmSelector.layAIMemoScrollerMouseDown(
  Sender: TObject;
  Button: TMouseButton;
  Shift: TShiftState;
  X, Y: Single);
begin
  FAIPressed := Button = TMouseButton.mbLeft;
  FAIPressPos := PointF(X, Y);
  FAIStartY := memoAI.VScrollBar.Value;
end;

procedure TfrmSelector.layAIMemoScrollerMouseMove(
  Sender: TObject;
  Shift: TShiftState;
  X, Y: Single);
begin
  if not FAIPressed then
    Exit;

  var DeltaY := Y - FAIPressPos.Y;
  memoAI.VScrollBar.Value := FAIStartY - DeltaY;
end;

procedure TfrmSelector.layAIMemoScrollerMouseUp(
  Sender: TObject;
  Button: TMouseButton;
  Shift: TShiftState;
  X, Y: Single);
begin
  FAIPressed := False;
end;

procedure TfrmSelector.layAIMemoScrollerMouseWheel(
  Sender: TObject;
  Shift: TShiftState;
  WheelDelta: Integer;
  var Handled: Boolean);
begin
  memoAI.ScrollBy(0, -WheelDelta);
end;

procedure TfrmSelector.layColorClick(Sender: TObject);
begin
  var Clipboard: IFMXExtendedClipboardService;

  if
    TPlatformServices.Current.SupportsPlatformService(
      IFMXExtendedClipboardService,
      Clipboard
    )
  then
  begin
    Clipboard.SetText(lblColor.Text);
    lblColor.Text := 'Copied!';
    timerCopy.Enabled := True;
  end;
end;

procedure TfrmSelector.RGBBarChangeHandler(
  Sender: TObject;
  const AColor: TAlphaColor);
begin
  SelectorChangeHandler(FRGBBars, AColor);
  tabSelectorsChange(FRGBBars);
end;

procedure TfrmSelector.SelectorChangeHandler(
  Sender: TObject;
  const AColor: TAlphaColor);
var
  Rec: TAlphaColorRec absolute AColor;
begin
  FColor := AColor;

  colorBox.Color := FColor;

  var Text := Format('%.2x%.2x%.2x%.2x', [Rec.A, Rec.R, Rec.G, Rec.B]);

  if FRGBBars <> nil then
  begin
    if not FRGBBars.AlphaEnabled then
      Text := Text.Substring(2);

    if Sender <> FRGBBars then
      FRGBBars.SetColorWithoutEvent(FColor);
  end;

  lblColor.Text := '#' + Text;
end;

procedure TfrmSelector.SelectorMouseUpHandler(
  Sender: TObject;
  AButton: TMouseButton;
  AShift: TShiftState;
  AX, AY: Single);
begin
  if not chbxAIEnabled.IsChecked then
    Exit;

  if FColor <> FPrevColor then
  begin
    FPrevColor := FColor;
    AskAI;
  end;
end;

procedure TfrmSelector.ShowWaiter;
begin
  rectWaiter.Visible := True;
  aniWaiter.Enabled := True;

  chbxAIEnabled.Enabled := False;
end;

procedure TfrmSelector.tabSelectorsChange(Sender: TObject);
begin
  var S := TCustomSelector(tabSelectors.ActiveTab.TagObject);
  if S <> nil then
    S.SetColorWithoutEvent(FColor);
end;

procedure TfrmSelector.timerCopyTimer(Sender: TObject);
begin
  timerCopy.Enabled := False;
  SelectorChangeHandler(nil, FRGBBars.Color);
end;

end.
