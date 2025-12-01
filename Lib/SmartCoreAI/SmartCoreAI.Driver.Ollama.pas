{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Ollama;

{
  SmartCoreAI.Driver.Ollama
  -------------------------
  Local Ollama driver implementation and parameters.

  - TAIOllamaParams stores provider-specific settings (base URL, model, timeouts,
    and endpoint overrides). Intended for design-time editing.
  - TAIOllamaDriver implements IAIDriver against the Ollama HTTP API, providing chat,
    model management (show/pull/push/create/delete), JSON/stream helpers, and
    strongly-typed success/partial/error events.

  Notes
  -----
  - Methods return a TGUID RequestId that can be passed to driver
    the cancel method.
  - Threading and event synchronization depend on the base driver settings
    (for example, whether events are marshaled to the main thread).
  - Error helpers normalize provider/HTTP errors into library-wide events.
}

interface

uses
  System.Classes, System.JSON, System.Net.HttpClient,
  SmartCoreAI.Exceptions, SmartCoreAI.Types, SmartCoreAI.Driver.Ollama.Models;

type
  /// <summary>
  ///   Event raised for a partial (streamed) fragment during chat generation.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="PartialText">Incremental text fragment.</param>
  TAIPartialResponseEvent = procedure(Sender: TObject; const PartialText: string) of object;

  /// <summary>
  ///   Event raised when streaming finishes; provides the final aggregated text.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Text">Concatenated final text.</param>
  TAIPartialResponseDoneEvent = procedure(Sender: TObject; const Text: string) of object;

  /// <summary>
  ///   Design-time parameters for the Ollama driver (base URL, model, timeouts, flags, endpoints).
  /// </summary>
  /// <remarks>
  ///   Getters/Setters encapsulate storage and optional validation.
  ///   Published properties are intentionally not documented here as requested.
  /// </remarks>
  TAIOllamaParams = class(TAIDriverParams)
  private
    function GetBaseURL: string;
    procedure SetBaseURL(const AValue: string);

    function GetModel: string;
    procedure SetModel(const AValue: string);

    function GetTimeout: Integer;
    procedure SetTimeout(const AValue: Integer);

    function GetSystemPrompt: string;
    procedure SetSystemPrompt(const AValue: string);

    function GetTemplate: string;
    procedure SetTemplate(const AValue: string);

    function GetRaw: Boolean;
    procedure SetRaw(const AValue: Boolean);

    function GetGenerateEndpoint: string;
    procedure SetGenerateEndpoint(const AValue: string);

    function GetChatEndpoint: string;
    procedure SetChatEndpoint(const AValue: string);

    function GetModelsEndpoint: string;
    procedure SetModelsEndpoint(const AValue: string);

    function GetCreateModelEndPoint: string;
    procedure SetCreateModelEndPoint(const AValue: string);

    function GetPullEndPoint: string;
    procedure SetPullEndPoint(const AValue: string);

    function GetPushEndPoint: string;
    procedure SetPushEndPoint(const AValue: string);

    function GetShowEndPoint: string;
    procedure SetShowEndPoint(const AValue: string);
  published
    property BaseURL: string read GetBaseURL write SetBaseURL stored False;
    property Model: string read GetModel write SetModel stored False;
    property Timeout: Integer read GetTimeout write SetTimeout stored False;
    property SystemPrompt: string read GetSystemPrompt write SetSystemPrompt stored False;
    property Template: string read GetTemplate write SetTemplate stored False;
    property Raw: Boolean read GetRaw write SetRaw stored False;
    property Endpoint_Generate: string read GetGenerateEndpoint write SetGenerateEndpoint stored False;
    property Endpoint_Chat: string read GetChatEndpoint write SetChatEndpoint stored False;
    property Endpoint_Models: string read GetModelsEndpoint write SetModelsEndpoint stored False;
    property EndPoint_CreateModel: string read GetCreateModelEndPoint write SetCreateModelEndPoint stored False;
    property EndPoint_Pull: string read GetPullEndPoint write SetPullEndPoint stored False;
    property EndPoint_Push: string read GetPushEndPoint write SetPushEndPoint stored False;
    property EndPoint_Show: string read GetShowEndPoint write SetShowEndPoint stored False;
  end;

  /// <summary>
  ///   Ollama driver. Implements chat (standard/streamed), model management, and
  ///   JSON/stream processing operations. Emits success/error/partial events and
  ///   normalizes provider errors.
  /// </summary>
  /// <remarks>
  ///   - Consumes parameters from Params (TAIOllamaParams).
  ///   - Methods return a RequestId (TGUID) for later cancellation.
  ///   - Methods may run on background tasks and surface results via events/callbacks.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIOllamaDriver = class(TAIDriver, IAIDriver)
  private
    FOllamaParams: TAIOllamaParams;
    FImages: TArray<string>;
    FContext: TArray<Integer>;

    FOnLoadModels: TAILoadModelsEvent;
    FOnChatSuccess: TAIChatSuccessEvent;
    FOnPartialResponse: TAIPartialResponseEvent;
    FOnPartialResponseDone: TAIPartialResponseDoneEvent;

    /// <summary>
    ///   Handles streamed chat responses and raises partial/final events.
    /// </summary>
    function HandleStreamedChat(AOllamaRequest: TOllamaGenerateRequest): TGUID;

    /// <summary>
    ///   Handles non-streaming chat responses and raises completion events.
    /// </summary>
    function HandleStandardChat(AOllamaRequest: TOllamaGenerateRequest): TGUID;

    /// <summary>
    ///   Validates model, base URL, and prompt for chat operations.
    /// </summary>
    /// <param name="APrompt">User prompt.</param>
    /// <param name="ACallback">Chat callback sink.</param>
    /// <returns>True when inputs are valid; otherwise False (and an error is raised).</returns>
    function CheckAll(const APrompt:string; const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates Callback presence for operations.
    /// </summary>
    function CheckCallBack(const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates prompt content (length, emptiness, etc.).
    /// </summary>
    function CheckPrompt(const APrompt: string): Boolean;

    /// <summary>
    ///   Validates model presence for general operations.
    /// </summary>
    /// <returns>True if configuration is valid, otherwise False.</returns>
    function CheckModel: Boolean;

    /// <summary>
    ///   Validates base URL presence for general operations.
    /// </summary>
    /// <returns>True if configuration is valid, otherwise False.</returns>
    function CheckBaseURL: Boolean;

  protected
    /// <summary>
    ///   Assigns driver parameters; expects a TAIOllamaParams instance.
    /// </summary>
    procedure SetParams(const AValue: TAIDriverParams); override;

    /// <summary>
    ///   Returns the current parameter object.
    /// </summary>
    function GetParams: TAIDriverParams; override;

    /// <summary>
    ///   Returns the driver name identifier.
    /// </summary>
    function InternalGetDriverName: string; override;

    /// <summary>
    ///   Performs a quick connectivity/configuration test; returns provider message in AResponse.
    /// </summary>
    function InternalTestConnection(out AResponse: string): Boolean; override;

    /// <summary>
    ///   Returns available model identifiers by the local runing Ollam server.
    /// </summary>
    function InternalGetAvailableModels: TArray<string>; override;

    /// <summary>
    ///   Locates primary JSON data within a root response suitable for dataset mapping.
    /// </summary>
    /// <param name="ARoot">Root JSON response.</param>
    /// <param name="ADataArray">Discovered array of rows/items.</param>
    /// <param name="AInnerRoot">Optionally returned inner root to be freed by caller.</param>
    /// <param name="AOwnsArray">True if caller owns ADataArray and must free it.</param>
    /// <returns>True when JSON data has been found; otherwise False.</returns>
    function FindJSONData(const ARoot: TJSONObject; out ADataArray: TJSONArray;
      out AInnerRoot: TJSONValue; out AOwnsArray: Boolean): Boolean; override;

    /// <summary>
    ///   Raises a partial fragment event during streaming chat.
    /// </summary>
    procedure DoPartialResponse(const PartialText: string); virtual;

    /// <summary>
    ///   Raises a partial-complete event with the final aggregated text.
    /// </summary>
    procedure DoPartialResponseDone(const Text: string); virtual;

    /// <summary>
    ///   Raises an event with the available model identifiers.
    /// </summary>
    procedure DoLoadModels(const AvailableModels: TArray<string>); virtual;

    /// <summary>
    ///   Raises a chat-success event including response text and the full raw JSON.
    /// </summary>
    procedure DoChatSuccess(const ResponseText: string; const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Raises a normalized error using an exception class categorization.
    /// </summary>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIChatCallback); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using HTTP response context and message.
    /// </summary>
    procedure DoError(const AReponse: IHTTPResponse; const Msg: string); overload; virtual;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Starts a chat operation and returns a RequestId for potential cancellation.
    ///   The callback receives lifecycle events and the final/partial results.
    /// </summary>
    /// <param name="APrompt">User prompt.</param>
    /// <param name="ACallback">Chat callback sink.</param>
    /// <returns>RequestId that identifies this chat invocation.</returns>
    function Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID; override;

    /// <summary>
    ///   Convenience helper to send a simple prompt without a callback (fires driver events).
    /// </summary>
    function SimpleChat(const APrompt: string): TGUID;

    /// <summary>
    ///   Advanced chat entry point using a fully populated Ollama request.
    /// </summary>
    function ChatEx(AOllamaRequest: TOllamaGenerateRequest): TGUID;

    /// <summary>
    ///   Shows model metadata by name.
    /// </summary>
    /// <param name="AName">Model name or tag.</param>
    /// <param name="AInfo">Returned model information as text.</param>
    /// <returns>True on success; otherwise False.</returns>
    function ShowModel(const AName: string; out AInfo: string): Boolean;

    /// <summary>
    ///   Deletes a model by name.
    /// </summary>
    function DeleteModel(const AName: string): Boolean;

    /// <summary>
    ///   Pulls a model from a registry.
    /// </summary>
    function PullModel(const AName: string): Boolean;

    /// <summary>
    ///   Pushes a model to a registry.
    /// </summary>
    function PushModel(const AName: string): Boolean;

    /// <summary>
    ///   Creates a model from a Modelfile.
    /// </summary>
    function CreateModel(const AName, AModelFile: string): Boolean;

    /// <summary>
    ///   Executes a simple CLI-like command (path/name) against the Ollama runtime.
    /// </summary>
    function ExecuteSimpleCommand(const APath, AName: string): Boolean;

    /// <summary>
    ///   Generates a streamed response for a prompt (raises partial events).
    /// </summary>
    function GenerateStreamedResponse(const APrompt: string): TGUID;

    /// <summary>
    ///   Initiates an image-generation request using the callback sink for results.
    /// </summary>
    function GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID; override;

    /// <summary>
    ///   Executes a generic JSON endpoint and returns results to the callback sink.
    /// </summary>
    function ExecuteJSONRequest(const AEndpoint: string; const AParams: string; const ACallback: IAIJSONCallback): TGUID; override;

    /// <summary>
    ///   Processes a stream-based request (for example, file upload/transform) and returns results to the callback sink.
    /// </summary>
    function ProcessStream(const AEndpoint: string; const AInput: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID; override;

    /// <summary>
    ///   Array of image references used by some Ollama models/features.
    /// </summary>
    property Images: TArray<string> read FImages write FImages;

    /// <summary>
    ///   Conversation context tokens maintained across requests by some Ollama models.
    /// </summary>
    property Context: TArray<Integer> read FContext write FContext;
  published
    property Params;

    property OnLoadModels: TAILoadModelsEvent read FOnLoadModels write FOnLoadModels;
    property OnChatSuccess: TAIChatSuccessEvent read FOnChatSuccess write FOnChatSuccess;
    property OnError: TAIErrorEvent read FOnError write FOnError;
    property OnPartialResponse: TAIPartialResponseEvent read FOnPartialResponse write FOnPartialResponse;
    property OnPartialResponseDone: TAIPartialResponseDoneEvent read FOnPartialResponseDone write FOnPartialResponseDone;
  end;

implementation

uses
  System.SysUtils, System.Threading, System.Generics.Collections,
  System.Net.URLClient, SmartCoreAI.Driver.Registry, SmartCoreAI.Consts,
  SmartCoreAI.HttpClientConfig;

{ TAIOllamaParams }

function TAIOllamaParams.GetBaseURL: string;
begin
  Result := AsPath(cOllama_FldName_BaseURL, cOllama_BaseURL);
end;

function TAIOllamaParams.GetGenerateEndpoint: string;
begin
  Result := AsPath(cOllama_FldName_GenerateEndpoint, cOllama_GenerateEndpoint);
end;

function TAIOllamaParams.GetModel: string;
begin
  Result := AsString(cOllama_FldName_Model, cOllama_Def_Model);
end;

function TAIOllamaParams.GetModelsEndpoint: string;
begin
  Result := AsPath(cOllama_FldName_ModelsEndpoint, cOllama_ModelsEndpoint);
end;

function TAIOllamaParams.GetPullEndPoint: string;
begin
  Result := AsPath(cOllama_FldName_PullEndPoint, cOllama_PullEndPoint);
end;

function TAIOllamaParams.GetPushEndPoint: string;
begin
  Result := AsPath(cOllama_FldName_PushEndPoint, cOllama_PushEndPoint);
end;

function TAIOllamaParams.GetRaw: Boolean;
begin
 Result := AsBoolean(cOllama_FldName_Raw, False);
end;

function TAIOllamaParams.GetShowEndPoint: string;
begin
  Result := AsPath(cOllama_FldName_ShowEndPoint, cOllama_ShowEndPoint);
end;

function TAIOllamaParams.GetSystemPrompt: string;
begin
  Result := AsString(cOllama_FldName_SystemPrompt, '');
end;

function TAIOllamaParams.GetChatEndpoint: string;
begin
  Result := AsPath(cOllama_FldName_ChatEndpoint, cOllama_ChatEndpoint);
end;

function TAIOllamaParams.GetCreateModelEndPoint: string;
begin
  Result := AsPath(cOllama_FldName_CreateModelEndPoint, cOllama_CreateModelEndPoint);
end;

function TAIOllamaParams.GetTemplate: string;
begin
  Result := AsString(cOllama_FldName_Template, '');
end;

function TAIOllamaParams.GetTimeout: Integer;
begin
  Result := AsInteger(cOllama_FldName_Timeout, cAIDefaultConnectionTimeout);
end;

procedure TAIOllamaParams.SetBaseURL(const AValue: string);
begin
  SetAsPath(cOllama_FldName_BaseURL, AValue, cOllama_BaseURL);
end;

procedure TAIOllamaParams.SetGenerateEndpoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_GenerateEndpoint, AValue, cOllama_GenerateEndpoint);
end;

procedure TAIOllamaParams.SetModel(const AValue: string);
begin
  SetAsString(cOllama_FldName_Model, AValue, '');
end;

procedure TAIOllamaParams.SetModelsEndpoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_ModelsEndpoint, AValue, cOllama_ModelsEndpoint);
end;

procedure TAIOllamaParams.SetPullEndPoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_PullEndPoint, AValue, cOllama_PullEndPoint);
end;

procedure TAIOllamaParams.SetPushEndPoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_PushEndPoint, AValue, cOllama_PushEndPoint);
end;

procedure TAIOllamaParams.SetRaw(const AValue: Boolean);
begin
  SetAsBoolean(cOllama_FldName_Raw, AValue, False);
end;

procedure TAIOllamaParams.SetShowEndPoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_ShowEndPoint, AValue, cOllama_ShowEndPoint);
end;

procedure TAIOllamaParams.SetSystemPrompt(const AValue: string);
begin
  SetAsString(cOllama_FldName_SystemPrompt, AValue, '');
end;

procedure TAIOllamaParams.SetChatEndpoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_ChatEndpoint, AValue, cOllama_ChatEndpoint);
end;

procedure TAIOllamaParams.SetCreateModelEndPoint(const AValue: string);
begin
  SetAsPath(cOllama_FldName_CreateModelEndPoint, AValue, cOllama_CreateModelEndPoint);
end;

procedure TAIOllamaParams.SetTemplate(const AValue: string);
begin
  SetAsString(cOllama_FldName_Template, AValue, '');
end;

procedure TAIOllamaParams.SetTimeout(const AValue: Integer);
begin
  SetAsInteger(cOllama_FldName_Timeout, AValue, cAIDefaultConnectionTimeout);
end;

{ TAIOllamaDriver }

function TAIOllamaDriver.Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID;
var
  LCallBack: IAIChatCallback;
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckAll(APrompt, ACallback) then Exit;
    if not Supports(ACallback, IAIChatCallback, LCallBack) then
      DoError(cOllama_Msg_CallBackSupportError, EAIException, nil);
  except
    begin
      EndRequest(LId);
      raise;
    end;
  end;

  InvokeEvent(procedure begin ACallback.DoBeforeRequest; end);
  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
    procedure
    var
      LReq: TOllamaGenerateRequest;
      LResp: IHTTPResponse;
      LURL, LResultText: string;
      LBody: string;
      LResponseObj: TOllamaGenerateResponse;
      LStream: TStringStream;
    begin
      try
        LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Generate]);
        LReq := TOllamaGenerateRequest.Create;
        try
          LReq.Model := FOllamaParams.Model;
          LReq.Prompt := APrompt;
          LReq.Stream := False;
          LReq.Format := 'json';
          LReq.Options := nil;
          LReq.Raw := FOllamaParams.Raw;
          LReq.SystemPrompt := FOllamaParams.SystemPrompt;
          LReq.Template := FOllamaParams.Template;
          if Length(FImages) > 0 then
            LReq.Images := FImages;

          if Length(FContext) > 0 then
            LReq.Context := FContext;

          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          InvokeEvent(procedure begin ACallback.DoBeforeResponse; end);
          try
            LResp := LHttpClient.Post(LURL, LStream);
          except on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException, ACallback);
              Exit;
            end;
          end;
          InvokeEvent(procedure begin ACallback.DoAfterResponse; end);
        finally
          LStream.Free;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          InvokeEvent(procedure begin ACallback.DoFullResponse(LResp.ContentAsString(TEncoding.UTF8)); end);
          LResponseObj := TAIUtil.Deserialize<TOllamaGenerateResponse>
            (TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject);
          try
            LResultText := LResponseObj.Response;
            InvokeEvent(procedure begin ACallback.DoResponse(LResultText); end);
            if Assigned(OnChatSuccess) then
              InvokeEvent(procedure begin OnChatSuccess(Self, LResultText, LResp.ContentAsString(TEncoding.UTF8)); end);
          finally
            LResponseObj.Free;
          end;
        end
        else
          DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
      except
        on E: Exception do
          DoError(E.Message, EAIException, ACallBack);
      end;
    end);
end;

function TAIOllamaDriver.ChatEx(AOllamaRequest: TOllamaGenerateRequest): TGUID;
begin
  if not CheckModel then Exit;
  if not CheckBaseURL then Exit;

  if AOllamaRequest.Stream then
    Result := HandleStreamedChat(AOllamaRequest)
  else
    Result := HandleStandardChat(AOllamaRequest);
end;

function TAIOllamaDriver.CheckBaseURL: Boolean;
begin
  Result := True;
  if FOllamaParams.BaseURL.IsEmpty then
  begin
    Result := False;
    DoError(collama_Msg_MissingBaseURLError, EAIValidationException, nil);
  end;
end;

function TAIOllamaDriver.CheckCallBack(const ACallback: IAIChatCallback): Boolean;
var
  LCallBack: IAIChatCallback;
begin
  Result := True;
  if not Assigned(ACallback) or not Supports(ACallback, IAIChatCallback, LCallBack) then
  begin
    DoError(cOllama_Msg_CallBackSupportError, EAIValidationException, LCallBack);
    Result := False;
  end
end;

function TAIOllamaDriver.CheckModel: Boolean;
begin
  Result := True;
  if FOllamaParams.Model.IsEmpty then
  begin
    DoError(cOllama_Msg_MissingModelsError, EAIValidationException, nil);
    Result := False;
  end;
end;

function TAIOllamaDriver.CheckPrompt(const APrompt: string): Boolean;
begin
  Result := True;
  if APrompt.Trim.IsEmpty then
  begin
    DoError(cOllama_Msg_PromptMissingError, EAIValidationException, nil);
    Result := False;
  end;
end;

function TAIOllamaDriver.CheckAll(const APrompt: string; const ACallback: IAIChatCallback): Boolean;

begin
  Result := True;

  if not CheckCallBack(ACallback) then
    Result := False
  else if not CheckPrompt(APrompt) then
    Result := False
  else if not CheckModel then
    Result := False
  else if not CheckBaseURL then
    Result := False;
end;

constructor TAIOllamaDriver.Create(AOwner: TComponent);
begin
  inherited;
  FOllamaParams := TAIOllamaParams.Create;
end;

function TAIOllamaDriver.CreateModel(const AName, AModelFile: string): Boolean;
var
  LHttpClient: THTTPClient;
  LReq: TOllamaCreateModelRequest;
  LResp: IHTTPResponse;
  LBody, LURL: string;
  LStream: TStringStream;
begin
  Result := False;
  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  try
    LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.EndPoint_CreateModel]);
    LReq := TOllamaCreateModelRequest.Create;
    try
      LReq.Name := AName;
      LReq.ModelFile := AModelFile;

      LBody := TAIUtil.Serialize(LReq);
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(LURL, LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException, nil);
            Exit;
          end;
        end;

        if TAIUtil.IsSuccessfulResponse(LResp) then
          Result := True
        else
          DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
      finally
        LStream.Free;
      end;
    finally
      LReq.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;

function TAIOllamaDriver.DeleteModel(const AName: string): Boolean;
begin
  Result := ExecuteSimpleCommand(cOllama_DeleteModelEndPoint, AName);
end;

destructor TAIOllamaDriver.Destroy;
begin
  FOllamaParams.Free;
  inherited;
end;

procedure TAIOllamaDriver.DoChatSuccess(const ResponseText, FullJsonResponse: string);
begin
  if Assigned(FOnChatSuccess) then
    InvokeEvent(procedure begin FOnChatSuccess(Self, ResponseText, FullJsonResponse); end)
end;

procedure TAIOllamaDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIChatCallback);
begin
  if Assigned(Callback) then
    InvokeEvent(procedure begin Callback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else if Assigned(ExceptionClass) then
    raise ExceptionClass.Create(Msg);
end;

procedure TAIOllamaDriver.DoError(const AReponse: IHTTPResponse; const Msg: string);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AReponse.StatusCode, AReponse.ContentAsString(TEncoding.UTF8), AReponse.Headers, cAIRequestFailed); end);
end;

procedure TAIOllamaDriver.DoLoadModels(const AvailableModels: TArray<string>);
begin
  if Assigned(FOnLoadModels) then
    FOnLoadModels(Self, AvailableModels);
end;

procedure TAIOllamaDriver.DoPartialResponse(const PartialText: string);
begin
  if Assigned(FOnPartialResponse) then
    FOnPartialResponse(Self, PartialText);
end;

procedure TAIOllamaDriver.DoPartialResponseDone(const Text: string);
begin
  if Assigned(FOnPartialResponseDone) then
    FOnPartialResponseDone(Self, Text);
end;

function TAIOllamaDriver.ExecuteJSONRequest(
  const AEndpoint: string; const AParams: string;
  const ACallback: IAIJSONCallback): TGUID;
begin
  DoError(Format(cAI_Msg_JSON_NotSupported, [DriverName]), EAIException, nil);
end;

function TAIOllamaDriver.ExecuteSimpleCommand(const APath, AName: string): Boolean;
var
  LHttpClient: THTTPClient;
  LReq: TOllamaModelNameRequest;
  LResp: IHTTPResponse;
  LBody, LURL: string;
  LStream: TStringStream;
begin
  Result := False;
  if not CheckModel then Exit;
  if not CheckBaseURL then Exit;
  if APath.IsEmpty then
  begin
    DoError(cOllama_Msg_MissingPathError, EAIException, nil);
    Exit;
  end
  else if AName.IsEmpty then
  begin
    DoError(cOllama_Msg_MissingNameError, EAIException, nil);
    Exit;
  end;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  try
    LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, APath);
    LReq := TOllamaModelNameRequest.Create;
    try
      LReq.Name := AName;
      LBody := TAIUtil.Serialize(LReq);
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(LURL, LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException, nil);
            Exit;
          end;
        end;

        Result := TAIUtil.IsSuccessfulResponse(LResp);
      finally
        LStream.Free;
      end;
    finally
      LReq.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;

function TAIOllamaDriver.FindJSONData(const ARoot: TJSONObject;
  out ADataArray: TJSONArray; out AInnerRoot: TJSONValue;
  out AOwnsArray: Boolean): Boolean;

  function TryOllamaPath(const R: TJSONObject; out Inner: TJSONValue; out Arr: TJSONArray): Boolean;
  var
    MsgObj: TJSONObject; S: string;
  begin
    Result := False; Inner := nil; Arr := nil;

    if R.TryGetValue<string>('response', S) and (S <> '') then
    begin
      Inner := TAIUtil.ExtractJSONValueFromText(S);
      if Assigned(Inner) then
      begin
        Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
        if Assigned(Arr) then Exit(True)
        else begin Inner.Free; Inner := nil; end;
      end;
    end;

    if R.TryGetValue<TJSONObject>('message', MsgObj) then
      if MsgObj.TryGetValue<string>('content', S) and (S <> '') then
      begin
        Inner := TAIUtil.ExtractJSONValueFromText(S);
        if Assigned(Inner) then
        begin
          Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
          if Assigned(Arr) then Exit(True)
          else begin Inner.Free; Inner := nil; end;
        end;
      end;
  end;

begin
  ADataArray := nil;
  AInnerRoot := nil;
  AOwnsArray := False;

  if TryOllamaPath(ARoot, AInnerRoot, ADataArray) then
    Exit(True);

  Result := inherited FindJSONData(ARoot, ADataArray, AInnerRoot, AOwnsArray);
end;

function TAIOllamaDriver.GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID;
begin
  DoError(Format(cAI_Msg_Image_NotSupport, [DriverName]), EAIException, nil);
end;

function TAIOllamaDriver.GenerateStreamedResponse(const APrompt: string): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckPrompt(APrompt) then Exit;
    if not CheckModel then Exit;
    if not CheckBaseURL then Exit;
  except
    begin
      EndRequest(LId);
      raise;
    end;
  end;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
    procedure
    var
      LReq: TOllamaGenerateRequest;
      LResp: IHTTPResponse;
      LLine: string;
      LStream: TStreamReader;
      LJSONLine: TJSONObject;
      LRespPart: TOllamaGenerateResponse;
      LURL, LBody: string;
      LStreamStr: TStringStream;
    begin
      LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Generate]);
      LReq := TOllamaGenerateRequest.Create;
      try
        LReq.Model := FOllamaParams.Model;
        LReq.Prompt := APrompt;
        LReq.Stream := True;
        LReq.Format := 'json';
        LReq.Options := nil;

        LBody := TAIUtil.Serialize(LReq);
      finally
        LReq.Free;
      end;

      LStreamStr := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        LHttpClient.CustomHeaders['Accept'] := cOllama_CHeader_Accept;
        try
          LResp := LHttpClient.Post(LURL, LStreamStr, nil);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException, nil);
            Exit;
          end;
        end;
      finally
        LStreamStr.Free;
      end;

      if LState.Cancelled then
        Exit;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        LStream := TStreamReader.Create(LResp.ContentStream, TEncoding.UTF8);
        try
          while not LStream.EndOfStream do
          begin
            LLine := LStream.ReadLine.Trim;
            if LLine.IsEmpty then
              Continue;

            try
              LJSONLine := TJSONObject.ParseJSONValue(LLine, False, True) as TJSONObject;
              try
                if Assigned(LJSONLine) then
                begin
                  LRespPart := TAIUtil.Deserialize<TOllamaGenerateResponse>(LJSONLine);

                  DoPartialResponse(LRespPart.Response);

                  if LRespPart.Done then
                    DoPartialResponseDone(LRespPart.Response);
                end;

              finally
                LJSONLine.Free;
              end;
            except on E: Exception do
              DoError(E.Message, EAIValidationException, nil);
            end;
          end;
        finally
          LStream.Free;
        end;
      end
      else
        DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
    end);
end;

function TAIOllamaDriver.GetParams: TAIDriverParams;
begin
  Result := FOllamaParams;
end;

function TAIOllamaDriver.HandleStandardChat(AOllamaRequest: TOllamaGenerateRequest): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
    procedure
    var
      LResp: IHTTPResponse;
      LRespObj: TOllamaGenerateResponse;
      LURL, LBody: string;
      LStream: TStringStream;
    begin
      try
        LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Generate]);
        LBody := TAIUtil.Serialize(AOllamaRequest);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
          except on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException, nil);
              Exit;
            end;
          end;
        finally
          LStream.Free;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LRespObj := TAIUtil.Deserialize<TOllamaGenerateResponse>
            (TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject);
          try
            DoChatSuccess(LRespObj.Response, LResp.ContentAsString(TEncoding.UTF8));
          finally
            LRespObj.Free;
          end;
        end
        else
          DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
      except on E: Exception do
        DoError(E.Message, EAIException, nil);
      end;
    end);
end;

function TAIOllamaDriver.HandleStreamedChat(AOllamaRequest: TOllamaGenerateRequest): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
    procedure
    var
      LURL, LLine, LAccum: string;
      LResp: IHTTPResponse;
      LBuffer: TBytes;
      LStreamText, LBody: string;
      LJSON: TJSONObject;
      LContentStream: TMemoryStream;
      LRespObj: TOllamaGenerateResponse;
      LStream: TStringStream;
    begin
      try
        LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Generate]);
        LBody := TAIUtil.Serialize(AOllamaRequest);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
          except on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException, nil);
              Exit;
            end;
          end;
        finally
          LStream.Free;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LContentStream := TMemoryStream.Create;
          try
            LResp.ContentStream.Position := 0;
            LContentStream.CopyFrom(LResp.ContentStream, LResp.ContentLength);
            SetLength(LBuffer, LContentStream.Size);
            LContentStream.Position := 0;
            LContentStream.ReadBuffer(LBuffer, Length(LBuffer));
            LStreamText := TEncoding.UTF8.GetString(LBuffer);

            LAccum := EmptyStr;
            for LLine in LStreamText.Split([sLineBreak], TStringSplitOptions.ExcludeEmpty) do
            begin
              LJSON := TJSONObject.ParseJSONValue(LLine, False, True) as TJSONObject;
              if not Assigned(LJSON) then
                Continue;

              LRespObj := TAIUtil.Deserialize<TOllamaGenerateResponse>(LJSON);
              try
                if not LRespObj.Response.IsEmpty then
                begin
                  LAccum := LAccum + LRespObj.Response;
                  DoPartialResponse(LRespObj.Response);
                end;

                if LRespObj.Done then
                  DoChatSuccess(LAccum, LResp.ContentAsString(TEncoding.UTF8));
              finally
                LJSON.Free;
                LRespObj.Free;
              end;
            end;
          finally
            LContentStream.Free;
          end;
        end
        else
          DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
      except
        on E: Exception do
          DoError(E.Message, EAIException, nil);
      end;
    end);
end;

function TAIOllamaDriver.InternalGetAvailableModels: TArray<string>;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LRespObj: TOllamaModelTagResponse;
  LList: TList<string>;
  LModel: TOllamaModelInfo;
begin
  LList := TList<string>.Create;
  try
    LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
    try
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Models]));
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException, nil);
          Exit;
        end;
      end;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        LRespObj := TAIUtil.Deserialize<TOllamaModelTagResponse>
          (TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject);
        try
          for LModel in LRespObj.Models do
            LList.Add(LModel.Name);

          DoLoadModels(LList.ToArray);
        finally
          LRespObj.Free;
        end;
      end
      else
        DoError(LResp, Format(cAI_Msg_ModelsError, [LResp.StatusText, LResp.StatusCode]));
    finally
      LHttpClient.Free;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TAIOllamaDriver.InternalGetDriverName: string;
begin
  Result := cOllama_DriverName;
end;

function TAIOllamaDriver.InternalTestConnection(out AResponse: string): Boolean;
var
  LModels: TArray<string>;
begin
  try
    LModels := InternalGetAvailableModels;
    Result := Length(LModels) > 0;
    if Result then
      AResponse := Format(cOllama_Msg_ModelsFound, [Length(LModels)])
    else
      AResponse := cAI_Msg_ModelsError;
  except
    on E: Exception do
    begin
      Result := False;
      AResponse := 'Exception: ' + E.Message;
    end;
  end;
end;

function TAIOllamaDriver.ProcessStream(const AEndpoint: string; const AInput: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID;
begin
  DoError(Format(cAI_Msg_Stream_NotSupport, [DriverName]), EAIException, nil);
end;

function TAIOllamaDriver.PullModel(const AName: string): Boolean;
begin
  Result := ExecuteSimpleCommand(FOllamaParams.EndPoint_Pull, AName);
end;

function TAIOllamaDriver.PushModel(const AName: string): Boolean;
begin
  Result := ExecuteSimpleCommand(FOllamaParams.EndPoint_Push, AName);
end;

procedure TAIOllamaDriver.SetParams(const AValue: TAIDriverParams);
begin
  FOllamaParams.SetStrings(AValue);
end;

function TAIOllamaDriver.ShowModel(const AName: string; out AInfo: string): Boolean;
var
  LHttpClient: THTTPClient;
  LReq: TOllamaModelNameRequest;
  LResp: IHTTPResponse;
  LBody, LURL: string;
  LStream: TStringStream;
begin
  Result := False;
  if not CheckModel then Exit;
  if not CheckBaseURL then Exit;

  AInfo := EmptyStr;
  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  try
    LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.EndPoint_Show]);
    LReq := TOllamaModelNameRequest.Create;
    try
      LReq.Name := AName;
      LBody := TAIUtil.Serialize(LReq);
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(LURL, LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException, nil);
            Exit;
          end;
        end;
      finally
        LStream.Free;
      end;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        AInfo := LResp.ContentAsString(TEncoding.UTF8);
        Result := True;
      end
      else
        DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
    finally
      LReq.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;

function TAIOllamaDriver.SimpleChat(const APrompt: string): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckPrompt(APrompt) then Exit;
    if not CheckModel then Exit;
    if not CheckBaseURL then Exit;
  except
    begin
      EndRequest(LId);
      raise;
    end;
  end;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
    procedure
    var
      LReq: TOllamaGenerateRequest;
      LResp: IHTTPResponse;
      LURL, LResultText, LBody: string;
      LResponseObj: TOllamaGenerateResponse;
      LStream: TStringStream;
    begin
      try
        LURL := TAIUtil.GetSafeFullURL(FOllamaParams.BaseURL, [FOllamaParams.Endpoint_Generate]);
        LReq := TOllamaGenerateRequest.Create;
        try
          LReq.Model := FOllamaParams.Model;
          LReq.Prompt := APrompt;
          LReq.Stream := False;
          LReq.Format := 'json';
          LReq.Options := nil;
          LReq.Raw := FOllamaParams.Raw;
          LReq.SystemPrompt := FOllamaParams.SystemPrompt;
          LReq.Template := FOllamaParams.Template;

          if Length(FImages) > 0 then
            LReq.Images := FImages;

          if Length(FContext) > 0 then
            LReq.Context := FContext;

          try
            LBody := TAIUtil.Serialize(LReq);
          except on E: Exception do
            begin
              DoError(E.Message, EAIJSONException, nil);
              Exit;
            end;
          end;

          LStream := TStringStream.Create(LBody, TEncoding.UTF8);
          try
            try
              LResp := LHttpClient.Post(LURL, LStream);
            except on E: Exception do
              begin
                DoError(E.Message, EAIHTTPException, nil);
                Exit;
              end;
            end;
          finally
            LStream.Free;
          end;

          if LState.Cancelled then
            Exit;

          if TAIUtil.IsSuccessfulResponse(LResp) then
          begin
            LResponseObj := TAIUtil.Deserialize<TOllamaGenerateResponse>(TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject);
            try
              LResultText := LResponseObj.Response;
              if Assigned(FOnChatSuccess) then
                InvokeEvent(procedure begin FOnChatSuccess(Self, LResultText, LResp.ContentAsString(TEncoding.UTF8)); end);
            finally
              LResponseObj.Free;
            end;
          end
          else
            DoError(LResp, Format(cOllama_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
        finally
          LReq.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException, nil);
      end;
    end);
end;

procedure RegisterOllamaDriver;
begin
  TAIDriverRegistry.RegisterDriverClass(
  cOllama_DriverName,
  cOllama_API_Name,
  cOllama_Description,
  COllama_Category,
  TAIOllamaDriver
  );
end;

initialization
  RegisterOllamaDriver;

end.
