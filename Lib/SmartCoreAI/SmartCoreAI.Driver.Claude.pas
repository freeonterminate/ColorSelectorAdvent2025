{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Claude;

{
  SmartCoreAI.Driver.Claude
  -------------------------
  Anthropic Claude driver implementation and parameters.

  - TAIClaudeParams stores provider-specific settings (BaseURL, API key, model, timeouts,
    and endpoint overrides). Designed to be edited at design-time.
  - TAIClaudeDriver implements IAIDriver against the Claude HTTP API, provides chat,
    files, models, and batches operations, and raises strongly-typed success/partial/error
    events.

  Notes
  -----
  - All functions return a TGUID RequestId that you can pass to the cancel method on the driver.
  - Threading and event synchronization depend on the base driver settings (e.g., whether events
    are queued onto the main thread).
  - Error handling helpers (DoError overloads) normalize provider/HTTP errors into library events.
}
interface

uses
  System.Classes, System.SysUtils, System.JSON, SmartCoreAI.Types,
  SmartCoreAI.Driver.Claude.Models, System.Net.HttpClient, SmartCoreAI.Exceptions;

type
  /// <summary>
  ///   Event raised when a list of files is retrieved successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Files">Array of file descriptors.</param>
  TAIFilesSuccessEvent = procedure(Sender: TObject; const Files: TArray<TClaudeFileInfo>) of object;

  /// <summary>
  ///   Event raised when a file upload completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="FileInfo">Information about the uploaded file.</param>
  TAIUploadSuccessEvent = procedure(Sender: TObject; const FileInfo: TClaudeFileInfo) of object;

  /// <summary>
  ///   Event raised when a batch operation is created successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="BatchID">Provider-assigned batch identifier.</param>
  TAIBatchSuccessEvent = procedure(Sender: TObject; const BatchID: string) of object;

  /// <summary>
  ///   Event raised when a list of batches is retrieved successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Data">Raw JSON array containing batch entries.</param>
  TAIListBatchesSuccessEvent = procedure(Sender: TObject; const Data: TJSONArray) of object;

  /// <summary>
  ///   Event raised for partial (streamed) fragments during chat/message streaming.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Fragment">Incremental text fragment.</param>
  TAIPartialEvent = procedure(Sender: TObject; const Fragment: string) of object;

  /// <summary>
  ///   Event raised when a streaming session completes and the full text is available.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="FullText">Concatenated final text.</param>
  TAIPartialCompleteEvent = procedure(Sender: TObject; const FullText: string) of object;

  /// <summary>
  ///   Design-time parameters for the Claude driver (base URL, API key, model, limits, endpoints).
  /// </summary>
  TAIClaudeParams = class(TAIDriverParams)
  private
    function GetBaseURL: string;
    procedure SetBaseURL(const AValue: string);

    function GetAPIKey: string;
    procedure SetAPIKey(const AValue: string);

    function GetMaxToken: Integer;
    procedure SetMaxToken(const AValue: Integer);

    function GetModel: string;
    procedure SetModel(const AValue: string);

    function GetAnthropicVersion: string;
    procedure SetAnthropicVersion(const AValue: string);

    function GetTimeout: Integer;
    procedure SetTimeout(const AValue: Integer);

    function GetMessagesEndpoint: string;
    procedure SetMessagesEndpoint(const AValue: string);

    function GetFilesEndpoint: string;
    procedure SetFilesEndpoint(const AValue: string);

    function GetModelsEndpoint: string;
    procedure SetModelsEndpoint(const AValue: string);

    function GetBatchesEndPoint: string;
    procedure SetBatchesEndPoint(const AValue: string);
  published
    property BaseURL: string read GetBaseURL write SetBaseURL stored False;
    property APIKey: string read GetAPIKey write SetAPIKey stored False;
    property MaxToken: Integer read GetMaxToken write SetMaxToken stored False;
    property Model: string read GetModel write SetModel stored False;
    property AnthropicVersion: string read GetAnthropicVersion write SetAnthropicVersion stored False;
    property Timeout: Integer read GetTimeout write SetTimeout stored False;

    property Endpoint_Messages: string read GetMessagesEndpoint write SetMessagesEndpoint stored False;
    property Endpoint_Files: string read GetFilesEndpoint write SetFilesEndpoint stored False;
    property Endpoint_Models: string read GetModelsEndpoint write SetModelsEndpoint stored False;
    property EndPoint_Batches: string read GetBatchesEndPoint write SetBatchesEndPoint stored False;
  end;

  /// <summary>
  ///   Anthropic Claude driver. Implements chat (sync/stream), models, files, and batch
  ///   operations. Emits success/error/partial events and normalizes provider errors.
  /// </summary>
  /// <remarks>
  ///   - The driver consumes parameters from Params (TAIClaudeParams).
  ///   - Methods return a RequestId (TGUID) for later cancellation.
  ///   - Methods following the Async suffix perform work on background tasks and
  ///     surface results through events and callbacks.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIClaudeDriver = class(TAIDriver, IAIDriver)
  private
    FClaudeParams: TAIClaudeParams;
    FOnChatSuccess: TAIChatSuccessEvent;
    FOnLoadModels: TAILoadModelsEvent;
    FOnFilesSuccess: TAIFilesSuccessEvent;
    FOnUploadSuccess: TAIUploadSuccessEvent;
    FOnBatchSuccess: TAIBatchSuccessEvent;
    FOnListBatchesSuccess: TAIListBatchesSuccessEvent;
    FOnPartial: TAIPartialEvent;
    FOnPartialComplete: TAIPartialCompleteEvent;

    /// <summary>
    ///   Sends a non-streaming messages request asynchronously and routes results via events.
    /// </summary>
    /// <param name="ARequest">Message request payload.</param>
    function SendMessageAsync(const ARequest: TClaudeMessageRequest): TGUID;

    /// <summary>
    ///   Sends a streaming messages request asynchronously and routes partial/final events.
    /// </summary>
    /// <param name="ARequest">Message request payload.</param>
    function SendMessageStreamAsync(const ARequest: TClaudeMessageRequest): TGUID;

    /// <summary>
    ///   Validates model, API key, prompt, and Callback presence for chat operations.
    /// </summary>
    /// <param name="APrompt">User prompt.</param>
    /// <param name="ACallback">Callback sink for chat lifecycle.</param>
    /// <returns>True when inputs are valid; otherwise False (and error is raised).</returns>
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
    ///   Validates API key presence for general operations.
    /// </summary>
    /// <returns>True if configuration is valid, otherwise False.</returns>
    function CheckAPIKey: Boolean;

    /// <summary>
    ///   Validates base URL presence for general operations.
    /// </summary>
    /// <returns>True if configuration is valid, otherwise False.</returns>
    function CheckBaseURL: Boolean;

    /// <summary>
    ///   Extracts concatenated text from a Claude message/content JSON document.
    /// </summary>
    /// <param name="AJSON">Root JSON object to inspect.</param>
    /// <returns>Extracted text content or empty string.</returns>
    function ExtractTextFromContent(const AJSON: TJSONObject): string;
  protected
    /// <summary>
    ///   Assigns driver parameters; expects a TAIClaudeParams instance.
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
    /// <param name="AResponse">Human-readable response or error details.</param>
    function InternalTestConnection(out AResponse: string): Boolean; override;

    /// <summary>
    ///   Returns available model identifiers by the provider at the moment.
    /// </summary>
    function InternalGetAvailableModels: TArray<string>; override;

    /// <summary>
    ///   Locates primary JSON data within a root response (array/object) suitable for dataset mapping.
    /// </summary>
    /// <param name="ARoot">Root JSON response.</param>
    /// <param name="ADataArray">Discovered array of rows/items.</param>
    /// <param name="AInnerRoot">Optionally returned inner root object to be freed by caller.</param>
    /// <param name="AOwnsArray">True if caller owns ADataArray and must free it.</param>
    /// <returns>True when JSON data has been found; otherwise False.</returns>
    function FindJSONData(const ARoot: TJSONObject; out ADataArray: TJSONArray;
      out AInnerRoot: TJSONValue; out AOwnsArray: Boolean): Boolean; override;

    /// <summary>
    ///   Raises a files-success event with the given list.
    /// </summary>
    procedure DoFilesSuccess(const Files: TArray<TClaudeFileInfo>); virtual;

    /// <summary>
    ///   Raises an upload-success event for a single file.
    /// </summary>
    procedure DoUploadSuccess(const FileInfo: TClaudeFileInfo); virtual;

    /// <summary>
    ///   Raises a batch-success event with the created batch identifier.
    /// </summary>
    procedure DoBatchSuccess(const BatchID: string); virtual;

    /// <summary>
    ///   Raises a batches-listing success event with raw JSON data.
    /// </summary>
    procedure DoListBatchesSuccess(const Data: TJSONArray); virtual;

    /// <summary>
    ///   Raises a partial fragment event during streaming chat.
    /// </summary>
    procedure DoPartial(const Fragment: string); virtual;

    /// <summary>
    ///   Raises a partial-complete event with the final aggregated text.
    /// </summary>
    procedure DoPartialComplete(const FullText: string); virtual;

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
    /// <param name="Msg">Error message.</param>
    /// <param name="ExceptionClass">Exception classifier for library consumers.</param>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using HTTP response context and message.
    /// </summary>
    procedure DoError(const AReponse: IHTTPResponse; const Msg: string); overload; virtual;

    /// <summary>
    ///   Routes a chat-specific error to the callback with HTTP response context.
    /// </summary>
    procedure DoErrorChat(const ACallback: IAIChatCallback; const Msg: string; const Response: IHTTPResponse); virtual;

    /// <summary>
    ///   Routes an image-specific error to the callback.
    /// </summary>
    procedure DoErrorImage(const ACallback: IAIImageCallback; const Msg: string); virtual;

    /// <summary>
    ///   Routes a stream-specific error to the callback.
    /// </summary>
    procedure DoErrorStream(const ACallback: IAIStreamCallback; const Msg: string); virtual;

    /// <summary>
    ///   Routes a JSON-specific error to the callback using HTTP response context.
    /// </summary>
    procedure DoErrorJson(const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Starts a chat operation and returns a RequestId for potential cancellation.
    ///   The callback receives lifecycle events and the final/partial results.
    /// </summary>
    /// <param name="APrompt">User prompt to send to the provider.</param>
    /// <param name="ACallback">Chat callback sink.</param>
    /// <returns>RequestId that identifies this chat invocation.</returns>
    function Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID; override;

    /// <summary>
    ///   Convenience helper to send a simple prompt without a callback (fires driver events).
    /// </summary>
    function SimpleChat(const APrompt: string): TGUID;

    /// <summary>
    ///   Advanced chat entry point using a fully populated message request.
    /// </summary>
    function ChatEx(const ARequest: TClaudeMessageRequest): TGUID;

    /// <summary>
    ///   Retrieves model identifiers asynchronously and emits the OnLoadModels event.
    /// </summary>
    procedure ListModelsAsync;

    /// <summary>
    ///   Uploads a file asynchronously and emits the OnUploadSuccess event.
    /// </summary>
    function UploadFileAsync(const AFilePath: string): TGUID;

    /// <summary>
    ///   Retrieves file listings asynchronously and emits the OnFilesSuccess event.
    /// </summary>
    function ListFilesAsync: TGUID;

    /// <summary>
    ///   Retrieves batch listings asynchronously and emits the OnListBatchesSuccess event.
    /// </summary>
    function ListBatchesAsync: TGUID;

    /// <summary>
    ///   Creates a batch asynchronously and emits the OnBatchSuccess event upon success.
    /// </summary>
    function CreateBatchAsync(const ARequest: TClaudeBatchRequest): TGUID;

    /// <summary>
    ///   Initiates an image-generation request using the callback sink for results.
    /// </summary>
    function GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID; override;

    /// <summary>
    ///   Executes a generic JSON endpoint and returns results to the callback sink.
    /// </summary>
    function ExecuteJSONRequest(const AEndpoint: string; const AParams: string; const ACallback: IAIJSONCallback): TGUID; override;

    /// <summary>
    ///   Processes a stream-based request (e.g., file upload/transform) and returns results to the callback sink.
    /// </summary>
    function ProcessStream(const AEndpoint: string; const AInput: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID; override;
  published
    property Params;

    property OnChatSuccess: TAIChatSuccessEvent read FOnChatSuccess write FOnChatSuccess;
    property OnError: TAIErrorEvent read FOnError write FOnError;
    property OnLoadModels: TAILoadModelsEvent read FOnLoadModels write FOnLoadModels;
    property OnFilesSuccess: TAIFilesSuccessEvent read FOnFilesSuccess write FOnFilesSuccess;
    property OnUploadSuccess: TAIUploadSuccessEvent read FOnUploadSuccess write FOnUploadSuccess;
    property OnBatchSuccess: TAIBatchSuccessEvent read FOnBatchSuccess write FOnBatchSuccess;
    property OnListBatchesSuccess: TAIListBatchesSuccessEvent read FOnListBatchesSuccess write FOnListBatchesSuccess;
  end;

implementation

uses
  System.Threading, System.Generics.Collections, System.Net.Mime, System.Net.URLClient,
  System.NetConsts, SmartCoreAI.Driver.Registry,
  SmartCoreAI.Consts, SmartCoreAI.HttpClientConfig;

{ TAIClaudeParams }

function TAIClaudeParams.GetAPIKey: string;
begin
  Result := AsString(cClaude_FldName_APIKey, '');
end;

function TAIClaudeParams.GetAnthropicVersion: string;
begin
  Result := AsString(cClaude_FldName_AnthropicVersion, '');
end;

function TAIClaudeParams.GetBaseURL: string;
begin
  Result := AsPath(cClaude_FldName_BaseURL, cClaude_BaseURL);
end;

function TAIClaudeParams.GetBatchesEndPoint: string;
begin
  Result := AsPath(cClaude_FldName_BatchesEndPoint, cClaude_BatchesEndPoint);
end;

function TAIClaudeParams.GetFilesEndpoint: string;
begin
  Result := AsPath(cClaude_FldName_FilesEndpoint, cClaude_FilesEndpoint);
end;

function TAIClaudeParams.GetMaxToken: Integer;
begin
  Result := AsInteger(cClaude_FldName_MaxToken, cClaude_Def_MaxToken);
end;

function TAIClaudeParams.GetMessagesEndpoint: string;
begin
  Result := AsPath(cClaude_FldName_MessagesEndpoint, cClaude_MessagesEndpoint);
end;

function TAIClaudeParams.GetModel: string;
begin
  Result := AsString(cClaude_FldName_Model, cClaude_Def_Model);
end;

function TAIClaudeParams.GetModelsEndpoint: string;
begin
  Result := AsPath(cClaude_FldName_ModelsEndpoint, cClaude_ModelsEndpoint);
end;

function TAIClaudeParams.GetTimeout: Integer;
begin
  Result := AsInteger(cClaude_FldName_Timeout, cAIDefaultConnectionTimeout);
end;

procedure TAIClaudeParams.SetAPIKey(const AValue: string);
begin
  SetAsString(cClaude_FldName_APIKey, AValue, '');
end;

procedure TAIClaudeParams.SetAnthropicVersion(const AValue: string);
begin
  SetAsString(cClaude_FldName_AnthropicVersion, AValue, '');
end;

procedure TAIClaudeParams.SetBaseURL(const AValue: string);
begin
  SetAsPath(cClaude_FldName_BaseURL, AValue, cClaude_BaseURL);
end;

procedure TAIClaudeParams.SetBatchesEndPoint(const AValue: string);
begin
  SetAsPath(cClaude_FldName_BatchesEndPoint, AValue, cClaude_BatchesEndPoint);
end;

procedure TAIClaudeParams.SetFilesEndpoint(const AValue: string);
begin
  SetAsPath(cClaude_FldName_FilesEndpoint, AValue, cClaude_FilesEndpoint);
end;

procedure TAIClaudeParams.SetMaxToken(const AValue: Integer);
begin
  SetAsInteger(cClaude_FldName_MaxToken, AValue, cClaude_Def_MaxToken);
end;

procedure TAIClaudeParams.SetMessagesEndpoint(const AValue: string);
begin
  SetAsPath(cClaude_FldName_MessagesEndpoint, AValue, cClaude_MessagesEndpoint);
end;

procedure TAIClaudeParams.SetModel(const AValue: string);
begin
  SetAsString(cClaude_FldName_Model, AValue, cClaude_Def_Model);
end;

procedure TAIClaudeParams.SetModelsEndpoint(const AValue: string);
begin
  SetAsPath(cClaude_FldName_ModelsEndpoint, AValue, cClaude_ModelsEndpoint);
end;

procedure TAIClaudeParams.SetTimeout(const AValue: Integer);
begin
  SetAsInteger(cClaude_FldName_Timeout, AValue, cAIDefaultConnectionTimeout);
end;

{ TAIClaudeDriver }

function TAIClaudeDriver.Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckAll(APrompt, ACallback) then Exit;
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
      LReq: TClaudeMessageRequest;
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LBody, LText: string;
      LStream: TStringStream;
    begin
      InvokeEvent(procedure begin ACallback.DoBeforeRequest end);

      LReq := TClaudeMessageRequest.Create;
      try
        LReq.Model := FClaudeParams.Model;
        LReq.MaxTokens := FClaudeParams.MaxToken;
        LReq.Messages.Add(TClaudeMessage.Create('user', APrompt));
        LBody := TAIUtil.Serialize(LReq);
      finally
        LReq.Free;
      end;
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;

      if FClaudeParams.Timeout <> 0 then
        LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        InvokeEvent(procedure begin ACallback.DoBeforeResponse; end);
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, FClaudeParams.Endpoint_Messages), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LText := ExtractTextFromContent(LJSON);
          try
            InvokeEvent(procedure begin ACallback.DoResponse(LText); end);
            InvokeEvent(procedure begin ACallback.DoFullResponse(LResp.ContentAsString(TEncoding.UTF8)); end);
          except on E: Exception do
            DoErrorChat(ACallback, E.Message, nil);
          end;
        finally
          LJSON.Free;
        end;
      end
      else
        DoErrorChat(ACallback, LResp.ContentAsString(TEncoding.UTF8), LResp);
    end);
end;

function TAIClaudeDriver.ChatEx(const ARequest: TClaudeMessageRequest): TGUID;
begin
  if not CheckAll('ChatEx', nil) then Exit;

  if ARequest.Stream then
    Result := SendMessageStreamAsync(ARequest)
  else
    Result := SendMessageAsync(ARequest);
end;

function TAIClaudeDriver.CheckAPIKey: Boolean;
begin
  Result := True;
  if FClaudeParams.APIKey.IsEmpty then
  begin
    Result := False;
    DoError(cClaude_Msg_APIKeyError, EAIValidationException);
  end
end;

function TAIClaudeDriver.CheckBaseURL: Boolean;
begin
  Result := True;
  if FClaudeParams.BaseURL.IsEmpty then
  begin
    Result := False;
    DoError(cClaude_Msg_MissingBaseURLError, EAIValidationException);
  end;
end;

function TAIClaudeDriver.CheckCallBack(const ACallback: IAIChatCallback): Boolean;
var
  LCallBack: IAIChatCallback;
begin
  Result := True;
  if Assigned(ACallback) and not Supports(ACallback, IAIChatCallback, LCallBack) then
  begin
    Result := False;
    DoError(cClaude_Msg_CallBackSupportError, EAIValidationException)
  end;
end;

function TAIClaudeDriver.CheckModel: Boolean;
begin
  Result := True;
  if FClaudeParams.Model.IsEmpty then
  begin
    Result := False;
    DoError(cClaude_Msg_MissingModelsError, EAIValidationException);
  end;
end;

function TAIClaudeDriver.CheckAll(const APrompt: string; const ACallback: IAIChatCallback): Boolean;

begin
  Result := True;

  if not CheckCallBack(ACallback) then
    Result := False
  else if not CheckModel then
    Result := False
  else if not CheckAPIKey then
    Result := False
  else if not CheckBaseURL then
    Result := False
  else if not CheckPrompt(APrompt) then
    Result := False;
end;

function TAIClaudeDriver.CheckPrompt(const APrompt: string): Boolean;
begin
  Result := True;
  if APrompt.IsEmpty then
  begin
    DoError(cClaude_Msg_PromptMissingError, EAIConfigException);
    Result := False;
  end;
end;

constructor TAIClaudeDriver.Create(AOwner: TComponent);
begin
  inherited;
  FClaudeParams := TAIClaudeParams.Create;
end;

function TAIClaudeDriver.CreateBatchAsync(const ARequest: TClaudeBatchRequest): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
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
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LBody, LBatchID: string;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;
      if FClaudeParams.Timeout <> 0 then
        LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

      LBody := TAIUtil.Serialize(ARequest);
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.EndPoint_Batches]), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LBatchID := LJSON.GetValue<string>('id');
          DoBatchSuccess(LBatchID);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp, Format(cAI_Msg_CreateBatcheError, [LResp.StatusText, LResp.StatusCode]));
    end);
end;

destructor TAIClaudeDriver.Destroy;
begin
  FClaudeParams.Free;
  inherited;
end;

procedure TAIClaudeDriver.DoBatchSuccess(const BatchID: string);
begin
  if Assigned(FOnBatchSuccess) then
    InvokeEvent(procedure begin FOnBatchSuccess(Self, BatchID); end);
end;

procedure TAIClaudeDriver.DoChatSuccess(const ResponseText, FullJsonResponse: string);
begin
  if Assigned(FOnChatSuccess) then
    InvokeEvent(procedure begin FOnChatSuccess(Self, ResponseText, FullJsonResponse); end)
end;

procedure TAIClaudeDriver.DoError(const AReponse: IHTTPResponse; const Msg: string);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AReponse.StatusCode, AReponse.ContentAsString(TEncoding.UTF8), AReponse.Headers, cAIRequestFailed); end);
end;

procedure TAIClaudeDriver.DoErrorChat(const ACallback: IAIChatCallback; const Msg: string; const Response: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8), Response.Headers, cAIRequestFailed); end);
end;

procedure TAIClaudeDriver.DoErrorImage(const ACallback: IAIImageCallback; const Msg: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin  ACallback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    raise EAIException.Create(Msg);
end;

procedure TAIClaudeDriver.DoErrorStream(const ACallback: IAIStreamCallback; const Msg: string);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    raise EAIException.Create(Msg);
end;

procedure TAIClaudeDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg) end)
  else
    raise ExceptionClass.Create(Msg);
end;

procedure TAIClaudeDriver.DoFilesSuccess(const Files: TArray<TClaudeFileInfo>);
begin
  if Assigned(FOnFilesSuccess) then
    InvokeEvent(procedure begin FOnFilesSuccess(Self, Files); end);
end;

procedure TAIClaudeDriver.DoListBatchesSuccess(const Data: TJSONArray);
begin
  if Assigned(FOnListBatchesSuccess) then
    InvokeEvent(procedure begin FOnListBatchesSuccess(Self, Data); end);
end;

procedure TAIClaudeDriver.DoLoadModels(const AvailableModels: TArray<string>);
begin
  if Assigned(FOnLoadModels) then
    InvokeEvent(procedure begin FOnLoadModels(Self, AvailableModels); end);
end;

procedure TAIClaudeDriver.DoPartial(const Fragment: string);
begin
  if Assigned(FOnPartial) then
    InvokeEvent(procedure begin FOnPartial(Self, Fragment); end);
end;

procedure TAIClaudeDriver.DoPartialComplete(const FullText: string);
begin
  if Assigned(FOnPartialComplete) then
    InvokeEvent(procedure begin FOnPartialComplete(Self, FullText); end);
end;

procedure TAIClaudeDriver.DoUploadSuccess(const FileInfo: TClaudeFileInfo);
begin
  if Assigned(FOnUploadSuccess) then
    InvokeEvent(procedure begin FOnUploadSuccess(Self, FileInfo); end);
end;

function TAIClaudeDriver.ExecuteJSONRequest(
  const AEndpoint: string; const AParams: string;
  const ACallback: IAIJSONCallback): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
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
      LResp: IHTTPResponse;
      LJSONResp: TJSONObject;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;
      if FClaudeParams.Timeout <> 0 then
        LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

      LStream := TStringStream.Create(AParams, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [AEndpoint]), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
        if LState.Cancelled then
          Exit;

        try
          LJSONResp := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;
        try
          if Assigned(ACallback) then
          begin
            if LState.Cancelled then
              Exit;

            try
              InvokeEvent(
                procedure
                begin
                  if Assigned(ACallback) then
                  begin
                    if ACallback.PopulateDataset(LJSONResp) then
                      ACallback.DoSuccess(LJSONResp.ToJSON)
                    else
                      DoErrorJson(ACallback, LResp);
                  end;
                end);
            except on E: Exception do
              DoError(E.Message, EAIException);
            end;
          end;
        finally
          LJSONResp.Free;
        end;
      end
      else
        DoErrorJson(ACallback, LResp);
    end);
end;

function TAIClaudeDriver.ExtractTextFromContent(const AJSON: TJSONObject): string;
var
  LArr: TJSONArray;
  I: Integer;
  LObj: TJSONObject;
begin
  Result := '';
  LArr := AJSON.GetValue<TJSONArray>('content');
  if LArr = nil then Exit;

  for I := 0 to LArr.Count - 1 do
    if LArr.Items[I] is TJSONObject then
    begin
      LObj := TJSONObject(LArr.Items[I]);
      if SameText(LObj.GetValue<string>('type'), 'text') then
        Result := Result + LObj.GetValue<string>('text');
    end;

  Result := Result.Trim;
end;

function TAIClaudeDriver.FindJSONData(const ARoot: TJSONObject;
  out ADataArray: TJSONArray; out AInnerRoot: TJSONValue;
  out AOwnsArray: Boolean): Boolean;

function TryClaudePath(
    const R: TJSONObject;
    out Inner: TJSONValue;
    out Arr: TJSONArray;
    out OwnsArr: Boolean
  ): Boolean;
  var
    ContentArr, Parts: TJSONArray;
    MsgObj, PartObj, LInnerObj: TJSONObject;
    InputVal: TJSONValue;
    S, LType, KeyName: string;
    I: Integer;
    Pair: TJSONPair;
    MaybeArr: TJSONArray;
  begin
    Result := False; Inner := nil; Arr := nil; OwnsArr := False;

    // Newer Claude message shape: root.content[] parts with type/text or input_json
    if R.TryGetValue<TJSONArray>('content', ContentArr) then
    begin
      for I := 0 to ContentArr.Count - 1 do
      begin
        if ContentArr.Items[I] is TJSONObject then
        begin
          PartObj := TJSONObject(ContentArr.Items[I]);

          // text-style
          if (PartObj.TryGetValue<string>('type', LType) and (LType = 'text')) or
             (PartObj.TryGetValue<string>('text', S) and (S <> '')) then
          begin
            if (S = '') then PartObj.TryGetValue<string>('text', S);
            if S <> '' then
            begin
              Inner := TAIUtil.ExtractJSONValueFromText(S);
              if Assigned(Inner) then
              begin
                // try array of objects first
                Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
                if Assigned(Arr) then
                  Exit(True);

                // handle object-with-array-of-primitives
                if Inner is TJSONObject then
                begin
                  LInnerObj := TJSONObject(Inner);
                  for Pair in LInnerObj do
                  begin
                    if Pair.JsonValue is TJSONArray then
                    begin
                      MaybeArr := TJSONArray(Pair.JsonValue);
                      KeyName := Pair.JsonString.Value;

                      if TAIUtil.IsArrayOfObjects(MaybeArr) then
                      begin
                        Arr := MaybeArr;
                        Exit(True);
                      end
                      else
                      begin
                        Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, KeyName);
                        OwnsArr := True;
                        Exit(True);
                      end;
                    end;
                  end;
                end;
                // Not useful, release and continue
                Inner.Free;
                Inner := nil;
              end;
            end;
          end
          // input_json already parsed
          else if PartObj.TryGetValue<TJSONValue>('input_json', InputVal) and Assigned(InputVal) then
          begin
            // Prefer arrays-of-objects if present
            Arr := TAIUtil.FindArrayOfObjectsDeep(InputVal);
            if Assigned(Arr) then
              Exit(True);

            // If input_json is an object with array-of-primitives, wrap
            if InputVal is TJSONObject then
            begin
              LInnerObj := TJSONObject(InputVal);
              for Pair in LInnerObj do
              begin
                if Pair.JsonValue is TJSONArray then
                begin
                  MaybeArr := TJSONArray(Pair.JsonValue);
                  KeyName := Pair.JsonString.Value;

                  if TAIUtil.IsArrayOfObjects(MaybeArr) then
                  begin
                    Arr := MaybeArr;
                    Exit(True);
                  end
                  else
                  begin
                    Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, KeyName);
                    OwnsArr := True;
                    Exit(True);
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    // Older Claude shape: message.content[] parts
    if R.TryGetValue<TJSONObject>('message', MsgObj) then
      if MsgObj.TryGetValue<TJSONArray>('content', Parts) then
      begin
        for I := 0 to Parts.Count - 1 do
        begin
          if Parts.Items[I] is TJSONObject then
          begin
            PartObj := TJSONObject(Parts.Items[I]);

            if PartObj.TryGetValue<string>('text', S) and (S <> '') then
            begin
              Inner := TAIUtil.ExtractJSONValueFromText(S);
              if Assigned(Inner) then
              begin
                Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
                if Assigned(Arr) then
                  Exit(True);

                if Inner is TJSONObject then
                begin
                  LInnerObj := TJSONObject(Inner);
                  for Pair in LInnerObj do
                  begin
                    if Pair.JsonValue is TJSONArray then
                    begin
                      MaybeArr := TJSONArray(Pair.JsonValue);
                      KeyName := Pair.JsonString.Value;

                      if TAIUtil.IsArrayOfObjects(MaybeArr) then
                      begin
                        Arr := MaybeArr;
                        Exit(True);
                      end
                      else
                      begin
                        Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, KeyName);
                        OwnsArr := True;
                        Exit(True);
                      end;
                    end;
                  end;
                end;

                Inner.Free; Inner := nil;
              end;
            end
            else if PartObj.TryGetValue<TJSONValue>('input_json', InputVal) and Assigned(InputVal) then
            begin
              Arr := TAIUtil.FindArrayOfObjectsDeep(InputVal);
              if Assigned(Arr) then
                Exit(True);

              if InputVal is TJSONObject then
              begin
                LInnerObj := TJSONObject(InputVal);
                for Pair in LInnerObj do
                begin
                  if Pair.JsonValue is TJSONArray then
                  begin
                    MaybeArr := TJSONArray(Pair.JsonValue);
                    KeyName := Pair.JsonString.Value;

                    if TAIUtil.IsArrayOfObjects(MaybeArr) then
                    begin
                      Arr := MaybeArr;
                      Exit(True);
                    end
                    else
                    begin
                      Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, KeyName);
                      OwnsArr := True;
                      Exit(True);
                    end;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
  end;

begin
  ADataArray := nil;
  AInnerRoot := nil;
  AOwnsArray := False;

  if TryClaudePath(ARoot, AInnerRoot, ADataArray, AOwnsArray) then
    Exit(True);

  Result := inherited FindJSONData(ARoot, ADataArray, AInnerRoot, AOwnsArray);
end;

function TAIClaudeDriver.GenerateImage(
  ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID;
begin
  DoErrorImage(ACallback, Format(cAI_Msg_Image_NotSupport, [DriverName]));
end;

function TAIClaudeDriver.GetParams: TAIDriverParams;
begin
  Result := FClaudeParams;
end;

function TAIClaudeDriver.InternalGetAvailableModels: TArray<string>;
begin
  if not CheckModel then Exit;
  if not CheckAPIKey then Exit;
  if not CheckBaseURL then Exit;

  TTask.Run(
    procedure
    var
      LHttpClient: THTTPClient;
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LArray: TJSONArray;
      LModels: TArray<TClaudeModelInfo>;
      LList: TList<string>;
      I: Integer;
    begin
      LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
      try
        LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
        LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
        LHttpClient.ContentType := cClaude_CHeader_JsonContentType;
        if FClaudeParams.Timeout <> 0 then
          LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

        try
          LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.Endpoint_Models]));
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          try
            LArray := LJSON.GetValue<TJSONArray>('data');
            SetLength(LModels, LArray.Count);
            for I := 0 to Pred(LArray.Count) do
              LModels[I] := TAIUtil.Deserialize<TClaudeModelInfo>(LArray.Items[I] as TJSONObject);

            LList := TList<string>.Create;
            try
              for var LModel in LModels do
                LList.Add(LModel.ID);

              DoLoadModels(LList.ToArray);
            finally
              LList.Free;
            end;
          finally
            LJSON.Free;
          end;
        end
        else
          DoError(LResp, Format(cAI_Msg_ModelsError, [LResp.StatusText, LResp.StatusCode]));
      finally
        LHttpClient.Free;
      end;
    end);
end;

function TAIClaudeDriver.InternalGetDriverName: string;
begin
  Result := cClaude_DriverName;
end;

procedure TAIClaudeDriver.DoErrorJson(
  const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(AResponse.StatusText); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end);
end;

function TAIClaudeDriver.InternalTestConnection(out AResponse: string): Boolean;
var
  LModels: TArray<string>;
begin
  try
    LModels := InternalGetAvailableModels;
    Result := Length(LModels) > 0;
    if Result then
      AResponse := cClaude_Msg_TestConnectionSuccess
    else
      AResponse := cClaude_Msg_TestConnectionError;
  except
    on E: Exception do
    begin
      Result := False;
      AResponse := E.Message;
    end;
  end;
end;

function TAIClaudeDriver.ListBatchesAsync: TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
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
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LArray: TJSONArray;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, FClaudeParams.EndPoint_Batches));
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException);
          Exit;
        end;
      end;

      if LState.Cancelled then
        Exit;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LArray := LJSON.GetValue<TJSONArray>('data');
          DoListBatchesSuccess(LArray);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp, Format(cAI_Msg_BatchesError, [LResp.StatusText, LResp.StatusCode]));
    end);
end;

function TAIClaudeDriver.ListFilesAsync: TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
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
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LArray: TJSONArray;
      LFiles: TArray<TClaudeFileInfo>;
      I: Integer;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, FClaudeParams.Endpoint_Files));
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException);
          Exit;
        end;
      end;

      if LState.Cancelled then
        Exit;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LArray := LJSON.GetValue<TJSONArray>('data');
          SetLength(LFiles, LArray.Count);
          for I := 0 to LArray.Count - 1 do
            LFiles[I] := TAIUtil.Deserialize<TClaudeFileInfo>(LArray.Items[I] as TJSONObject);

          DoFilesSuccess(LFiles);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp, Format(cAI_Msg_ListFilesError, [LResp.StatusText, LResp.StatusCode]));
    end);
end;

procedure TAIClaudeDriver.ListModelsAsync;
begin
  InternalGetAvailableModels;
end;

function TAIClaudeDriver.ProcessStream(const AEndpoint: string;
  const AInput: string; const AParams: TJSONObject;
  const ACallback: IAIStreamCallback): TGUID;
begin
  DoErrorStream(ACallback, Format(cAI_Msg_Stream_NotSupport, [DriverName]));
end;

function TAIClaudeDriver.SendMessageAsync(const ARequest: TClaudeMessageRequest): TGUID;
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
      LBody: string;
      LJSON: TJSONObject;
      LText: string;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;
      if FClaudeParams.Timeout <> 0 then
        LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

      try
        try
          LBody := TAIUtil.Serialize(ARequest);
        except on E: Exception do
          raise EAIException.Create(E.Message);
        end;
      finally
        ARequest.Free;
      end;

      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.Endpoint_Messages]), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LText := LJSON.GetValue<TJSONArray>('content').Items[0].GetValue<string>('text');
          DoChatSuccess(LText, LResp.ContentAsString(TEncoding.UTF8));
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp, Format(cClaude_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
    end);
end;

function TAIClaudeDriver.SendMessageStreamAsync(const ARequest: TClaudeMessageRequest): TGUID;
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
      LReader: TStreamReader;
      LLine, LText, LPayload: string;
      LBody: string;
      LStream: TStringStream;
      LJSON: TJSONObject;
      LDelta: TJSONObject;
    begin
      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.CustomHeaders[cClaude_FldName_Accept] := cClaude_CHeader_Accept;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;

      ARequest.Stream := True;
      try
        try
          LBody := TAIUtil.Serialize(ARequest);
        except on E: Exception do
          raise EAIException.Create(E.Message);
        end;
      finally
        ARequest.Free;
      end;

      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.Endpoint_Messages]), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LReader := TStreamReader.Create(LResp.ContentStream, TEncoding.UTF8);
          try
            while not LReader.EndOfStream do
            begin
              LLine := LReader.ReadLine.Trim;
              if LLine.StartsWith('data: ') then
              begin
                LPayload := LLine.Substring(6);
                if LPayload = '[DONE]' then
                begin
                  DoPartialComplete(LText);
                  Exit;
                end;

                LJSON := TJSONObject.ParseJSONValue(LPayload, False, True) as TJSONObject;
                if Assigned(LJSON) then
                try
                  if LJSON.GetValue<string>('type') = 'content_block_delta' then
                  begin
                    LDelta := LJSON.GetValue<TJSONObject>('delta');
                    if Assigned(LDelta) and LDelta.TryGetValue<string>('text', LLine) then
                    begin
                      LText := LText + LLine;
                      DoPartial(LLine);
                    end;
                  end;
                finally
                  LJSON.Free;
                end;
              end;
            end;
          finally
            LReader.Free;
          end;
        end
        else
          DoError(LResp, Format(cAI_Msg_HttpError, [LResp.StatusText, LResp.StatusCode]));
      finally
        LStream.Free;
      end;
    end);
end;

procedure TAIClaudeDriver.SetParams(const AValue: TAIDriverParams);
begin
  FClaudeParams.SetStrings(AValue);
end;

function TAIClaudeDriver.SimpleChat(const APrompt: string): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
    if not CheckBaseURL then Exit;
    if not CheckPrompt(APrompt) then Exit;
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
      LReq: TClaudeMessageRequest;
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LBody, LText: string;
      LStream: TStringStream;
    begin
      LReq := TClaudeMessageRequest.Create;
      try
        LReq.Model := FClaudeParams.Model;
        LReq.MaxTokens := FClaudeParams.MaxToken;
        LReq.Messages.Add(TClaudeMessage.Create('user', APrompt));
        LBody := TAIUtil.Serialize(LReq);
      finally
        LReq.Free;
      end;

      LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
      LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;
      LHttpClient.ContentType := cClaude_CHeader_JsonContentType;
      if FClaudeParams.Timeout <> 0 then
        LHttpClient.ConnectionTimeout := FClaudeParams.Timeout;

      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.Endpoint_Messages]), LStream);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
        LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LText := LJSON.GetValue<TJSONArray>('content').Items[0].GetValue<string>('text');
          DoChatSuccess(LText, LResp.ContentAsString(TEncoding.UTF8));
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp, Format(cClaude_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
    end);
end;

function TAIClaudeDriver.UploadFileAsync(const AFilePath: string): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not FileExists(AFilePath) then
    begin
      DoError(cClaude_Msg_FilePathError, EAIValidationException);
      Exit;
    end;

    if not CheckModel then Exit;
    if not CheckAPIKey then Exit;
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
      LForm: TMultipartFormData;
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LInfo: TClaudeFileInfo;
    begin
      LForm := TMultipartFormData.Create;
      try
        LForm.AddFile('file', AFilePath);
        LHttpClient.CustomHeaders[cClaude_CHeader_APIKey] := FClaudeParams.APIKey;
        LHttpClient.CustomHeaders[cClaude_CHeader_AnthropicVersion] := FClaudeParams.AnthropicVersion;

        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FClaudeParams.BaseURL, [FClaudeParams.Endpoint_Files]), LForm);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          try
            LInfo := TAIUtil.Deserialize<TClaudeFileInfo>(LJSON);
            DoUploadSuccess(LInfo);
          finally
            LJSON.Free;
          end;
        end
        else
          DoError(LResp, Format(cAI_Msg_HttpError, [LResp.StatusText, LResp.StatusCode]));
      finally
        LForm.Free;
      end;
    end);
end;

procedure RegisterClaudeDriver;
begin
  TAIDriverRegistry.RegisterDriverClass(
    cClaude_DriverName,
    cClaude_API_Name,
    cClaude_Description,
    cClaude_Category,
    TAIClaudeDriver
  );
end;

initialization
 RegisterClaudeDriver;

end.
