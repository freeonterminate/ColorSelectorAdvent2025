{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Gemini;

{
  SmartCoreAI.Driver.Gemini
  -------------------------
  Google Gemini driver implementation and parameters.

  - TAIGeminiParams holds provider-specific configuration (base URL, API key,
    model, decoding/generation knobs, and endpoint overrides). Intended for design-time editing.
  - TAIGeminiDriver implements IAIDriver against Gemini endpoints, providing chat,
    model discovery, image/video/audio/document operations, and success/error events.

  Notes
  -----
  - Methods return a TGUID RequestId that can be passed to driver the cancel method.
  - Threading and event synchronization depend on the base driver settings (for example,
    whether events are marshaled to the main thread).
  - Error helpers normalize provider/HTTP errors into library-wide events.
}

interface

uses
  System.Classes, System.JSON, System.Net.HttpClient, SmartCoreAI.Exceptions,
  SmartCoreAI.Types, SmartCoreAI.Driver.Gemini.Models;

type
  /// <summary>
  ///   Event raised when image generation completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Images">Array of generated image results.</param>
  TAIGenerateImageSuccessEvent = procedure(Sender: TObject; const Images: TArray<IAIImageGenerationResult>) of object;

  /// <summary>
  ///   Event raised when video generation completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="GeneratedVideo">Generated video descriptor.</param>
  TAIGenerateVideoSuccessEvent = procedure(Sender: TObject; const GeneratedVideo: TAIGeminiGeneratedVideo) of object;

  /// <summary>
  ///   Generic success event providing a response text payload.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="ResponseText">Human-readable response text.</param>
  TAISuccessEvent = procedure(Sender: TObject; const ResponseText: string) of object;

  /// <summary>
  ///   Design-time parameters for the Gemini driver (base URL, API key, model, limits, and endpoints).
  /// </summary>
  TAIGeminiParams = class(TAIDriverParams)
  private
    function GetBaseURL: string;
    procedure SetBaseURL(const AValue: string);

    function GetAPIKey: string;
    procedure SetAPIKey(const AValue: string);

    function GetModel: string;
    procedure SetModel(const AValue: string);

    function GetMaxToken: Integer;
    procedure SetMaxToken(const AValue: Integer);

    function GetTemperature: Double;
    procedure SetTemperature(const AValue: Double);

    function GetTimeout: Integer;
    procedure SetTimeout(const AValue: Integer);

    function GetTopP: Double;
    procedure SetTopP(const AValue: Double);

    function GetTopK: Integer;
    procedure SetTopK(const AValue: Integer);

    function GetGenerateContentEndpoint: string;
    procedure SetGenerateContentEndpoint(const AValue: string);

    function GetModelsEndpoint: string;
    procedure SetModelsEndpoint(const AValue: string);

    function GetGenerateImageEndPoint: string;
    procedure SetGenerateImageEndPoint(const AValue: string);

    function GetGenerateImagePredictEndPoint: string;
    procedure SetGenerateImagePredictEndPoint(const AValue: string);

    function GetGenerateVideoEndPoint: string;
    procedure SetGenerateVideoEndPoint(const AValue: string);

    function GetUnderstandVideoEndPoint: string;
    procedure SetUnderstandVideoEndPoint(const AValue: string);

    function GetGenerateSpeechEndPoint: string;
    procedure SetGenerateSpeechEndPoint(const AValue: string);

    function GetUnderstandAudioEndPoint: string;
    procedure SetUnderstandAudioEndPoint(const AValue: string);

    function GetGenerateMusicEndPoint: string;
    procedure SetGenerateMusicEndPoint(const AValue: string);

    function GetUnderstandDocumentEndPoint: string;
    procedure SetUnderstandDocumentEndPoint(const AValue: string);

    function GetAspectRatio: string;
    procedure SetAspectRatio(const AValue: string);

    function GetPersonGeneration: string;
    procedure SetPersonGeneration(const AValue: string);

    function GetSampleCount: Integer;
    procedure SetSampleCount(const AValue: Integer);

    function GetSampleImageSize: string;
    procedure SetSampleImageSize(const AValue: string);
  published
    property BaseURL: string read GetBaseURL write SetBaseURL stored False;
    property APIKey: string read GetAPIKey write SetAPIKey stored False;
    property Model: string read GetModel write SetModel stored False;
    property MaxToken: Integer read GetMaxToken write SetMaxToken stored False;
    property Temperature: Double read GetTemperature write SetTemperature stored False;
    property Timeout: Integer read GetTimeout write SetTimeout stored False;
    property TopP: Double read GetTopP write SetTopP stored False;
    property TopK: Integer read GetTopK write SetTopK stored False;
    property SampleCount: Integer read GetSampleCount write SetSampleCount stored False;
    property AspectRatio: string read GetAspectRatio write SetAspectRatio stored False;
    property SampleImageSize: string read GetSampleImageSize write SetSampleImageSize stored False;
    property PersonGeneration: string read GetPersonGeneration write SetPersonGeneration stored False;
    property Endpoint_GenerateContent: string read GetGenerateContentEndpoint write SetGenerateContentEndpoint stored False;
    property Endpoint_Models: string read GetModelsEndpoint write SetModelsEndpoint stored False;
    property EndPoint_GenerateImage: string read GetGenerateImageEndPoint write SetGenerateImageEndPoint stored False;
    property EndPoint_GenerateImagePredict: string read GetGenerateImagePredictEndPoint write SetGenerateImagePredictEndPoint stored False;
    property EndPoint_GenerateVideo: string read GetGenerateVideoEndPoint write SetGenerateVideoEndPoint stored False;
    property EndPoint_UnderstandVideo: string read GetUnderstandVideoEndPoint write SetUnderstandVideoEndPoint stored False;
    property EndPoint_GenerateSpeech: string read GetGenerateSpeechEndPoint write SetGenerateSpeechEndPoint stored False;
    property EndPoint_UnderstandAudio: string read GetUnderstandAudioEndPoint write SetUnderstandAudioEndPoint stored False;
    property EndPoint_GenerateMusic: string read GetGenerateMusicEndPoint write SetGenerateMusicEndPoint stored False;
    property EndPoint_UnderstandDocument: string read GetUnderstandDocumentEndPoint write SetUnderstandDocumentEndPoint stored False;
  end;

  /// <summary>
  ///   Google Gemini driver. Implements chat, model discovery, image/video/audio/document
  ///   operations, and emits success/error events.
  /// </summary>
  /// <remarks>
  ///   - Consumes parameters from Params (TAIGeminiParams).
  ///   - Methods return a RequestId (TGUID) for later cancellation.
  ///   - Async methods perform work on background tasks and surface results via events/callbacks.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIGeminiDriver = class(TAIDriver, IAIDriver)
  private
    FGeminiParams: TAIGeminiParams;

    FOnLoadModels: TAILoadModelsEvent;
    FOnChatSuccess: TAIChatSuccessEvent;
    FOnGenerateImageSuccess: TAIGenerateImageSuccessEvent;
    FOnGenerateVideoSuccess: TAIGenerateVideoSuccessEvent;
    FOnUnderstandImageSuccess: TAISuccessEvent;
    FOnUnderstandVideSuccess: TAISuccessEvent;
    FOnGenerateSpeechSuccess: TAISuccessEvent;
    FOnUnderstandAudioSuccess: TAISuccessEvent;
    FOnGenerateMusicSuccess: TAISuccessEvent;
    FOnUnderstandDocumentSuccess: TAISuccessEvent;
    FOnGenerateContentWithURLContextSuccess: TAISuccessEvent;
    FOnError: TAIErrorEvent;

    /// <summary>
    ///   Builds a full URL string for the specified URL type using Params and current settings.
    /// </summary>
    function CreateURL(const AUrlType: TAIUrlType): string;

    /// <summary>
    ///   Validates model, API key, prompt, and Callback presence for chat operations.
    /// </summary>
    /// <param name="APrompt">User prompt.</param>
    /// <param name="ACallback">Optional chat callback sink.</param>
    /// <returns>True when inputs are valid; otherwise False.</returns>
    function CheckAll(const APrompt:string; const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates Callback presence for operations.
    /// </summary>
    function CheckCallBack(const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates prompt content (length, emptiness, etc.).
    /// </summary>
    function CheckPrompt(APrompt: string): Boolean;

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
    ///   Asynchronously generates content from a set of Gemini contents and routes
    ///   results to a callback sink.
    /// </summary>
    function GenerateContentAsync(const AContents: TArray<TAIGeminiContent>; const ACallback: IAIChatCallback): TGUID; overload;

    /// <summary>
    ///   Asynchronously generates content and routes results to driver events
    ///   based on the requested event type.
    /// </summary>
    function GenerateContentAsync(const AContents: TArray<TAIGeminiContent>; const EventType: TAIEventType): TGUID; overload;

    /// <summary>
    ///   Returns True if the provided model string is an Imagen-family model so parsing the response will differ accordingly.
    /// </summary>
    function IsImagenModel(const AValue: string): Boolean;

    /// <summary>
    ///   Parses Gemini image-generation results into a uniform array of image results.
    /// </summary>
    function ParseGeminiImageResults(const AObj: TJSONObject): TArray<IAIImageGenerationResult>;

    /// <summary>
    ///   Parses Imagen Predict results into a uniform array of image results.
    /// </summary>
    function ParseImagenPredictResults(const AObj: TJSONObject): TArray<IAIImageGenerationResult>;

    /// <summary>
    ///   Common error path for JSON callbacks using HTTP response context.
    /// </summary>
    procedure InternalJSONCallBackDoError(const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse);
  protected
    /// <summary>
    ///   Assigns driver parameters; expects a TAIGeminiParams instance.
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
    ///   Returns available model identifiers by the provider at the moment.
    /// </summary>
    function InternalGetAvailableModels: TArray<string>; override;

    /// <summary>
    ///   Locates primary JSON data within a root response suitable for dataset mapping.
    /// </summary>
    function FindJSONData(const ARoot: TJSONObject; out ADataArray: TJSONArray;
      out AInnerRoot: TJSONValue; out AOwnsArray: Boolean): Boolean; override;

    /// <summary>
    ///   Raises a success event for image generation and forwards the full response to callbacks.
    /// </summary>
    procedure DoGenerateImageSuccess(const ACallback: IAIImageCallback; const Images: TArray<IAIImageGenerationResult>; const FullResponse: string); virtual;

    /// <summary>
    ///   Raises a success event for video generation.
    /// </summary>
    procedure DoGenerateVideoSuccess(const GeneratedVideo: TAIGeminiGeneratedVideo); virtual;

    /// <summary>
    ///   Raises a success event for understanding image content.
    /// </summary>
    procedure DoUnderstandImageSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event for understanding video content.
    /// </summary>
    procedure DoUnderstandVideSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event for speech generation.
    /// </summary>
    procedure DoGenerateSpeechSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event for understanding audio content.
    /// </summary>
    procedure DoUnderstandAudioSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event for music generation.
    /// </summary>
    procedure DoGenerateMusicSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event for understanding document content.
    /// </summary>
    procedure DoUnderstandDocumentSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises a success event when generating content with URL context.
    /// </summary>
    procedure DoGenerateContentWithURLContextSuccess(const ResponseText: string); virtual;

    /// <summary>
    ///   Raises an event with the available model identifiers.
    /// </summary>
    procedure DoLoadModels(const AvailableModels: TArray<string>); virtual;

    /// <summary>
    ///   Raises a chat-success event including response text and full raw JSON.
    /// </summary>
    procedure DoChatSuccess(const ResponseText: string; const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Raises a normalized error using an exception class categorization.
    /// </summary>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using an exception class categorization if IAIChatCallback isn't available.
    /// </summary>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIChatCallback); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using an exception class categorization if IAIChatCallback isn't available.
    /// </summary>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIJSONCallback); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using HTTP response context and message.
    /// </summary>
    procedure DoError(const AReponse: IHTTPResponse; const Msg: string); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using HTTP response context and message if IAIChatCallback isn't available.
    /// </summary>
    procedure DoError(const AReponse: IHTTPResponse; const Msg: string; Callback: IAIChatCallback); overload; virtual;

    /// <summary>
    ///   Routes an image-specific error to the callback with HTTP response context.
    /// </summary>
    procedure DoErrorImage(const ACallback: IAIImageCallback; const Msg: string; Response: IHTTPResponse); virtual;

    /// <summary>
    ///   Routes a stream-specific error to the callback using HTTP response context.
    /// </summary>
    procedure DoErrorStream(const ACallback: IAIStreamCallback; const AResponse: IHTTPResponse); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Starts a chat operation and returns a RequestId for potential cancellation.
    ///   The callback receives lifecycle events and the final/partial results.
    /// </summary>
    function Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID; override;

    /// <summary>
    ///   Convenience helper to send a simple prompt without a callback (fires driver events).
    /// </summary>
    function SimpleChat(const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous image generation. Results are emitted via OnGenerateImageSuccess.
    /// </summary>
    function GenerateImageAsync(const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous video generation. Results are emitted via OnGenerateVideoSuccess.
    /// </summary>
    function GenerateVideoAsync(const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous image understanding with an image part and prompt.
    /// </summary>
    function UnderstandImageAsync(const AImagePart: TAIGeminiImagePart; const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous video understanding with a video source and prompt.
    /// </summary>
    function UnderstandVideoAsync(const AVideoData: TAIGeminiVideoSource; const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous speech generation.
    /// </summary>
    function GenerateSpeechAsync(const AText, AVoice, ALanguageCode: string): TGUID;

    /// <summary>
    ///   Starts asynchronous audio understanding with audio input and prompt.
    /// </summary>
    function UnderstandAudioAsync(const AAudioData: TAIGeminiAudioInput; const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous music generation.
    /// </summary>
    function GenerateMusicAsync(const APrompt, AGenre, AMood: string; ADurationSeconds: Integer): TGUID;

    /// <summary>
    ///   Starts asynchronous document understanding with a document input and prompt.
    /// </summary>
    function UnderstandDocumentAsync(const ADocument: TAIGeminiDocumentInput; const APrompt: string): TGUID;

    /// <summary>
    ///   Starts asynchronous content generation using additional URL context.
    /// </summary>
    function GenerateContentWithURLContextAsync(const AContents: TArray<TAIGeminiContent>; const AURLContext: TAIGeminiURLContext): TGUID;

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
    function ProcessStream(const AEndpoint: string; const AInputFileName: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID; override;
  published
    property Params;

    property OnError: TAIErrorEvent read FOnError write FOnError;
    property OnLoadModels: TAILoadModelsEvent read FOnloadModels write FOnLoadModels;
    property OnChatSuccess: TAIChatSuccessEvent read FOnChatSuccess write FOnChatSuccess;
    property OnGenerateImageSuccess: TAIGenerateImageSuccessEvent read FOnGenerateImageSuccess write FOnGenerateImageSuccess;
    property OnGenerateVideoSuccess: TAIGenerateVideoSuccessEvent read FOnGenerateVideoSuccess write FOnGenerateVideoSuccess;
    property OnUnderstandImageSuccess: TAISuccessEvent read FOnUnderstandImageSuccess write FOnUnderstandImageSuccess;
    property OnUnderstandVideSuccess: TAISuccessEvent read FOnUnderstandVideSuccess write FOnUnderstandVideSuccess;
    property OnGenerateSpeechSuccess: TAISuccessEvent read FOnGenerateSpeechSuccess write FOnGenerateSpeechSuccess;
    property OnUnderstandAudioSuccess: TAISuccessEvent read FOnUnderstandAudioSuccess write FOnUnderstandAudioSuccess;
    property OnGenerateMusicSuccess: TAISuccessEvent read FOnGenerateMusicSuccess write FOnGenerateMusicSuccess;
    property OnUnderstandDocumentSuccess: TAISuccessEvent read FOnUnderstandDocumentSuccess write FOnUnderstandDocumentSuccess;
    property OnGenerateContentWithURLContextSuccess: TAISuccessEvent read FOnGenerateContentWithURLContextSuccess write FOnGenerateContentWithURLContextSuccess;
  end;

implementation

uses
  System.SysUtils, System.Threading, System.Generics.Collections, System.Net.URLClient,
  System.NetConsts, System.Net.Mime, SmartCoreAI.Driver.Registry, SmartCoreAI.Consts,
  SmartCoreAI.HttpClientConfig;

{ TAIGeminiParams }

function TAIGeminiParams.GetAPIKey: string;
begin
  Result := AsString(cGemini_FldName_APIKey, '');
end;

function TAIGeminiParams.GetAspectRatio: string;
begin
  Result := AsString(cGemini_FldName_AspectRatio, cGemini_Def_AspectRatio);
end;

function TAIGeminiParams.GetBaseURL: string;
begin
  Result := AsPath(cGemini_FldName_BaseURL, cGemini_BaseURL);
end;

function TAIGeminiParams.GetGenerateContentEndpoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateContentEndpoint, cGemini_GenerateContentEndpoint);
end;

function TAIGeminiParams.GetGenerateImageEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateImageEndPoint, cGemini_GenerateImageEndPoint);
end;

function TAIGeminiParams.GetGenerateImagePredictEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateImagePredictEndPoint, cGemini_GenerateImagePredictEndPoint);
end;

function TAIGeminiParams.GetGenerateMusicEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateMusicEndPoint, cGemini_GenerateMusicEndPoint);
end;

function TAIGeminiParams.GetGenerateSpeechEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateSpeechEndPoint, cGemini_GenerateSpeechEndPoint);
end;

function TAIGeminiParams.GetGenerateVideoEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_GenerateVideoEndPoint, cGemini_GenerateVideoEndPoint);
end;

function TAIGeminiParams.GetMaxToken: Integer;
begin
  Result := AsInteger(cGemini_FldName_MaxToken, cGemini_Def_MaxToken);
end;

function TAIGeminiParams.GetModel: string;
begin
  Result := AsString(cGemini_FldName_Model, cGemini_Def_Model);
end;

function TAIGeminiParams.GetModelsEndpoint: string;
begin
  Result := AsPath(cGemini_FldName_ModelsEndpoint, cGemini_ModelsEndpoint);
end;

function TAIGeminiParams.GetPersonGeneration: string;
begin
  Result := AsString(cGemini_FldName_PersonGeneration, cGemini_Def_PersonGeneration);
end;

function TAIGeminiParams.GetSampleCount: Integer;
begin
  Result := AsInteger(cGemini_FldName_SampleCount, cGemini_Def_SampleCount);
end;

function TAIGeminiParams.GetSampleImageSize: string;
begin
  Result := AsString(cGemini_FldName_SampleImageSize, cGemini_Def_SampleImageSize);
end;

function TAIGeminiParams.GetTemperature: Double;
begin
  Result := AsFloat(cGemini_FldName_Temperature, cGemini_Def_Temperature);
end;

function TAIGeminiParams.GetTimeout: Integer;
begin
  Result := AsInteger(cGemini_FldName_Timeout, cAIDefaultConnectionTimeout);
end;

function TAIGeminiParams.GetTopK: Integer;
begin
  Result := AsInteger(cGemini_FldName_TopK, cGemini_Def_TopK);
end;

function TAIGeminiParams.GetTopP: Double;
begin
  Result := AsFloat(cGemini_FldName_TopP, cGemini_Def_TopP);
end;

function TAIGeminiParams.GetUnderstandAudioEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_UnderstandAudioEndPoint, cGemini_UnderstandAudioEndPoint);
end;

function TAIGeminiParams.GetUnderstandDocumentEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_UnderstandDocumentEndPoint, cGemini_UnderstandDocumentEndPoint);
end;

function TAIGeminiParams.GetUnderstandVideoEndPoint: string;
begin
  Result := AsPath(cGemini_FldName_UnderstandVideoEndPoint, cGemini_UnderstandVideoEndPoint);
end;

procedure TAIGeminiParams.SetAPIKey(const AValue: string);
begin
  SetAsString(cGemini_FldName_APIKey, AValue, '');
end;

procedure TAIGeminiParams.SetAspectRatio(const AValue: string);
begin
  SetAsString(cGemini_FldName_AspectRatio, AValue, cGemini_Def_AspectRatio);
end;

procedure TAIGeminiParams.SetBaseURL(const AValue: string);
begin
  SetAsPath(cGemini_FldName_BaseURL, AValue, cGemini_BaseURL);
end;

procedure TAIGeminiParams.SetGenerateContentEndpoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateContentEndpoint, AValue, cGemini_GenerateContentEndpoint);
end;

procedure TAIGeminiParams.SetGenerateImageEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateImageEndPoint, AValue, cGemini_GenerateImageEndPoint);
end;

procedure TAIGeminiParams.SetGenerateImagePredictEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateImagePredictEndPoint, AValue, cGemini_GenerateImagePredictEndPoint);
end;

procedure TAIGeminiParams.SetGenerateMusicEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateMusicEndPoint, AValue, cGemini_GenerateMusicEndPoint);
end;

procedure TAIGeminiParams.SetGenerateSpeechEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateSpeechEndPoint, AValue, cGemini_GenerateSpeechEndPoint);
end;

procedure TAIGeminiParams.SetGenerateVideoEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_GenerateVideoEndPoint, AValue, cGemini_GenerateVideoEndPoint);
end;

procedure TAIGeminiParams.SetMaxToken(const AValue: Integer);
begin
  SetAsInteger(cGemini_FldName_MaxToken, AValue, cGemini_Def_MaxToken);
end;

procedure TAIGeminiParams.SetModel(const AValue: string);
begin
  SetAsString(cGemini_FldName_Model, AValue, '');
end;

procedure TAIGeminiParams.SetModelsEndpoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_ModelsEndpoint, AValue, cGemini_ModelsEndpoint);
end;

procedure TAIGeminiParams.SetPersonGeneration(const AValue: string);
begin
  SetAsString(cGemini_FldName_PersonGeneration, AValue, cGemini_Def_PersonGeneration);
end;

procedure TAIGeminiParams.SetSampleCount(const AValue: Integer);
begin
  SetAsInteger(cGemini_FldName_SampleCount, AValue, cGemini_Def_SampleCount);
end;

procedure TAIGeminiParams.SetSampleImageSize(const AValue: string);
begin
  SetAsString(cGemini_FldName_SampleImageSize, AValue, cGemini_Def_SampleImageSize);
end;

procedure TAIGeminiParams.SetTemperature(const AValue: Double);
begin
  SetAsFloat(cGemini_FldName_Temperature, AValue, cGemini_Def_Temperature);
end;

procedure TAIGeminiParams.SetTimeout(const AValue: Integer);
begin
  SetAsInteger(cGemini_FldName_Timeout, AValue, cAIDefaultConnectionTimeout);
end;

procedure TAIGeminiParams.SetTopK(const AValue: Integer);
begin
  SetAsInteger(cGemini_FldName_TopK, AValue, cGemini_Def_TopK);
end;

procedure TAIGeminiParams.SetTopP(const AValue: Double);
begin
  SetAsFloat(cGemini_FldName_TopP, AValue, cGemini_Def_TopP);
end;

procedure TAIGeminiParams.SetUnderstandAudioEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_UnderstandAudioEndPoint, AValue, cGemini_UnderstandAudioEndPoint);
end;

procedure TAIGeminiParams.SetUnderstandDocumentEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_UnderstandDocumentEndPoint, AValue, cGemini_UnderstandDocumentEndPoint);
end;

procedure TAIGeminiParams.SetUnderstandVideoEndPoint(const AValue: string);
begin
  SetAsPath(cGemini_FldName_UnderstandVideoEndPoint, AValue, cGemini_UnderstandVideoEndPoint);
end;

{ TAIGeminiDriver }

function TAIGeminiDriver.Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID;
var
  LMessage: TAIGeminiContent;
  LPart: TAIGeminiPart;
begin
  if not CheckAll(APrompt, ACallback) then Exit;

  InvokeEvent(procedure begin ACallback.DoBeforeRequest; end);
  LMessage := TAIGeminiContent.Create;
  LPart := TAIGeminiPart.Create;
  try
    LMessage.Role := grUser;
    LPart.Text := APrompt;
    LMessage.Parts := [LPart];
    Result := GenerateContentAsync([LMessage], ACallback);
  except on E: Exception do
    DoError(E.Message, EAIException);
  end;
end;

function TAIGeminiDriver.CheckModel: Boolean;
begin
  Result := True;
  if FGeminiParams.Model.IsEmpty then
  begin
    Result := False;
    DoError(cGemini_Msg_MissingModelsError, EAIValidationException);
  end;
end;

function TAIGeminiDriver.CheckAPIKey: Boolean;
begin
  Result := True;
  if FGeminiParams.APIKey.IsEmpty then
  begin
    Result := False;
    DoError(cGemini_Msg_APIKeyError, EAIValidationException);
  end;
end;

function TAIGeminiDriver.CheckBaseURL: Boolean;
begin
  Result := True;
  if FGeminiParams.BaseURL.IsEmpty then
  begin
    Result := False;
    DoError(cGemini_Msg_MissingBaseURLError, EAIValidationException);
  end;
end;

function TAIGeminiDriver.CheckCallBack(const ACallback: IAIChatCallback): Boolean;
var
  LCallBack: IAIChatCallback;
begin
  Result := True;
  if not Assigned(ACallback) or not Supports(ACallback, IAIChatCallback, LCallBack) then
  begin
    DoError(cGemini_Msg_CallBackSupportError, EAIValidationException);
    Result := False;
  end;
end;

function TAIGeminiDriver.CheckAll(const APrompt:string; const ACallback: IAIChatCallback): Boolean;
begin
  Result := True;
  if not CheckCallBack(ACallback) then
    Result := False
  else if not CheckPrompt(APrompt) then
    Result := False
  else if not CheckModel then
    Result := False
  else if not CheckAPIKey then
    Result := False
  else if not CheckBaseURL then
    Result := False;
end;

function TAIGeminiDriver.CheckPrompt(APrompt: string): Boolean;
begin
  Result := True;
  if APrompt.Trim.IsEmpty then
  begin
    DoError(cGemini_Msg_PromptMissingError, EAIValidationException);
    Result := False;
  end;
end;

constructor TAIGeminiDriver.Create(AOwner: TComponent);
begin
  inherited;
  FGeminiParams := TAIGeminiParams.Create;
end;

function TAIGeminiDriver.CreateURL(const AUrlType: TAIUrlType): string;
var
  LEndPoint: string;
begin
  case AUrlType of
    utGenerateContentEndpoint: LEndPoint := FGeminiParams.Endpoint_GenerateContent;
    utModelsEndpoint: LEndPoint := FGeminiParams.Endpoint_Models;
    utGenerateImageEndPoint: LEndPoint := FGeminiParams.EndPoint_GenerateImage;
    utGenerateImagePredictEndPoint: LEndPoint := FGeminiParams.EndPoint_GenerateImagePredict;
    utGenerateVideoEndPoint: LEndPoint := FGeminiParams.EndPoint_GenerateVideo;
    utUnderstandVideoEndPoint: LEndPoint := FGeminiParams.EndPoint_UnderstandVideo;
    utUnderstandAudioEndPoint: LEndPoint := FGeminiParams.EndPoint_UnderstandAudio;
    utGenerateSpeechEndPoint: LEndPoint := FGeminiParams.EndPoint_GenerateSpeech;
    utGenerateMusicEndPoint: LEndPoint := FGeminiParams.EndPoint_GenerateMusic;
    utUnderstandDocumentEndPoint: LEndPoint := FGeminiParams.EndPoint_UnderstandDocument;
  end;

  Result := Format(TAIUtil.GetSafeFullURL(FGeminiParams.BaseURL, [LEndPoint]), [FGeminiParams.Model, FGeminiParams.APIKey]);
end;

destructor TAIGeminiDriver.Destroy;
begin
  FGeminiParams.Free;
  inherited;
end;

procedure TAIGeminiDriver.DoChatSuccess(const ResponseText, FullJsonResponse: string);
begin
  if Assigned(FOnChatSuccess) then
    FOnChatSuccess(Self, ResponseText, FullJsonResponse);
end;

procedure TAIGeminiDriver.DoError(const AReponse: IHTTPResponse; const Msg: string);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AReponse.StatusCode, AReponse.ContentAsString(TEncoding.UTF8), AReponse.Headers, cAIRequestFailed); end);
end;

procedure TAIGeminiDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIChatCallback);
begin
  if Assigned(Callback) then
    InvokeEvent(procedure begin Callback.DoError(Msg) end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg) end)
  else if Assigned(ExceptionClass) then
    raise ExceptionClass.Create(Msg);
end;

procedure TAIGeminiDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass; Callback: IAIJSONCallback);
begin
  if Assigned(Callback) then
    InvokeEvent(procedure begin Callback.DoError(Msg) end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg) end)
  else if Assigned(ExceptionClass) then
    raise ExceptionClass.Create(Msg);
end;

procedure TAIGeminiDriver.DoErrorImage(const ACallback: IAIImageCallback; const Msg: string; Response: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else if Assigned(Response) then
    InvokeEvent(procedure begin RaiseAIHTTPError(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8), Response.Headers, cAIRequestFailed); end)
  else
    raise EAIException.Create(Msg);
end;

procedure TAIGeminiDriver.DoErrorStream(const ACallback: IAIStreamCallback; const AResponse: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(TAIUtil.TryExtractError(AResponse)); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, TAIUtil.TryExtractError(AResponse)); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end)
end;

procedure TAIGeminiDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg) end)
  else if Assigned(ExceptionClass) then
    raise ExceptionClass.Create(Msg);
end;

procedure TAIGeminiDriver.DoGenerateImageSuccess(const ACallback: IAIImageCallback; const Images: TArray<IAIImageGenerationResult>; const FullResponse: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoSuccess(Images, FullResponse); end)
  else if Assigned(FOnGenerateImageSuccess) then
    InvokeEvent(procedure begin FOnGenerateImageSuccess(Self, Images); end);
end;

procedure TAIGeminiDriver.DoLoadModels(const AvailableModels: TArray<string>);
begin
  if Assigned(FOnLoadModels) then
    InvokeEvent(procedure begin FOnLoadModels(Self, AvailableModels); end);
end;

procedure TAIGeminiDriver.DoGenerateContentWithURLContextSuccess(const ResponseText: string);
begin
  if Assigned(FOnGenerateContentWithURLContextSuccess) then
    InvokeEvent(procedure begin FOnGenerateContentWithURLContextSuccess(Self, ResponseText); end);
end;

procedure TAIGeminiDriver.DoGenerateMusicSuccess(const ResponseText: string);
begin
  if Assigned(FOnGenerateMusicSuccess) then
    InvokeEvent(procedure begin FOnGenerateMusicSuccess(Self, ResponseText); end);
end;

procedure TAIGeminiDriver.DoGenerateSpeechSuccess(const ResponseText: string);
begin
  if Assigned(FOnGenerateSpeechSuccess) then
    InvokeEvent(procedure begin FOnGenerateSpeechSuccess(Self, ResponseText); end);
end;

procedure TAIGeminiDriver.DoGenerateVideoSuccess(const GeneratedVideo: TAIGeminiGeneratedVideo);
begin
  if Assigned(FOnGenerateVideoSuccess) then
    InvokeEvent(procedure begin FOnGenerateVideoSuccess(Self, GeneratedVideo); end)
end;

procedure TAIGeminiDriver.DoUnderstandAudioSuccess(const ResponseText: string);
begin
  if Assigned(FOnUnderstandAudioSuccess) then
    InvokeEvent(procedure begin FOnUnderstandAudioSuccess(Self, ResponseText); end);
end;

procedure TAIGeminiDriver.DoUnderstandDocumentSuccess(const ResponseText: string);
begin
  if Assigned(FOnUnderstandDocumentSuccess) then
    InvokeEvent(procedure begin FOnUnderstandDocumentSuccess(Self, ResponseText); end);
end;

procedure TAIGeminiDriver.DoUnderstandImageSuccess(const ResponseText: string);
begin
  if Assigned(FOnUnderstandImageSuccess) then
    FOnUnderstandImageSuccess(Self, ResponseText);
end;

procedure TAIGeminiDriver.DoUnderstandVideSuccess(const ResponseText: string);
begin
  if Assigned(FOnUnderstandVideSuccess) then
    InvokeEvent(procedure begin FOnUnderstandVideSuccess(Self, ResponseText); end);
end;

function TAIGeminiDriver.ExecuteJSONRequest(
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
      LJSONIn: TJSONObject;
      LRespObj: TAIGeminiGenerateContentResponse;
      LURL: string;
      LStream: TStringStream;
    begin
      try
        LURL := CreateURL(utGenerateContentEndpoint);
        LHttpClient.ContentType := cGemini_CHeader_JsonContentType;

        LStream := TStringStream.Create(AParams, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LRespObj := TAIUtil.Deserialize<TAIGeminiGenerateContentResponse>(LJSONIn);
            try
            if Assigned(ACallback) and (Length(LRespObj.Candidates) > 0) then
            begin
              var LClone := (LJSONIn.Clone as TJSONObject);
              try
                if ACallback.PopulateDataset(LClone) then
                  InvokeEvent(procedure begin ACallback.DoSuccess(LJSONIn.ToString) end)
                else
                  InternalJSONCallBackDoError(ACallback, LResp);
              finally
                if Assigned(LClone) then
                  LClone.Free;
              end;
            end;
          finally
            LRespObj.Free;
          end;
        finally
          LJSONIn.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException, ACallback);
      end;
    end
  );
end;

function TAIGeminiDriver.FindJSONData(
  const ARoot: TJSONObject;
  out ADataArray: TJSONArray;
  out AInnerRoot: TJSONValue;
  out AOwnsArray: Boolean
): Boolean;

  function TryGeminiPath(
    const R: TJSONObject; out Inner: TJSONValue; out Arr: TJSONArray; out OwnsArr: Boolean
  ): Boolean;
  var
    Candidates, Parts, ContentArr: TJSONArray;
    CandObj, PartObj, ContentObj, LInnerObj: TJSONObject;
    S, KeyName: string;
    I, J: Integer;
    Pair: TJSONPair;
    MaybeArr: TJSONArray;
  begin
    Result := False; Inner := nil; Arr := nil; OwnsArr := False;

    if R.TryGetValue<TJSONArray>('candidates', Candidates) then
    begin
      for I := 0 to Candidates.Count - 1 do
        if Candidates.Items[I] is TJSONObject then
        begin
          CandObj := TJSONObject(Candidates.Items[I]);

          // Shape 1: candidates[].content:{ parts:[ {text: "..."} ] }
          if CandObj.TryGetValue<TJSONObject>('content', ContentObj)
             and ContentObj.TryGetValue<TJSONArray>('parts', Parts) then
          begin
            for J := 0 to Parts.Count - 1 do
              if Parts.Items[J] is TJSONObject then
              begin
                PartObj := TJSONObject(Parts.Items[J]);
                if PartObj.TryGetValue<string>('text', S) and (S <> '') then
                begin
                  Inner := TAIUtil.ExtractJSONValueFromText(S);
                  if Assigned(Inner) then
                  begin
                    // NEW: top-level array support
                    if Inner is TJSONArray then
                    begin
                      MaybeArr := TJSONArray(Inner);
                      if TAIUtil.IsArrayOfObjects(MaybeArr) then
                      begin
                        Arr := MaybeArr;
                        Exit(True);
                      end
                      else
                      begin
                        Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, 'value'); // default key
                        OwnsArr := True;
                        Exit(True);
                      end;
                    end;

                    // existing: object -> property -> array
                    Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
                    if Assigned(Arr) then
                      Exit(True);

                    if Inner is TJSONObject then
                    begin
                      LInnerObj := TJSONObject(Inner);
                      for Pair in LInnerObj do
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

                    Inner.Free; Inner := nil;
                  end;
                end;
              end;
          end
          // Shape 2: candidates[].content:[ {text:"..."} , ... ]
          else if CandObj.TryGetValue<TJSONArray>('content', ContentArr) then
          begin
            for J := 0 to ContentArr.Count - 1 do
              if ContentArr.Items[J] is TJSONObject then
              begin
                PartObj := TJSONObject(ContentArr.Items[J]);
                if PartObj.TryGetValue<string>('text', S) and (S <> '') then
                begin
                  Inner := TAIUtil.ExtractJSONValueFromText(S);
                  if Assigned(Inner) then
                  begin
                    // NEW: top-level array support
                    if Inner is TJSONArray then
                    begin
                      MaybeArr := TJSONArray(Inner);
                      if TAIUtil.IsArrayOfObjects(MaybeArr) then
                      begin
                        Arr := MaybeArr;
                        Exit(True);
                      end
                      else
                      begin
                        Arr := TAIUtil.WrapPrimitiveArrayAsObjects(MaybeArr, 'value');
                        OwnsArr := True;
                        Exit(True);
                      end;
                    end;

                    Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
                    if Assigned(Arr) then
                      Exit(True);

                    if Inner is TJSONObject then
                    begin
                      LInnerObj := TJSONObject(Inner);
                      for Pair in LInnerObj do
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

                    Inner.Free; Inner := nil;
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

  if TryGeminiPath(ARoot, AInnerRoot, ADataArray, AOwnsArray) then
    Exit(True);

  // Fallback: generic (arrays of objects only)
  Result := inherited FindJSONData(ARoot, ADataArray, AInnerRoot, AOwnsArray);
end;


function TAIGeminiDriver.GenerateContentAsync(const AContents: TArray<TAIGeminiContent>; const ACallback: IAIChatCallback): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckAll('content', ACallback) then Exit;
    if Length(AContents) = 0  then
    begin
      DoError(cGemini_Msg_ContentMissingError, EAIException, ACallback);
      Exit;
    end;
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
      LJSONIn: TJSONObject;
      LJSONOut: string;
      LReq: TAIGeminiGenerateContentRequest;
      LRespObj: TAIGeminiGenerateContentResponse;
      LURL: string;
      LStream: TStringStream;
    begin
      try
        LURL := CreateURL(utGenerateContentEndpoint);
        LReq := TAIGeminiGenerateContentRequest.Create;
        try
          LReq.Contents := AContents;
          LJSONOut := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LHttpClient.ContentType := cGemini_CHeader_JsonContentType;

        if Assigned(ACallback) then
          InvokeEvent(procedure begin ACallback.DoBeforeResponse; end);

        LStream := TStringStream.Create(LJSONOut, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
          except on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException);
              Exit;
            end;
          end;
        finally
          LStream.Free;
        end;

        if Assigned(ACallback) then
          InvokeEvent(procedure begin ACallback.DoAfterResponse; end);

        if LState.Cancelled then
          Exit;

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          if Assigned(ACallback) then
          begin
            DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]), ACallback);
            Exit;
          end
          else
            InvokeEvent(procedure begin RaiseAIHTTPError(LResp.StatusCode, LResp.ContentAsString(TEncoding.UTF8), LResp.Headers, cAIRequestFailed); end);
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LRespObj := TAIUtil.Deserialize<TAIGeminiGenerateContentResponse>(LJSONIn);
          if Assigned(ACallback) and (Length(LRespObj.Candidates) > 0) then
            InvokeEvent(procedure begin ACallback.DoResponse(LRespObj.Candidates[0].Content.Parts[0].Text); end);

          LRespObj.Free;
        finally
          LJSONIn.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException, ACallback);
      end;
    end
  );
end;

function TAIGeminiDriver.GetParams: TAIDriverParams;
begin
  Result := FGeminiParams;
end;

function TAIGeminiDriver.InternalGetAvailableModels: TArray<string>;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LJSONObj: TJSONObject;
  LJSON: TJSONArray;
  LItem: TJSONValue;
  LList: TList<string>;
  LAPIKey: string;
  LURL: string;
begin
  LAPIKey := FGeminiParams.APIKey;
  if LAPIKey.IsEmpty then
    raise EAIException.Create(cGemini_Msg_APIKeyError);

  LList := TList<string>.Create;
  try
    LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
    try
      LURL := TAIUtil.GetSafeFullURL(FGeminiParams.BaseURL, [Format(cGemini_LoadModels_template, [FGeminiParams.Endpoint_Models, LAPIKey])]);
      try
        LResp := LHttpClient.Get(LURL);
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException);
          Exit;
        end;
      end;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        try
          LJSONObj := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          if Assigned(LJSONObj) then
          begin
            LJSON := LJSONObj.GetValue<TJSONArray>('models');
            if Assigned(LJSON) then
              for LItem in LJSON do
                LList.Add(LItem.GetValue<string>('name'));
          end;
        except on E: Exception do
          raise EAIJSONException.Create(E.Message);
        end;

        DoLoadModels(LList.ToArray);
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

function TAIGeminiDriver.InternalGetDriverName: string;
begin
  Result := cGemini_DriverName;
end;

procedure TAIGeminiDriver.InternalJSONCallBackDoError(
  const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse);
begin

end;

function TAIGeminiDriver.InternalTestConnection(out AResponse: string): Boolean;
var
  LModels: TArray<string>;
begin
  try
    LModels := InternalGetAvailableModels;
    Result := Length(LModels) > 0;
    if Result then
      AResponse := cGemini_Msg_TestConnectionSuccess
    else
      AResponse := cGemini_Msg_TestConnectionError;
  except
    on E: EAIException do
    begin
      Result := False;
      AResponse := E.Message;
    end;
  end;
end;

function TAIGeminiDriver.IsImagenModel(const AValue: string): Boolean;
begin
  Result := Avalue.StartsWith('imagen-', True);
end;

function TAIGeminiDriver.ParseGeminiImageResults(const AObj: TJSONObject): TArray<IAIImageGenerationResult>;
  var
    Cands, Parts: TJSONArray;
    CandObj, ContentObj, PartObj, InlineObj: TJSONObject;
    i, j: Integer;
    Mime, Data: string;
    Res: TAIGeminiImageGenerationResult;

  function TryGetObj(const Obj: TJSONObject; const Name1, Name2: string; out Child: TJSONObject): Boolean;
  begin
    Result := Obj.TryGetValue<TJSONObject>(Name1, Child)
          or Obj.TryGetValue<TJSONObject>(Name2, Child);
  end;

  function TryGetStr(const Obj: TJSONObject; const Name1, Name2: string; out S: string): Boolean;
  begin
    Result := Obj.TryGetValue<string>(Name1, S)
          or Obj.TryGetValue<string>(Name2, S);
  end;
begin
  SetLength(Result, 0);
  if not AObj.TryGetValue<TJSONArray>('candidates', Cands) then
    Exit;
  for i := 0 to Cands.Count - 1 do
  begin
    CandObj := Cands.Items[i] as TJSONObject;
    if (CandObj.TryGetValue<TJSONObject>('content', ContentObj)) and
       (ContentObj.TryGetValue<TJSONArray>('parts', Parts)) then
    begin
      for j := 0 to Parts.Count - 1 do
      begin
        PartObj := Parts.Items[j] as TJSONObject;
        if TryGetObj(PartObj, 'inlineData', 'inline_data', InlineObj) then
        begin
          if not TryGetStr(InlineObj, 'mimeType', 'mime_type', Mime) then
            Mime := '';

          if not InlineObj.TryGetValue<string>('data', Data) then
            Data := '';

          if Data <> '' then
          begin
            Res := TAIGeminiImageGenerationResult.Create;
            Res.MimeType := Mime;
            Res.Data := Data;         // base64
            Result := Result + [Res];
          end;
        end;
      end;
    end;
  end;
end;

function TAIGeminiDriver.ParseImagenPredictResults(const AObj: TJSONObject): TArray<IAIImageGenerationResult>;
var
  Arr: TJSONArray;
  IObj, ImgObj: TJSONObject;
  i: Integer;
  B64, Mime: string;
  Res: TAIGeminiImageGenerationResult;
begin
  SetLength(Result, 0);

  // Prefer explicit Imagen REST shape: predictions[].bytesBase64Encoded
  if AObj.TryGetValue<TJSONArray>('predictions', Arr) then
  begin
    for i := 0 to Arr.Count - 1 do
    begin
      IObj := Arr.Items[i] as TJSONObject;
      // Variant A: top-level base64
      if IObj.TryGetValue<string>('bytesBase64Encoded', B64) and (B64 <> '') then
      begin
        Mime := IObj.GetValue<string>('mimeType', 'image/png'); // guess if missing
        Res := TAIGeminiImageGenerationResult.Create;
        Res.MimeType := Mime;
        Res.Data := B64;
        Result := Result + [Res];
      end
      // Variant B: wrapped as image.imageBytes (SDK style)
      else if IObj.TryGetValue<TJSONObject>('image', ImgObj) then
      begin
        if ImgObj.TryGetValue<string>('imageBytes', B64) and (B64 <> '') then
        begin
          Mime := ImgObj.GetValue<string>('mimeType', 'image/png');
          Res := TAIGeminiImageGenerationResult.Create;
          Res.MimeType := Mime;
          Res.Data := B64;
          Result := Result + [Res];
        end;
      end;
    end;
    Exit;
  end;

  // Fallback: some SDKs expose "generatedImages"
  if AObj.TryGetValue<TJSONArray>('generatedImages', Arr) then
  begin
    for i := 0 to Arr.Count - 1 do
    begin
      IObj := Arr.Items[i] as TJSONObject;
      if IObj.TryGetValue<TJSONObject>('image', ImgObj) and
         ImgObj.TryGetValue<string>('imageBytes', B64) and (B64 <> '') then
      begin
        Mime := ImgObj.GetValue<string>('mimeType', 'image/png');
        Res := TAIGeminiImageGenerationResult.Create;
        Res.MimeType := Mime;
        Res.Data := B64;
        Result := Result + [Res];
      end;
    end;
  end;
end;

function TAIGeminiDriver.ProcessStream(const AEndpoint: string; const AInputFileName: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID;
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

  Run(LState, LId, LHttpClient,
    procedure
    var
      LResp: IHTTPResponse;
      LMultipart: TMultipartFormData;
      LStream: TStringStream;
      LURL: string;
      Pair: TJSONPair;
    begin
      LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
      LHttpClient.CustomHeaders['x-goog-api-key'] := FGeminiParams.APIKey;
      LHttpClient.CustomHeaders['Accept'] := 'application/json';

      LURL := TAIUtil.GetSafeFullURL(FGeminiParams.BaseURL, [AEndpoint]);

      if not AInputFileName.IsEmpty then
      begin
        LMultipart := TMultipartFormData.Create;
        try
          LMultipart.AddFile('file', AInputFileName);
          LMultipart.AddField('model', FGeminiParams.Model);

          for Pair in AParams do // params (strings/numbers/bools) as fields
            LMultipart.AddField(Pair.JsonString.Value, Pair.JsonValue.Value);

          try
            LResp := LHttpClient.Post(LURL, LMultipart);
          except
            on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException);
              Exit;
            end;
          end;
        finally
          LMultipart.Free;
        end;
      end
      else
      begin
        LStream := TStringStream.Create(AParams.ToJSON, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
          except
            on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException);
              Exit;
            end;
          end;
        finally
          LStream.Free;
        end;
      end;

      if LState.Cancelled then
        Exit;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        if Assigned(ACallback) then
          InvokeEvent(procedure begin ACallback.DoSuccess(LResp.ContentStream); end);
      end
      else
        DoErrorStream(ACallback, LResp);
    end);
end;

procedure TAIGeminiDriver.SetParams(const AValue: TAIDriverParams);
begin
  FGeminiParams.SetStrings(AValue);
end;

function TAIGeminiDriver.SimpleChat(const APrompt: string): TGUID;
var
  LMessage: TAIGeminiContent;
  LPart: TAIGeminiPart;
begin
  if not CheckPrompt(APrompt) then Exit;
  if not CheckModel then Exit;
  if not CheckAPIKey then Exit;
  if not CheckBaseURL then Exit;

  LMessage := TAIGeminiContent.Create;
  LPart := TAIGeminiPart.Create;
  try
    try
      LMessage.Role := grUser;
      LPart.Text := APrompt;
      LMessage.Parts := [LPart];
      Result := GenerateContentAsync([LMessage], etChat);
    except on E: Exception do
      DoError(E.Message, EAIException);
    end;
  finally
    LPart.Free;
    LMessage.Free;
  end;
end;

function TAIGeminiDriver.GenerateImageAsync(const APrompt: string): TGUID;
var
  LReqGemini: IAIImageGenerationRequest;
begin
  if not CheckPrompt(APrompt) then Exit;
  if not CheckModel then Exit;
  if not CheckAPIKey then Exit;
  if not CheckBaseURL then Exit;

  LReqGemini := TAIGeminiGenerateImageRequest.Create;
  LReqGemini.Prompt := APrompt;
  Result := GenerateImage(LReqGemini, nil);
end;

function TAIGeminiDriver.GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  if not Assigned(ARequest) then
  begin
    DoErrorImage(ACallback, cGemini_Msg_RequestObjMissingError, nil);
    Exit;
  end;

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
      LURL, LBody: string;
      LJSONResp: TJSONObject;
      LReq: TAIGeminiGenerateImageRequest;
      LReqPredict: TAIGeminiImagenPredictRequest;
      LImageCB: IAIImageCallback;
      LStream: TStringStream;
      LResults: TArray<IAIImageGenerationResult>;
    begin
      try
        if IsImagenModel(FGeminiParams.Model) then
        begin
          LURL := CreateURL(utGenerateImagePredictEndPoint);

          LReqPredict := TAIGeminiImagenPredictRequest.Create;
          try
            LReqPredict.SetPrompt(ARequest.Prompt);
            LReqPredict.Parameters.SampleCount := FGeminiParams.SampleCount;
            LReqPredict.Parameters.AspectRatio := FGeminiParams.AspectRatio;
            LReqPredict.Parameters.SampleImageSize := FGeminiParams.SampleImageSize;
            LReqPredict.Parameters.PersonGeneration := FGeminiParams.PersonGeneration;
            LBody := LReqPredict.BuildJSON;
          finally
            LReqPredict.Free;
          end;
        end
        else
        begin
          LURL := CreateURL(utGenerateImageEndPoint);
          LReq := TAIGeminiGenerateImageRequest.Create;
          try
            LReq.Prompt := ARequest.Prompt;
            LBody := LReq.BuildGenerateContentJSON;
          finally
            LReq.Free;
          end;
        end;

        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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
          LJSONResp := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          try
            if IsImagenModel(FGeminiParams.Model) then
              LResults := ParseImagenPredictResults(LJSONResp)
            else
              LResults := ParseGeminiImageResults(LJSONResp);

            if Supports(ACallback, IAIImageCallback, LImageCB) then
            begin
              if Length(LResults) > 0 then
              begin
                case LImageCB.GetDecodeMode of
                  idmBase64, idmAuto:
                    DoGenerateImageSuccess(ACallback, LResults, LResp.ContentAsString(TEncoding.UTF8));
                  else
                    DoErrorImage(ACallback, cGemini_Msg_Not_Supported, LResp);
                end;
              end
              else
                DoErrorImage(ACallback, cGemini_Msg_Not_Supported, LResp);
            end;
          finally
            LJSONResp.Free;
          end;
        end
        else
          DoErrorImage(ACallback, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]), LResp);
      except on E: Exception do
        DoErrorImage(ACallback, E.Message, nil);
      end;
    end);
end;

function TAIGeminiDriver.UnderstandImageAsync(const AImagePart: TAIGeminiImagePart; const APrompt: string): TGUID;
var
  LUserContent: TAIGeminiContent;
  LImagePart: TAIGeminiPart;
  LPromptPart: TAIGeminiPart;
begin
  LUserContent := TAIGeminiContent.Create;
  LImagePart := TAIGeminiPart.Create;
  LPromptPart := TAIGeminiPart.Create;

  try
    try
      LUserContent.Role := grUser;

      // Setup image part
      LImagePart.InlineData := AImagePart.InlineData;

      // Setup prompt part
      LPromptPart.Text := APrompt;

      // Combine both
      LUserContent.Parts := [LImagePart, LPromptPart];
      Result := GenerateContentAsync([LUserContent], etUnderstandimage);
    except
      on E: Exception do
      begin
        LUserContent.Free;
        LImagePart.Free;
        LPromptPart.Free;
        DoError(E.Message, EAIException);
      end;
    end;
  finally
    LUserContent.Free;
    LImagePart.Free;
    LPromptPart.Free;
  end;
end;

function TAIGeminiDriver.GenerateVideoAsync(const APrompt: string): TGUID;
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
      LReq: TAIGeminiGenerateVideoRequest;
      LResp: IHTTPResponse;
      LURL, LBody: string;
      LJSONResp: TJSONObject;
      LVideoResp: TAIGeminiGenerateVideoResponse;
      LStream: TStringStream;
    begin
      try
        LURL := CreateURL(utGenerateVideoEndPoint);
        LReq := TAIGeminiGenerateVideoRequest.Create;
        try
          LReq.Prompt := APrompt;
          LBody := TAIUtil.Serialize(LReq);
          LStream := TStringStream.Create(LBody, TEncoding.UTF8);
          try
            LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
            try
              LResp := LHttpClient.Post(LURL, lStream, nil);
            except on E: Exception do
              begin
                DoError(E.Message, EAIHTTPException);
                Exit;
              end;
            end;
          finally
            LStream.Free;
          end;
        finally
          LReq.Free;
        end;

        if LState.Cancelled then
          Exit;

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONResp := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LVideoResp := TAIUtil.Deserialize<TAIGeminiGenerateVideoResponse>(LJSONResp);
          try
            DoGenerateVideoSuccess(LVideoResp.Video);
          finally
            LVideoResp.Free;
          end;
        finally
          LJSONResp.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.UnderstandVideoAsync(const AVideoData: TAIGeminiVideoSource; const APrompt: string): TGUID;
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
    if not CheckAPIKey then Exit;
    if not CheckBaseURL then Exit;
  except
    begin
      EndRequest(LId);
      raise;
    end;
  end;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  LState := BeginRequest(LId);
  Result := LId;
  Run(LState, LId, LHttpClient,
    procedure
    var
      LReq: TAIGeminiUnderstandVideoRequest;
      LJSONIn: TJSONObject;
      LJSONOut: string;
      LResp: IHTTPResponse;
      LURL: string;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiUnderstandVideoRequest.Create;
        try
          LReq.Video := AVideoData;
          LReq.Prompt := APrompt;
          LJSONOut := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;
        LURL := CreateURL(utUnderstandVideoEndPoint);

        LStream := TStringStream.Create(LJSONOut, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          DoUnderstandVideSuccess(LJSONIn.GetValue<string>('text'));
        finally
          LJSONIn.Free;
        end;

      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.GenerateSpeechAsync(const AText, AVoice, ALanguageCode: string): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if AText.IsEmpty then
    begin
      DoError(cGemini_Msg_TextMissingError, EAIValidationException);
      Exit;
    end;

    if AVoice.IsEmpty then
    begin
      DoError(cGemini_Msg_VoiceMissingError, EAIValidationException);
      Exit;
    end;

    if ALanguageCode.IsEmpty then
    begin
      DoError(cGemini_Msg_LanguageCodeMissingError, EAIValidationException);
      Exit;
    end;

    if not CheckPrompt(AText) then Exit;
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
      LReq: TAIGeminiSpeechGenerationRequest;
      LRespJSON: TJSONObject;
      LResp: IHTTPResponse;
      LURL, LBody: string;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiSpeechGenerationRequest.Create;
        try
          LReq.Text := AText;
          LReq.Voice := AVoice;
          LReq.LanguageCode := ALanguageCode;
          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LURL := CreateURL(utGenerateSpeechEndPoint);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LRespJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          DoGenerateSpeechSuccess(LRespJSON.GetValue<string>('audioData'));
        finally
          LRespJSON.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.UnderstandAudioAsync(const AAudioData: TAIGeminiAudioInput; const APrompt: string): TGUID;
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
      LReq: TAIGeminiUnderstandAudioRequest;
      LResp: IHTTPResponse;
      LURL, LBody: string;
      LJSONIn: TJSONObject;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiUnderstandAudioRequest.Create;
        try
          LReq.Audio := AAudioData;
          LReq.Prompt := APrompt;
          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LURL := CreateURL(utUnderstandAudioEndPoint);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          DoUnderstandAudioSuccess(LJSONIn.GetValue<string>('text'));
        finally
          LJSONIn.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.GenerateMusicAsync(const APrompt, AGenre, AMood: string; ADurationSeconds: Integer): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if AGenre.IsEmpty then
    begin
      DoError(cGemini_Msg_GenreMissingError, EAIValidationException);
      Exit;
    end;

    if AMood.IsEmpty then
    begin
      DoError(cGemini_Msg_GenreMissingError, EAIValidationException);
      Exit;
    end;
    if not CheckPrompt(APrompt) then Exit;
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
      LReq: TAIGeminiGenerateMusicRequest;
      LResp: IHTTPResponse;
      LJSONIn: TJSONObject;
      LURL, LBody: string;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiGenerateMusicRequest.Create;
        try
          LReq.Prompt := APrompt;
          LReq.Genre := AGenre;
          LReq.Mood := AMood;
          LReq.DurationSeconds := ADurationSeconds;
          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LURL := CreateURL(utGenerateMusicEndPoint);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          DoGenerateMusicSuccess(LJSONIn.GetValue<string>('music').Trim);
        finally
          LJSONIn.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.UnderstandDocumentAsync(const ADocument: TAIGeminiDocumentInput; const APrompt: string): TGUID;
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
      LReq: TAIGeminiUnderstandDocumentRequest;
      LResp: IHTTPResponse;
      LJSONIn: TJSONObject;
      LURL, LBody: string;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiUnderstandDocumentRequest.Create;
        try
          LReq.Document := ADocument;
          LReq.Prompt := APrompt;
          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LURL := CreateURL(utUnderstandDocumentEndPoint);
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
          try
            LResp := LHttpClient.Post(LURL, LStream, nil);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          DoUnderstandDocumentSuccess(LJSONIn.GetValue<string>('text'));
        finally
          LJSONIn.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.GenerateContentAsync(const AContents: TArray<TAIGeminiContent>; const EventType: TAIEventType): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if Length(AContents) = 0  then
    begin
      DoError(cGemini_Msg_ContentMissingError, EAIValidationException);
      Exit;
    end;

    if not CheckAll('content', nil) then Exit;
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
      LJSONIn: TJSONObject;
      LReq: TAIGeminiGenerateContentRequest;
      LRespObj: TAIGeminiGenerateContentResponse;
      LURL, LBody, LMsg: string;
      LStream: TStringStream;
    begin
      try
        LURL := CreateURL(utGenerateContentEndpoint);
        LReq := TAIGeminiGenerateContentRequest.Create;
        try
          LReq.Contents := AContents;
          LBody := TAIUtil.Serialize(LReq);
        finally
          LReq.Free;
        end;

        LHttpClient.ContentType := cGemini_CHeader_JsonContentType;
        LStream := TStringStream.Create(LBody, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(LURL, LStream);
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

        if not TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          LMsg := Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]);
          DoError(LResp, LMsg);
          Exit;
        end;

        LJSONIn := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        try
          LRespObj := TAIUtil.Deserialize<TAIGeminiGenerateContentResponse>(LJSONIn);
          case EventType of
            etChat:
            begin
              if Length(LRespObj.Candidates) > 0 then
                DoChatSuccess(LRespObj.Candidates[0].Content.Parts[0].Text, LResp.ContentAsString(TEncoding.UTF8))
              else
                DoError(Format(cAIGemini_Msg_NoCandidate, [LResp.ContentAsString(TEncoding.UTF8)]), nil);
            end;

            etUnderstandimage:
            begin
              if Length(LRespObj.Candidates) > 0 then
                DoUnderstandImageSuccess(LRespObj.Candidates[0].Content.Parts[0].Text)
              else
                DoError(Format(cAIGemini_Msg_NoCandidate, [LResp.ContentAsString(TEncoding.UTF8)]), nil);
            end;
          end;
          LRespObj.Free;
        finally
          LJSONIn.Free;
        end;
      except
        on E: Exception do
          DoError(E.Message, EAIException);
      end;
    end
  );
end;

function TAIGeminiDriver.GenerateContentWithURLContextAsync(const AContents: TArray<TAIGeminiContent>; const AURLContext: TAIGeminiURLContext): TGUID;
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
      LReq: TAIGeminiGenerateContentRequest;
      LJSONReq, LJSONResp: TJSONObject;
      LResp: IHTTPResponse;
      LURL: string;
      LStream: TStringStream;
    begin
      try
        LReq := TAIGeminiGenerateContentRequest.Create;
        try
          LReq.Contents := AContents;
          LJSONReq := TAIUtil.SerializeToJSONObject(LReq);
        finally
          LReq.Free;
        end;

        LJSONReq.AddPair('urlContexts', TAIUtil.SerializeToJSONObject(AURLContext).GetValue<TJSONArray>('urlContexts'));
        LURL := Format(TAIUtil.GetSafeFullURL(FGeminiParams.BaseURL, [FGeminiParams.Endpoint_GenerateContent]),
          [FGeminiParams.Model, FGeminiParams.APIKey]);

        try
          LStream := TStringStream.Create(LJSONReq.ToJSON, TEncoding.UTF8);
          try
            LHttpClient.CustomHeaders['Content-Type'] := cGemini_CHeader_JsonContentType;
            try
              LResp := LHttpClient.Post(LURL, LStream, nil);
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

          if not TAIUtil.IsSuccessfulResponse(LResp) then
          begin
            DoError(LResp, Format(cGemini_Msg_OnGenerateError, [LResp.StatusCode, LResp.StatusText]));
            Exit;
          end;

          LJSONResp := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          try
            DoGenerateContentWithURLContextSuccess(LJSONResp.GetValue<string>('candidates[0].content.parts[0].text'));
          finally
            LJSONResp.Free;
          end;
        finally
          LJSONReq.Free;
        end;
      except on E: Exception do
        DoError(E.Message, EAIException);
      end;
    end
  );
end;

procedure RegisterGeminiDriver;
begin
  TAIDriverRegistry.RegisterDriverClass(
    cGemini_DriverName,
    cGemini_API_Name,
    cGemini_Description,
    cGemini_Category,
    TAIGeminiDriver
  );
end;

procedure TAIGeminiDriver.DoError(const AReponse: IHTTPResponse; const Msg: string; Callback: IAIChatCallback);
begin
  if Assigned(Callback) then
    InvokeEvent(procedure begin Callback.DoError(Msg) end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AReponse.StatusCode, AReponse.ContentAsString(TEncoding.UTF8), AReponse.Headers, cAIRequestFailed); end);
end;

initialization
  RegisterGeminiDriver;

end.
