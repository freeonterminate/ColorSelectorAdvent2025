{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Comp.Chat;

interface

uses
  System.Classes, System.SysUtils, System.JSON, SmartCoreAI.Types,
  SmartCoreAI.Comp.Connection;

type
  TAIChatResponseEvent = procedure(Sender: TObject; const Text: string) of object;
  TAIFullResponseEvent = procedure(Sender: TObject; const FullJsonResponse: string) of object;
  TAIPartialResponseEvent = procedure(Sender: TObject; const PartialText: string) of object;

  /// <summary>
  ///   Chat request component that simplifies chat operation through the AI connection and it's active Driver
  /// </summary>
  /// <remarks>
  ///   - Use "Chat" to start a chat operation. The function returns a
  ///     request GUID that can be passed to the cancel method.
  ///   - This component implements IAIChatCallback, and the driver will call
  ///     back into the protected DoXxxx methods to raise published events.
  ///   - Direct execution via DoExecute is not supported; use Chat.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIChatRequest = class(TAIRequest, IAIChatCallback)
  private
    FOnBeforeRequest: TNotifyEvent;
    FOnAfterRequest: TNotifyEvent;
    FOnBeforeResponse: TNotifyEvent;
    FOnAfterResponse: TNotifyEvent;
    FOnResponse: TAIChatResponseEvent;
    FOnError: TAIErrorEvent;
    FOnFullResponse: TAIFullResponseEvent;
    FOnPartialResponse: TAIPartialResponseEvent;
  protected
    // IAIChatCallback

     /// <summary>
    ///   Called by the driver immediately before the HTTP/API request is issued.
    /// </summary>
    /// <remarks>
    ///   Use this to update UI state (e.g., show spinners) or reset buffers.
    /// </remarks>
    procedure DoBeforeRequest; virtual;

    /// <summary>
    ///   Called by the driver right after the HTTP/API request has been sent.
    /// </summary>
    /// <remarks>
    ///   Can be used for logging, timing, or advanced telemetry.
    /// </remarks>
    procedure DoAfterRequest; virtual;

    /// <summary>
    ///   Called by the driver just before it begins dispatching the response.
    /// </summary>
    procedure DoBeforeResponse; virtual;

    /// <summary>
    ///   Called by the driver when it has finished dispatching the response.
    /// </summary>
    procedure DoAfterResponse; virtual;

    /// <summary>
    ///   Delivers the final, consolidated response text for the request.
    /// </summary>
    /// <param name="Text">
    ///   The final response text.
    /// </param>
    procedure DoResponse(const Text: string); virtual;

    /// <summary>
    ///   Delivers a provider- or driver-normalized error message for the request.
    /// </summary>
    /// <param name="ErrorMessage">
    ///   A human-readable error description (already extracted/normalized by the driver).
    /// </param>
    /// <remarks>
    ///   Depending on driver setting, if SynchronizeEvent = True, this will be called on the main thread,
    ///  if SynchronizeEvent = False, will be called on a worker thread.
    /// </remarks>
    procedure DoError(const ErrorMessage: string); virtual;

    /// <summary>
    ///   Delivers the complete raw JSON response as a string (for diagnostics or custom parsing).
    /// </summary>
    /// <param name="FullJsonResponse">
    ///   Raw JSON document returned by the provider, serialized as text.
    /// </param>
    procedure DoFullResponse(const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Delivers an incremental piece of the streamed response text.
    /// </summary>
    /// <param name="PartialText">
    ///   The incremental (partial) text chunk received so far.
    /// </param>
    procedure DoPartialResponse(const PartialText: string); virtual;

    /// <summary>
    ///   Execution entry point from the base class. Not supported for chat requests.
    /// </summary>
    /// <remarks>
    ///   This component is designed to be invoked via "Chat" and not by
    ///   calling Execute on the base "TAIRequest". This method will
    ///   raise an exception or route an error event accordingly.
    /// </remarks>
    function DoExecute: TGUID; override;
  public
    /// <summary>
    ///   Starts a chat operation using the active driver configured on
    ///   "SmartCoreAI.Comp.Connection.TAIConnection".
    /// </summary>
    /// <param name="APrompt">
    ///   The user prompt to send to the provider.
    /// </param>
    /// <returns>
    ///   A "TGUID" request identifier assigned by the driver. Use this value with
    ///   driver-level cancel method (e.g., Driver.Cancel(RequestId)) to cooperatively
    ///   cancel the in-flight operation.
    ///   The returned RequestId is unique per Request/invocation.
    /// </returns>
    /// <exception> "SmartCoreAI.Exceptions.EAIConfigException"
    ///   Raised when the Connection is not assigned or no driver is available.
    /// </exception>
    /// <remarks>
    ///  The driver will invoke
    ///   DoBeforeRequest, DoAfterRequest,
    ///   DoBeforeResponse, DoAfterResponse,
    ///   DoPartialResponse(if there is a chunk), DoFullResponse, and DoResponse.
    ///   if there is any error it will invoke DoError as the request progresses.
    /// </remarks>
    function Chat(const APrompt: string): TGUID;
  published
    property OnBeforeRequest: TNotifyEvent read FOnBeforeRequest write FOnBeforeRequest;
    property OnAfterRequest: TNotifyEvent read FOnAfterRequest write FOnAfterRequest;
    property OnBeforeResponse: TNotifyEvent read FOnBeforeResponse write FOnBeforeResponse;
    property OnAfterResponse: TNotifyEvent read FOnAfterResponse write FOnAfterResponse;
    property OnResponse: TAIChatResponseEvent read FOnResponse write FOnResponse;
    property OnError: TAIErrorEvent read FOnError write FOnError;
    property OnFullResponse: TAIFullResponseEvent read FOnFullResponse write FOnFullResponse;
    property OnPartialResponse: TAIPartialResponseEvent read FOnPartialResponse write FOnPartialResponse;
  end;

implementation

uses
  SmartCoreAI.Consts, SmartCoreAI.Exceptions;

{ TAIChatRequest }

function TAIChatRequest.Chat(const APrompt: string): TGUID;
begin
  if not Assigned(Connection) then
    raise EAIConfigException.Create(cAIConnectionNotAssigned);
  if not Assigned(Connection.DriverIntf) then
    raise EAIConfigException.Create(cAIDriverNotFound);

  Result := Connection.DriverIntf.Chat(APrompt, Self); // Passes as IAIChatCallback
end;

procedure TAIChatRequest.DoBeforeRequest;
begin
  if Assigned(FOnBeforeRequest) then
    FOnBeforeRequest(Self);
end;

procedure TAIChatRequest.DoAfterRequest;
begin
  if Assigned(FOnAfterRequest) then
    FOnAfterRequest(Self);
end;

procedure TAIChatRequest.DoBeforeResponse;
begin
  if Assigned(FOnBeforeResponse) then
    FOnBeforeResponse(Self);
end;

procedure TAIChatRequest.DoAfterResponse;
begin
  if Assigned(FOnAfterResponse) then
    FOnAfterResponse(Self);
end;

procedure TAIChatRequest.DoResponse(const Text: string);
begin
  if Assigned(FOnResponse) then
    FOnResponse(Self, Text);
end;

procedure TAIChatRequest.DoError(const ErrorMessage: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, ErrorMessage);
end;

function TAIChatRequest.DoExecute: TGUID;
begin
  if Assigned(FOnError) then
    FOnError(Self, cAI_Msg_Execution_Not_Supported)
  else
    raise EAIException.Create(cAI_Msg_Execution_Not_Supported);
end;

procedure TAIChatRequest.DoFullResponse(const FullJsonResponse: string);
begin
  if Assigned(FOnFullResponse) then
    FOnFullResponse(Self, FullJsonResponse);
end;

procedure TAIChatRequest.DoPartialResponse(const PartialText: string);
begin
  if Assigned(FOnPartialResponse) then
    FOnPartialResponse(Self, PartialText);
end;

end.
