{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Comp.Stream;

{
  SmartCoreAI.Comp.Stream
  -----------------------
  Component wrapper for stream-oriented requests (uploading/processing a file and
  receiving streamed results). It delegates execution to the active driver through
  DriverIntf on the associated Connection and surfaces results via success/partial/error
  events.

  Notes
  -----
  - Set Endpoint, Input (existing file path), and Params before calling Execute.
  - The driver controls threading and event synchronization. If your UI relies on
    main-thread handlers, ensure the driver is configured to synchronize events.
  - For cancellation, use the RequestId returned by the driver-side invocation and
    call the corresponding cancel routine on the driver.
}
interface

uses
  System.Classes, System.SysUtils, System.JSON, SmartCoreAI.Types,
  SmartCoreAI.Comp.Connection;

type
  /// <summary>
  ///   Event raised when a streamed request completes successfully.
  /// </summary>
  /// <param name="Sender">
  ///   The TAIStreamRequest instance that raised the event.
  /// </param>
  /// <param name="AStream">
  ///   The resulting stream produced by the provider. The caller owns any
  ///   subsequent processing; lifetime semantics depend on driver implementation.
  /// </param>
  TAIStreamRequestSuccessEvent = procedure(Sender: TObject; const AStream: TStream) of object;

  /// <summary>
  ///   Event raised when a partial data chunk is available during streaming.
  /// </summary>
  /// <param name="Sender">
  ///   The TAIStreamRequest instance that raised the event.
  /// </param>
  /// <param name="APartialData">
  ///   A chunk of bytes representing incremental data received so far.
  /// </param>
  TAIStreamRequestPartialEvent = procedure(Sender: TObject; const APartialData: TBytes) of object;

  /// <summary>
  ///   Declarative request component for stream-based operations like Audio transcription,
  ///   Speech recognition, understanding audio, video, or image, etc
  /// It validates configuration (Connection, Driver, Endpoint, Input, Params) and delegates
  ///   execution to the active driver, raising events for success, partial chunks,
  ///   and errors.
  /// </summary>
  /// <remarks>
  ///   - Input must point to an existing file path.
  ///   - Params is owned by the component and is cloned on assignment to avoid
  ///     double-free or cross-ownership issues.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIStreamRequest = class(TAIRequest, IAIStreamCallback)
  private
    FEndpoint: string;
    FInputFileName: string;
    FParams: TJSONObject;
    FOnSuccess: TAIStreamRequestSuccessEvent;
    FOnPartial: TAIStreamRequestPartialEvent;
    FOnError: TAIErrorEvent;

    /// <summary>
    ///   Assigns Params by cloning the provided JSON object. The component owns
    ///   the resulting instance and frees any previously assigned object.
    /// </summary>
    /// <param name="Value">Source JSON object to clone and assign.</param>
    procedure SetParam(const Value: TJSONObject);
  protected
    /// <summary>
    ///   Validates configuration and delegates execution to the driver using
    ///   Endpoint, Input, and Params. Raises configuration exceptions when
    ///   required members are missing or invalid.
    /// </summary>
    function DoExecute: TGUID; override;

    // IAIStreamCallback implementation

    /// <summary>
    ///   Delivers the final stream upon successful completion.
    /// </summary>
    /// <param name="AStream">The resulting stream from the provider(AI Engine).</param>
    procedure DoSuccess(const AStream: TStream); virtual;

    /// <summary>
    ///   Delivers a normalized error message if the request fails.
    /// </summary>
    /// <param name="AErrorMessage">Human-readable error description.</param>
    procedure DoError(const AErrorMessage: string); virtual;

    /// <summary>
    ///   Delivers a partial chunk of streamed data when available.
    /// </summary>
    /// <param name="APartialData">Incremental bytes received so far.</param>
    procedure DoPartial(const APartialData: TBytes); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Arbitrary request parameters owned by the component. On assignment, the
    ///   provided JSON object is cloned; the component frees its current instance.
    /// </summary>
    property Params: TJSONObject read FParams write SetParam;
  published
    /// <summary>
    ///   Input file path to send. Must refer to an existing file before Execute is called.
    /// </summary>
    property InputFileName: string read FInputFileName write FInputFileName;
    property Endpoint: string read FEndpoint write FEndpoint;
    property OnSuccess: TAIStreamRequestSuccessEvent read FOnSuccess write FOnSuccess;
    property OnPartial: TAIStreamRequestPartialEvent read FOnPartial write FOnPartial;
    property OnError: TAIErrorEvent read FOnError write FOnError;
  end;

implementation

uses
  SmartCoreAI.Consts, SmartCoreAI.Exceptions;

function TAIStreamRequest.DoExecute: TGUID;
begin
  if not Assigned(Connection) then
    raise EAIConfigException.Create(cAIConnectionNotAssigned);

  if not Assigned(Connection.DriverIntf) then
    raise EAIConfigException.Create(cAIDriverNotFound);

  if not Assigned(FParams) then
    raise EAIConfigException.Create(cAI_Msg_ParamsNotAssigned);

  if (FInputFileName.IsEmpty) or not FileExists(FInputFileName) then
    raise EAIConfigException.Create(cAI_Msg_NoInputFilePath);

  if FEndpoint.Trim.IsEmpty then
    raise EAIConfigException.Create(cAI_Msg_EmptyEndpoint);

  Result := Connection.DriverIntf.ProcessStream(FEndpoint, FInputFileName, FParams, Self);
end;

procedure TAIStreamRequest.DoSuccess(const AStream: TStream);
begin
  if Assigned(FOnSuccess) then
    FOnSuccess(Self, AStream);
end;

procedure TAIStreamRequest.SetParam(const Value: TJSONObject);
var
  LNew: TJSONObject;
begin
  if Value = FParams then
    Exit;

  if Value = nil then
  begin
    FreeAndNil(FParams);
    Exit;
  end;

  // This component better owns its own instance to avoid double-freeing.
  LNew := TJSONObject(Value.Clone);
  try
    FreeAndNil(FParams);
    FParams := LNew;
  except on E: Exception do
    begin
      LNew.Free;
      raise EAIConfigException.Create(E.Message);
    end;
  end;
end;

procedure TAIStreamRequest.DoPartial(const APartialData: TBytes);
begin
  if Assigned(FOnPartial) then
    FOnPartial(Self, APartialData);
end;

constructor TAIStreamRequest.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FParams := nil;
end;

destructor TAIStreamRequest.Destroy;
begin
  FParams.Free;
  inherited Destroy;
end;

procedure TAIStreamRequest.DoError(const AErrorMessage: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, AErrorMessage);
end;

end.
