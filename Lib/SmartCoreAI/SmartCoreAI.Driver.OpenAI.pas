{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.OpenAI;

{
  SmartCoreAI.Driver.OpenAI
  -------------------------
  OpenAI driver implementation and parameters.

  - TAIOpenAIParams holds provider-specific settings (base URL, API key, model,
    decoding/generation knobs, and endpoint overrides). Intended for design-time editing.
  - TAIOpenAIDriver implements IAIDriver against OpenAI endpoints, providing chat,
    files, audio, moderation, and fine-tuning operations. Emits success/partial/error events.

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
  SmartCoreAI.Types, SmartCoreAI.Driver.OpenAI.Models, SmartCoreAI.Consts;

type
  /// <summary>
  ///   Event raised for partial (streamed) chat fragments.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="PartialText">Incremental text fragment.</param>
  TAIChatPartialEvent = procedure(Sender: TObject; const PartialText: string) of object;

  /// <summary>
  ///   Event raised when image generation completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Images">Array of generated image results.</param>
  /// <param name="FullJsonResponse">Raw JSON payload as text.</param>
  TAIImageSuccessEvent = procedure(Sender: TObject; const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string) of object;

  /// <summary>
  ///   Event raised when text-to-speech completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="AudioData">Synthesized audio stream.</param>
  TAIAudioSuccessEvent = procedure(Sender: TObject; const AudioData: TStream) of object;

  /// <summary>
  ///   Event raised when audio transcription completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="ResultText">Transcribed text.</param>
  TAITranscriptionSuccessEvent = procedure(Sender: TObject; const ResultText: string) of object;

  /// <summary>
  ///   Event raised when audio translation completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="ResultText">Translated text.</param>
  TAITranslationSuccessEvent = procedure(Sender: TObject; const ResultText: string) of object;

  /// <summary>
  ///   Event raised when a fine-tune job is created.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="JobID">Created job identifier.</param>
  /// <param name="Full">Full structured response describing the job.</param>
  TAIFineTuneCreatedEvent = procedure(Sender: TObject; const JobID: string; const Full: TAIStartFineTuneResponse) of object;

  /// <summary>
  ///   Event raised when fine-tune jobs are listed successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Jobs">Array of job summaries.</param>
  TAIFineTuneListEvent = procedure(Sender: TObject; const Jobs: TArray<TAIFineTuneJobSummary>) of object;

  /// <summary>
  ///   Event raised when fine-tune job events are retrieved.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Events">Array of job events.</param>
  TAIFineTuneEventsEvent = procedure(Sender: TObject; const Events: TArray<TAIFineTuneEvent>) of object;

  /// <summary>
  ///   Event raised when a fine-tune job is cancelled.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="JobID">Cancelled job identifier.</param>
  /// <param name="Cancelled">True if cancellation succeeded.</param>
  TAIFineTuneCancelledEvent = procedure(Sender: TObject; const JobID: string; Cancelled: Boolean) of object;

  /// <summary>
  ///   Event raised when a file is uploaded successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="FileInfo">Uploaded file information.</param>
  TAIFileUploadedEvent = procedure(Sender: TObject; const FileInfo: TAIFileInfo) of object;

  /// <summary>
  ///   Event raised when a file is deleted.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Deleted">True if deletion succeeded.</param>
  /// <param name="FileID">Identifier of the file.</param>
  TAIFileDeletedEvent = procedure(Sender: TObject; const Deleted: Boolean; const FileID: string) of object;

  /// <summary>
  ///   Event raised when moderation completes successfully.
  /// </summary>
  /// <param name="Sender">Driver instance raising the event.</param>
  /// <param name="Result">Structured moderation result.</param>
  TAIModerationSuccessEvent = procedure(Sender: TObject; const Result: TAIModerationResult) of object;

  /// <summary>
  ///   Design-time parameters for the OpenAI driver (base URL, API key, model, limits, endpoints).
  /// </summary>
  /// <remarks>
  ///   Getters/Setters encapsulate storage and optional validation.
  ///   Published properties are intentionally omitted here as requested.
  /// </remarks>
  TAIOpenAIParams = class(TAIDriverParams)
  private
    function GetBaseURL: string;
    procedure SetBaseURL(const AValue: string);

    function GetAPIKey: string;
    procedure SetAPIKey(const AValue: string);

    function GetMaxToken: Integer;
    procedure SetMaxToken(const AValue: Integer);

    function GetTemperature: Double;
    procedure SetTemperature(const AValue: Double);

    function GetTimeout: Integer;
    procedure SetTimeout(const AValue: Integer);

    function GetModel: string;
    procedure SetModel(const AValue: string);

    function GetFrequencyPenalty: Double;
    procedure SetFrequencyPenalty(const AValue: Double);

    function GetN: Integer;
    procedure SetN(const AValue: Integer);

    function GetPresencePenalty: Double;
    procedure SetPresencePenalty(const AValue: Double);

    function GetResponseFormat: string;
    procedure SetResponseFormat(const AValue: string);

    function GetStream: Boolean;
    procedure SetStream(const AValue: Boolean);

    function GetTopP: Double;
    procedure SetTopP(const AValue: Double);

    function GetVerbosity: string;
    procedure SetVerbosity(const AValue: string);

    function GetReasoningEffort: string;
    procedure SetReasoningEffort(const AValue: string);

    function GetChatEndpoint: string;
    procedure SetChatEndpoint(const AValue: string);

    function GetFilesEndpoint: string;
    procedure SetFilesEndpoint(const AValue: string);

    function GetModelsEndpoint: string;
    procedure SetModelsEndpoint(const AValue: string);

    function GetCancelJobEndPoint: string;
    procedure SetCancelJobEndPoint(const AValue: string);

    function GetGenerateImageEndPoint: string;
    procedure SetGenerateImageEndPoint(const AValue: string);

    function GetStartFineTuningEndPoint: string;
    procedure SetStartFineTuningEndPoint(const AValue: string);

    function GetSynthesizeSpeechEndPoint: string;
    procedure SetSynthesizeSpeechEndPoint(const AValue: string);

    function GetTranscribeAudioEndPoint: string;
    procedure SetTranscribeAudioEndPoint(const AValue: string);

    function GetTranslateAudioEndPoint: string;
    procedure SetTranslateAudioEndPoint(const AValue: string);

    function GetModerateEndPoint: string;
    procedure SetModerateEndPoint(const AValue: string);

  published
    property BaseURL: string read GetBaseURL write SetBaseURL stored False;
    property APIKey: string read GetAPIKey write SetAPIKey stored False;
    property MaxToken: Integer read GetMaxToken write SetMaxToken stored False;
    property Temperature: Double read GetTemperature write SetTemperature stored False;
    property TopP: Double read GetTopP write SetTopP stored False;
    property N: Integer read GetN write SetN stored False;
    property Stream: Boolean read GetStream write SetStream stored False;
    property PresencePenalty: Double read GetPresencePenalty write SetPresencePenalty stored False;
    property FrequencyPenalty: Double read GetFrequencyPenalty write SetFrequencyPenalty stored False;
    property ResponseFormat: string read GetResponseFormat write SetResponseFormat stored False;
    property Timeout: Integer read GetTimeout write SetTimeout stored False;
    property Model: string read GetModel write SetModel stored False;
    /// <summary>
    /// GPT-5: Controls the depth of internal reasoning. The value "minimal" is new.
    /// </summary>
    property ReasoningEffort: string read GetReasoningEffort write SetReasoningEffort stored False;
    /// <summary>
    /// GPT-5: Controls how expansive text should be.
    /// </summary>
    property Verbosity: string read GetVerbosity write SetVerbosity stored False;
    property Endpoint_Chat: string read GetChatEndpoint write SetChatEndpoint stored False;
    property Endpoint_Files: string read GetFilesEndpoint write SetFilesEndpoint stored False;
    property Endpoint_Models: string read GetModelsEndpoint write SetModelsEndpoint stored False;
    property EndPoint_CancelJob: string read GetCancelJobEndPoint write SetCancelJobEndPoint stored False;
    property EndPoint_GenerateImage: string read GetGenerateImageEndPoint write SetGenerateImageEndPoint stored False;
    property EndPoint_StartFineTuning: string read GetStartFineTuningEndPoint write SetStartFineTuningEndPoint stored False;
    property EndPoint_SynthesizeSpeech: string read GetSynthesizeSpeechEndPoint write SetSynthesizeSpeechEndPoint stored False;
    property EndPoint_TranscribeAudio: string read GetTranscribeAudioEndPoint write SetTranscribeAudioEndPoint stored False;
    property EndPoint_TranslateAudio: string read GetTranslateAudioEndPoint write SetTranslateAudioEndPoint stored False;
    property EndPoint_Moderate: string read GetModerateEndPoint write SetModerateEndPoint stored False;
  end;

  /// <summary>
  ///   OpenAI driver. Implements chat, model discovery, images, audio, moderation,
  ///   and fine-tuning operations. Emits success/error/partial events and normalizes errors.
  /// </summary>
  /// <remarks>
  ///   - Consumes parameters from Params (TAIOpenAIParams).
  ///   - Methods return a RequestId (TGUID) for later cancellation.
  ///   - Async and request methods surface results via events/callbacks.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIOpenAIDriver = class(TAIDriver, IAIDriver)
  private
    FOpenAIParams: TAIOpenAIParams;
    FOnLoadModels: TAILoadModelsEvent;
    FOnChatSuccess: TAIChatSuccessEvent;
    FOnChatPartial: TAIChatPartialEvent;
    FOnImageSuccess: TAIImageSuccessEvent;
    FOnAudioSuccess: TAIAudioSuccessEvent;
    FOnTranscriptionSuccess: TAITranscriptionSuccessEvent;
    FOnTranslationSuccess: TAITranslationSuccessEvent;
    FOnFineTuneCreated: TAIFineTuneCreatedEvent;
    FOnFineTuneListed: TAIFineTuneListEvent;
    FOnFineTuneEvents: TAIFineTuneEventsEvent;
    FOnFineTuneCancelled: TAIFineTuneCancelledEvent;
    FOnFileUploaded: TAIFileUploadedEvent;
    FOnFileDeleted: TAIFileDeletedEvent;
    FOnModerationSuccess: TAIModerationSuccessEvent;

    /// <summary>
    ///   Handles a streaming chat request lifecycle and returns its RequestId.
    /// </summary>
    function HandleStreamedChat(const ARequest: TOpenAIChatRequest): TGUID;

    /// <summary>
    ///   Handles a non-streaming chat request lifecycle and returns its RequestId.
    /// </summary>
    /// <param name="ARequest"> the request object
    /// <param name="AFreeRequestObject">
    ///   When True, the request object is freed after use.
    /// </param>
    function HandleStandardChat(const ARequest: TOpenAIChatRequest; AFreeRequestObject: Boolean): TGUID;

    /// <summary>
    ///   Validates model, API key, prompt, and Calback presence for chat operations.
    /// </summary>
    function CheckAll(const APrompt:string; const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates APIKey presence for operations.
    /// </summary>
    function CheckAPIKey: Boolean;

    /// <summary>
    ///   Validates base URL presence for operations.
    /// </summary>
    function CheckBaseURL: Boolean;

    /// <summary>
    ///   Validates Callback presence for operations.
    /// </summary>
    function CheckCallBack(const ACallback: IAIChatCallback): Boolean;

    /// <summary>
    ///   Validates model presence for operations.
    /// </summary>
     function CheckModel: Boolean;

    /// <summary>
    ///   Validates prompt content (length, emptiness, etc.).
    /// </summary>
    function CheckPrompt(APrompt: string): Boolean;

    /// <summary>
    ///   Extracts the message content text from a chat JSON response.
    /// </summary>
    function ExtractChatContent(AJSON: TJSONObject): string;

    /// <summary>
    ///   Applies parameter values to a concrete chat request object.
    /// </summary>
    procedure ApplyParams(AOpenAIChatRequest: TOpenAIChatRequest; AParam: TAIOpenAIParams);
  protected
   /// <summary>
    ///   Assigns driver parameters; expects a TAIOpenAIParams instance.
    /// </summary>
    procedure SetParams(const AValue: TAIDriverParams); override;

    /// <summary>
    ///   Returns the current params object.
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
    ///   Returns available model identifiers.
    /// </summary>
    function InternalGetAvailableModels: TArray<string>; override;

    /// <summary>
    ///   Locates primary JSON data within a root response suitable for dataset mapping.
    /// </summary>
    function FindJSONData(const ARoot: TJSONObject; out ADataArray: TJSONArray; out AInnerRoot: TJSONValue; out AOwnsArray: Boolean): Boolean; override;

    /// <summary>
    ///   Raises an event with the available model identifiers.
    /// </summary>
    procedure DoLoadModels(const AvailableModels: TArray<string>); virtual;

    /// <summary>
    ///   Raises a partial fragment event during streaming chat.
    /// </summary>
    procedure DoChatPartial(const PartialText: string); virtual;

    /// <summary>
    ///   Raises a chat-success event including response text and the full raw JSON.
    /// </summary>
    procedure DoChatSuccess(const ACallback: IAIChatCallback; const ResponseText: string; const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Raises an image-success event and forwards the full JSON response.
    /// </summary>
    procedure DoImageSuccess(const ACallback: IAIImageCallback; const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Raises an audio-success event for synthesized speech.
    /// </summary>
    procedure DoAudioSuccess(const AudioData: TStream); virtual;

    /// <summary>
    ///   Raises a transcription-success event.
    /// </summary>
    procedure DoTranscriptionSuccess(const ResultText: string); virtual;

    /// <summary>
    ///   Raises a translation-success event.
    /// </summary>
    procedure DoTranslationSuccess(const ResultText: string); virtual;

    /// <summary>
    ///   Raises a fine-tune created event with job id and full response.
    /// </summary>
    procedure DoFineTuneCreated(const JobID: string; const FullResponse: TAIStartFineTuneResponse); virtual;

    /// <summary>
    ///   Raises a fine-tune list event with job summaries.
    /// </summary>
    procedure DoFineTuneList(const Jobs: TArray<TAIFineTuneJobSummary>); virtual;

    /// <summary>
    ///   Raises a fine-tune events event with a list of events.
    /// </summary>
    procedure DoFineTuneEvents(const Events: TArray<TAIFineTuneEvent>); virtual;

    /// <summary>
    ///   Raises a fine-tune cancelled event.
    /// </summary>
    procedure DoFineTuneCancelled(const JobID: string; Cancelled: Boolean); virtual;

    /// <summary>
    ///   Raises a file uploaded success event.
    /// </summary>
    procedure DoFileUploaded(const FileInfo: TAIFileInfo); virtual;

    /// <summary>
    ///   Raises a file deleted event.
    /// </summary>
    procedure DoFileDeleted(const Deleted: Boolean; const FileID: string); virtual;

    /// <summary>
    ///   Raises a moderation-success event.
    /// </summary>
    procedure DoModerationSuccess(Result: TAIModerationResult); virtual;

    /// <summary>
    ///   Raises a normalized error using an exception class categorization.
    /// </summary>
    procedure DoError(const Msg: string; ExceptionClass: EAIExceptionClass); overload; virtual;

    /// <summary>
    ///   Raises a normalized error using HTTP response context.
    /// </summary>
    procedure DoError(const AResponse: IHTTPResponse); overload; virtual;

    /// <summary>
    ///   Routes a chat-specific error to the callback using HTTP response context and message.
    /// </summary>
    procedure DoError(const ACallback: IAIChatCallback; const AResponse: IHTTPResponse; const Msg: string); overload; virtual;

    /// <summary>
    ///   Routes an image-specific error to the callback using a message.
    /// </summary>
    procedure DoErrorImage(const ACallback: IAIImageCallback; const Msg: string); overload; virtual;

    /// <summary>
    ///   Routes an image-specific error to the callback using HTTP response context.
    /// </summary>
    procedure DoErrorImage(const ACallback: IAIImageCallback; const AResponse: IHTTPResponse); overload; virtual;

    /// <summary>
    ///   Routes a JSON-specific error to the callback using HTTP response context.
    /// </summary>
    procedure DoErrorJson(const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse); virtual;

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
    ///   Advanced chat entry point using a fully populated chat request.
    /// </summary>
    function ChatEx(const ARequest: TOpenAIChatRequest): TGUID;

    /// <summary>
    ///   Convenience helper to send a simple prompt without a callback (fires driver events).
    /// </summary>
    function SimpleChat(const APrompt: string): TGUID;

    /// <summary>
    ///   Initiates text-to-speech synthesis.
    /// </summary>
    function SynthesizeSpeech(const ARequest: TAITextToSpeechRequest): TGUID;

    /// <summary>
    ///   Initiates audio transcription from a file using request parameters.
    /// </summary>
    function TranscribeAudio(const AAudioFile: string; const ARequest: TAITranscriptionRequest): TGUID;

    /// <summary>
    ///   Initiates audio translation from a file using request parameters.
    /// </summary>
    function TranslateAudio(const AAudioFile: string; const ARequest: TAITranslationRequest): TGUID;

    /// <summary>
    ///   Starts a fine-tuning job.
    /// </summary>
    function StartFineTuning(const ARequest: TAIStartFineTuneRequest): TGUID;

    /// <summary>
    ///   Lists fine-tuning jobs.
    /// </summary>
    function ListJobs: TGUID;

    /// <summary>
    ///   Cancels a fine-tune job by identifier.
    /// </summary>
    function CancelJob(const AJobID: string): TGUID;

    /// <summary>
    ///   Retrieves fine-tune job events by identifier.
    /// </summary>
    function GetEvents(const AJobID: string): TGUID;

    /// <summary>
    ///   Uploads a file for a given purpose.
    /// </summary>
    function UploadFile(const AFilePath: string; const APurpose: string = cOpenAI_CHeader_Purpose): TGUID;

    /// <summary>
    ///   Deletes a file by identifier.
    /// </summary>
    function DeleteFile(const AFileID: string): TGUID;

    /// <summary>
    ///   Runs a moderation request and emits a moderation result event.
    /// </summary>
    function Moderate(const ARequest: TAIModerationRequest): TGUID;

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
    property OnChatPartial: TAIChatPartialEvent read FOnChatPartial write FOnChatPartial;
    property OnImageSuccess: TAIImageSuccessEvent read FOnImageSuccess write FOnImageSuccess;
    property OnAudioSuccess: TAIAudioSuccessEvent read FOnAudioSuccess write FOnAudioSuccess;
    property OnFineTuneCreated: TAIFineTuneCreatedEvent read FOnFineTuneCreated write FOnFineTuneCreated;
    property OnFineTuneListed: TAIFineTuneListEvent read FOnFineTuneListed write FOnFineTuneListed;
    property OnFineTuneEvents: TAIFineTuneEventsEvent read FOnFineTuneEvents write FOnFineTuneEvents;
    property OnFineTuneCancelled: TAIFineTuneCancelledEvent read FOnFineTuneCancelled write FOnFineTuneCancelled;
    property OnFileUploaded: TAIFileUploadedEvent read FOnFileUploaded write FOnFileUploaded;
    property OnFileDeleted: TAIFileDeletedEvent read FOnFileDeleted write FOnFileDeleted;
    property OnTranscriptionSuccess: TAITranscriptionSuccessEvent read FOnTranscriptionSuccess write FOnTranscriptionSuccess;
    property OnTranslationSuccess: TAITranslationSuccessEvent read FOnTranslationSuccess write FOnTranslationSuccess;
    property OnModerationSuccess: TAIModerationSuccessEvent read FOnModerationSuccess write FOnModerationSuccess;
  end;

implementation

uses
  System.SysUtils, System.Threading, System.Generics.Collections, System.Net.Mime,
  System.Net.URLClient, System.NetConsts,
  SmartCoreAI.Driver.Registry, SmartCoreAI.HttpClientConfig;

{ TAIOpenAIParams }

function TAIOpenAIParams.GetAPIKey: string;
begin
  Result := AsString(cOpenAI_FldName_APIKey, '');
end;

function TAIOpenAIParams.GetBaseURL: string;
begin
  Result := AsPath(cOpenAI_FldName_BaseURL, cOpenAI_BaseURL);
end;

function TAIOpenAIParams.GetCancelJobEndPoint: string;
begin
  Result := AsPath(cOpenAI_FldName_CancelJobEndPoint, cOpenAI_CancelJobEndPoint);
end;

function TAIOpenAIParams.GetChatEndpoint: string;
begin
  Result := AsPath(cOpenAI_FldName_ChatEndpoint, cOpenAI_ChatEndpoint);
end;

function TAIOpenAIParams.GetFilesEndpoint: string;
begin
  Result := AsPath(cOpenAI_FldName_FilesEndpoint, cOpenAI_FilesEndpoint);
end;

function TAIOpenAIParams.GetFrequencyPenalty: Double;
begin
  Result := AsFloat(cOpenAI_FldName_FrequencyPenalty, cOpenAI_Def_FrequencyPenalty);
end;

function TAIOpenAIParams.GetGenerateImageEndPoint: string;
begin
  Result := AsPath(cOpenAI_FldName_GenerateImageEndPoint, cOpenAI_GenerateImageEndPoint);
end;

function TAIOpenAIParams.GetMaxToken: Integer;
begin
  Result := AsInteger(cOpenAI_FldName_MaxToken, cOpenAI_Def_MaxToken);
end;

function TAIOpenAIParams.GetModel: string;
begin
  Result := AsString(cOpenAI_FldName_Model, cOpenAI_Def_Model);
end;

function TAIOpenAIParams.GetModelsEndpoint: string;
begin
  Result := AsPath(cOpenAI_FldName_ModelsEndpoint, cOpenAI_ModelsEndpoint);
end;

function TAIOpenAIParams.GetModerateEndPoint: string;
begin
  Result := AsPath(cOpenAI_FldName_ModerateEndPoint, cOpenAI_ModerateEndPoint);
end;

function TAIOpenAIParams.GetN: Integer;
begin
  Result := AsInteger(cOpenAI_FldName_N, cOpenAI_Def_N);
end;

function TAIOpenAIParams.GetPresencePenalty: Double;
begin
  Result := AsFloat(cOpenAI_FldName_PresencePenalty, cOpenAI_Def_PresencePenalty);
end;

function TAIOpenAIParams.GetReasoningEffort: string;
begin
  Result := AsString(cOpenAI_FldName_ReasoningEffort, cOpenAI_Def_ReasoningEffort);
end;

function TAIOpenAIParams.GetResponseFormat: string;
begin
  Result := AsString(cOpenAI_FldName_ResponseFormat, cOpenAI_Def_ResponseFormat);
end;

function TAIOpenAIParams.GetStartFineTuningEndPoint: string;
begin
  Result := AsPath(cOpenAI_FldName_StartFineTuningEndPoint, cOpenAI_StartFineTuningEndPoint);
end;

function TAIOpenAIParams.GetStream: Boolean;
begin
  Result := AsBoolean(cOpenAI_FldName_Stream, cOpenAI_Def_Stream);
end;

function TAIOpenAIParams.GetSynthesizeSpeechEndPoint: string;
begin
  Result := AsPath(cOpenAI_FldName_SynthesizeSpeechEndPoint, cOpenAI_SynthesizeSpeechEndPoint);
end;

function TAIOpenAIParams.GetTemperature: Double;
begin
  Result := AsFloat(cOpenAI_FldName_Temperature, cOpenAI_Def_Temperature);
end;

function TAIOpenAIParams.GetTimeout: Integer;
begin
  Result := AsInteger(cOpenAI_FldName_Timeout, cAIDefaultConnectionTimeout);
end;

function TAIOpenAIParams.GetTopP: Double;
begin
  Result := AsFloat(cOpenAI_FldName_TopP, cOpenAI_Def_TopP);
end;

function TAIOpenAIParams.GetTranscribeAudioEndPoint: string;
begin
  Result := AsString(cOpenAI_FldName_TranscribeAudioEndPoint, cOpenAI_TranscribeAudioEndPoint);
end;

function TAIOpenAIParams.GetTranslateAudioEndPoint: string;
begin
  Result := AsString(cOpenAI_FldName_TranslateAudioEndPoint, cOpenAI_TranslateAudioEndPoint);
end;

function TAIOpenAIParams.GetVerbosity: string;
begin
  Result := AsString(cOpenAI_FldName_Verbosity, cOpenAI_Def_Verbosity);
end;

procedure TAIOpenAIParams.SetAPIKey(const AValue: string);
begin
  SetAsString(cOpenAI_FldName_APIKey, AValue, '');
end;

procedure TAIOpenAIParams.SetBaseURL(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_BaseURL, AValue, cOpenAI_BaseURL);
end;

procedure TAIOpenAIParams.SetCancelJobEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_CancelJobEndPoint, AValue, cOpenAI_CancelJobEndPoint)
end;

procedure TAIOpenAIParams.SetChatEndpoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_ChatEndpoint, AValue, cOpenAI_ChatEndpoint);
end;

procedure TAIOpenAIParams.SetFilesEndpoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_FilesEndpoint, AValue, cOpenAI_FilesEndpoint);
end;

procedure TAIOpenAIParams.SetFrequencyPenalty(const AValue: Double);
begin
  SetAsFloat(cOpenAI_FldName_FrequencyPenalty, AValue, cOpenAI_Def_FrequencyPenalty);
end;

procedure TAIOpenAIParams.SetGenerateImageEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_GenerateImageEndPoint, AValue, cOpenAI_GenerateImageEndPoint);
end;

procedure TAIOpenAIParams.SetMaxToken(const AValue: Integer);
begin
  SetAsInteger(cOpenAI_FldName_MaxToken, AValue, cOpenAI_Def_MaxToken);
end;

procedure TAIOpenAIParams.SetModel(const AValue: string);
begin
  SetAsString(cOpenAI_FldName_Model, AValue, '');
end;

procedure TAIOpenAIParams.SetModelsEndpoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_ModelsEndpoint, AValue, cOpenAI_ModelsEndpoint);
end;

procedure TAIOpenAIParams.SetModerateEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_ModerateEndPoint, AValue, cOpenAI_ModerateEndPoint);
end;

procedure TAIOpenAIParams.SetN(const AValue: Integer);
begin
  SetAsInteger(cOpenAI_FldName_N, AValue, cOpenAI_Def_N);
end;

procedure TAIOpenAIParams.SetPresencePenalty(const AValue: Double);
begin
  SetAsFloat(cOpenAI_FldName_PresencePenalty, AValue, cOpenAI_Def_PresencePenalty);
end;

procedure TAIOpenAIParams.SetReasoningEffort(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_ReasoningEffort, AValue, cOpenAI_Def_ReasoningEffort);
end;

procedure TAIOpenAIParams.SetResponseFormat(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_ResponseFormat, AValue, cOpenAI_Def_ResponseFormat);
end;

procedure TAIOpenAIParams.SetStartFineTuningEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_StartFineTuningEndPoint, AValue, cOpenAI_StartFineTuningEndPoint);
end;

procedure TAIOpenAIParams.SetStream(const AValue: Boolean);
begin
  SetAsBoolean(cOpenAI_FldName_Stream, AValue, cOpenAI_Def_Stream);
end;

procedure TAIOpenAIParams.SetSynthesizeSpeechEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_SynthesizeSpeechEndPoint, AValue, cOpenAI_SynthesizeSpeechEndPoint);
end;

procedure TAIOpenAIParams.SetTemperature(const AValue: Double);
begin
  SetAsFloat(cOpenAI_FldName_Temperature, AValue, cOpenAI_Def_Temperature);
end;

procedure TAIOpenAIParams.SetTimeout(const AValue: Integer);
begin
  SetAsInteger(cOpenAI_FldName_Timeout, AValue, cAIDefaultConnectionTimeout);
end;

procedure TAIOpenAIParams.SetTopP(const AValue: Double);
begin
  SetAsFloat(cOpenAI_FldName_TopP, AValue, cOpenAI_Def_TopP);
end;

procedure TAIOpenAIParams.SetTranscribeAudioEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_TranscribeAudioEndPoint, AValue, cOpenAI_TranscribeAudioEndPoint);
end;

procedure TAIOpenAIParams.SetTranslateAudioEndPoint(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_TranslateAudioEndPoint, AValue, cOpenAI_TranslateAudioEndPoint);
end;

procedure TAIOpenAIParams.SetVerbosity(const AValue: string);
begin
  SetAsPath(cOpenAI_FldName_Verbosity, AValue, cOpenAI_Def_Verbosity);
end;

{ TAIOpenAIDriver }

procedure TAIOpenAIDriver.ApplyParams(AOpenAIChatRequest: TOpenAIChatRequest; AParam: TAIOpenAIParams);
begin
  AOpenAIChatRequest.Model := AParam.Model;
  AOpenAIChatRequest.MaxTokens := AParam.MaxToken;
  AOpenAIChatRequest.Temperature := AParam.Temperature;
  AOpenAIChatRequest.TopP := AParam.TopP;
  AOpenAIChatRequest.N := AParam.N;
  AOpenAIChatRequest.Stream := AParam.Stream;
  AOpenAIChatRequest.PresencePenalty := AParam.PresencePenalty;
  AOpenAIChatRequest.FrequencyPenalty := AParam.FrequencyPenalty;
  AOpenAIChatRequest.Verbosity := AParam.Verbosity;
  AOpenAIChatRequest.ReasoningEffort := AParam.ReasoningEffort;
end;

function TAIOpenAIDriver.CancelJob(const AJobID: string): TGUID;
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
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      try
        LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [Format(FOpenAIParams.EndPoint_CancelJob, [AJobID])]), EmptyStr);
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException);
          Exit;
        end;
      end;

      if LState.Cancelled then
        Exit;

      if TAIUtil.IsSuccessfulResponse(LResp) then
        DoFineTuneCancelled(AJobID, TAIUtil.IsSuccessfulResponse(LResp))
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID;
var
  LReqObj: TOpenAIChatRequest;
  LBodyStr: string;
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if not CheckAll(APrompt, ACallback) then
      Exit;
  except
    begin
      EndRequest(LId);
      raise
    end;
  end;

  InvokeEvent(procedure begin ACallback.DoBeforeRequest; end);
  LReqObj := TOpenAIChatRequest.Create;
  try
    ApplyParams(LReqObj, FOpenAIParams);
    LReqObj.Messages.Add(TAIChatMessage.Create(TAIChatMessageRole.cmrUser, APrompt));
    LBodyStr := TAIUtil.Serialize(LReqObj);
  finally
    LReqObj.Free;
  end;

  LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
  Run(LState, LId, LHttpClient,
  procedure
  var
    LResp: IHTTPResponse;
    LBodyStream: TStringStream;
    LJsonResp: TJSONObject;
    LContent, LJsonOut, LURL: string;
  begin
    try
      LURL := TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Chat]);
      InvokeEvent(procedure begin ACallback.DoBeforeResponse; end);
      LBodyStream := TStringStream.Create(LBodyStr, TEncoding.UTF8);
      try
        try
          LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
          LHttpClient.CustomHeaders['Content-Type'] := cOpenAI_CHeader_JsonContentType;
          LHttpClient.CustomHeaders['Accept'] := cOpenAI_CHeader_JsonContentType;
          LResp := LHttpClient.Post(LURL, LBodyStream, nil);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;
      finally
        LBodyStream.Free;
      end;

      if LState.Cancelled then
        Exit;

      InvokeEvent(procedure begin ACallback.DoAfterResponse; end);

      if not TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        DoError(LResp);
        Exit;
      end;

      LJsonOut := LResp.ContentAsString(TEncoding.UTF8);
      if LJsonOut.IsEmpty then
        Exit;

      InvokeEvent(procedure begin ACallback.DoFullResponse(LJsonOut); end);

      try
        LJsonResp := TJSONObject(TJSONObject.ParseJSONValue(LJsonOut, False, True));
        LContent := ExtractChatContent(LJsonResp);
      except on E: Exception do
        raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
      end;

      try
        try
          if not LContent.IsEmpty then
            DoChatSuccess(ACallback, LContent, LJsonOut)
          else
            DoError(ACallback, LResp, cOpenAI_Msg_NoValidMessageInContentError);
        except on E: Exception do
          DoError(ACallback, nil, cOpenAI_Msg_NoValidMessageInContentError);
        end;
      finally
        LJsonResp.Free;
      end;
    except on E: Exception do
      DoError(ACallback, nil, E.Message);
    end;
  end);
end;

function TAIOpenAIDriver.SimpleChat(const APrompt: string): TGUID;
var
  LReq: TOpenAIChatRequest;
begin
  if not CheckModel then Exit;
  if not CheckAPIKey then Exit;
  if not CheckBaseURL then Exit;
  if not CheckPrompt(APrompt) then Exit;

  LReq := TOpenAIChatRequest.Create;
  ApplyParams(LReq, FOpenAIParams);
  LReq.Messages.Add(TAIChatMessage.Create(TAIChatMessageRole.cmrUser, APrompt));
  LReq.Stream := False;

  Result := HandleStandardChat(LReq, True);
end;

function TAIOpenAIDriver.ChatEx(const ARequest: TOpenAIChatRequest): TGUID;
begin
  if not Assigned(ARequest) then
  begin
    DoError(cOpenAI_Msg_RequestObjMissingError, EAIValidationException);
    Exit;
  end;

  if not CheckModel then Exit;
  if not CheckAPIKey then Exit;
  if not CheckBaseURL then Exit;

  if ARequest.Stream then
    Result := HandleStreamedChat(ARequest)
  else
    Result := HandleStandardChat(ARequest, True);
end;

function TAIOpenAIDriver.CheckModel: Boolean;
begin
  Result := True;
  if FOpenAIParams.Model.IsEmpty then
  begin
    Result := False;
    DoError(cOpenAI_Msg_MissingModelsError, EAIValidationException);
  end;
end;

function TAIOpenAIDriver.CheckAPIKey: Boolean;
begin
  Result := True;
  if FOpenAIParams.APIKey.IsEmpty then
  begin
    Result := False;
    DoError(cOpenAI_Msg_APIKeyError, EAIValidationException);
  end;
end;

function TAIOpenAIDriver.CheckBaseURL: Boolean;
begin
  Result := True;
  if FOpenAIParams.BaseURL.IsEmpty then
  begin
    Result := False;
    DoError(cOpenAI_Msg_MissingBaseURLError, EAIValidationException);
  end;
end;

function TAIOpenAIDriver.CheckCallBack(const ACallback: IAIChatCallback): Boolean;
var
  LCallback: IAIChatCallback;
begin
  Result := True;
  if not Assigned(ACallback) or (not Supports(ACallback, IAIChatCallback, LCallback)) then
  begin
    Result := False;
    DoError(cOpenAI_Msg_CallbackSupportError, EAIValidationException);
  end;
end;

function TAIOpenAIDriver.CheckAll(const APrompt: string; const ACallback: IAIChatCallback): Boolean;
begin
  Result := True;
  if not CheckModel then
    Exit(False);

  if not CheckAPIKey then
    Exit(False);

  if not CheckBaseURL then
    Exit(False);

  if not CheckPrompt(APrompt) then
    Exit(False);

  if not CheckCallBack(ACallback) then
    Exit(False);
end;

function TAIOpenAIDriver.CheckPrompt(APrompt: string): Boolean;
begin
  Result := True;
  if APrompt.Trim.IsEmpty then
  begin
    Result := False;
    DoError(cOpenAI_Msg_PromptMissingError, EAIValidationException);
  end;
end;

constructor TAIOpenAIDriver.Create(AOwner: TComponent);
begin
  inherited;
  FOpenAIParams := TAIOpenAIParams.Create;
end;

function TAIOpenAIDriver.DeleteFile(const AFileID: string): TGUID;
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
      LDeleted: Boolean;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;

      try
        LResp := LHttpClient.Delete(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Files, AFileID]));
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
        try
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          LDeleted := LJSON.GetValue<Boolean>('deleted');
          DoFileDeleted(LDeleted, AFileID);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp);
    end);
end;

destructor TAIOpenAIDriver.Destroy;
begin
  FOpenAIParams.Free;
  inherited;
end;

procedure TAIOpenAIDriver.DoAudioSuccess(const AudioData: TStream);
begin
  if Assigned(FOnAudioSuccess) then
    InvokeEvent(procedure begin FOnAudioSuccess(Self, AudioData); end);
end;

procedure TAIOpenAIDriver.DoChatPartial(const PartialText: string);
begin
  if Assigned(FOnChatPartial) then
    InvokeEvent(procedure begin FOnChatPartial(Self, PartialText); end);
end;

procedure TAIOpenAIDriver.DoChatSuccess(const ACallback: IAIChatCallback; const ResponseText, FullJsonResponse: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoResponse(ResponseText) end)
  else if Assigned(FOnChatSuccess) then
    InvokeEvent(procedure begin FOnChatSuccess(Self, ResponseText, FullJsonResponse); end)
end;

procedure TAIOpenAIDriver.DoError(const Msg: string; ExceptionClass: EAIExceptionClass);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg) end)
  else
    raise ExceptionClass.Create(Msg);
end;

procedure TAIOpenAIDriver.DoError(const AResponse: IHTTPResponse);
begin
  if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, TAIUtil.TryExtractError(AResponse)); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end);
end;

procedure TAIOpenAIDriver.DoError(const ACallback: IAIChatCallback; const AResponse: IHTTPResponse; const Msg: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end)
  else if Assigned(AResponse) then
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end)
  else
    raise EAIException.Create(Msg);
end;

procedure TAIOpenAIDriver.DoErrorImage(const ACallback: IAIImageCallback; const AResponse: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(TAIUtil.TryExtractError(AResponse)); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, TAIUtil.TryExtractError(AResponse)); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end);
end;

procedure TAIOpenAIDriver.DoErrorImage(const ACallback: IAIImageCallback; const Msg: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(Msg); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, Msg); end);
end;

procedure TAIOpenAIDriver.DoFileDeleted(const Deleted: Boolean; const FileID: string);
begin
  if Assigned(FOnFileDeleted) then
    InvokeEvent(procedure begin FOnFileDeleted(Self, Deleted, FileID); end);
end;

procedure TAIOpenAIDriver.DoFileUploaded(const FileInfo: TAIFileInfo);
begin
  if Assigned(FileInfo) and Assigned(FOnFileUploaded) then
    FOnFileUploaded(Self, FileInfo);
end;

procedure TAIOpenAIDriver.DoFineTuneCancelled(const JobID: string; Cancelled: Boolean);
begin
  if Assigned(FOnFineTuneCancelled) then
    InvokeEvent(procedure begin FOnFineTuneCancelled(Self, JobID, Cancelled); end)
end;

procedure TAIOpenAIDriver.DoFineTuneCreated(const JobID: string;
  const FullResponse: TAIStartFineTuneResponse);
begin
  if Assigned(FOnFineTuneCreated) then
    InvokeEvent(procedure begin FOnFineTuneCreated(Self, JobID, FullResponse); end);
end;

procedure TAIOpenAIDriver.DoFineTuneEvents(const Events: TArray<TAIFineTuneEvent>);
begin
  if Assigned(FOnFineTuneEvents) then
    InvokeEvent(procedure begin FOnFineTuneEvents(Self, Events); end);
end;

procedure TAIOpenAIDriver.DoFineTuneList(
  const Jobs: TArray<TAIFineTuneJobSummary>);
begin
  if Assigned(FOnFineTuneListed) then
    InvokeEvent(procedure begin FOnFineTuneListed(Self, Jobs); end);
end;

procedure TAIOpenAIDriver.DoImageSuccess(const ACallback: IAIImageCallback;
  const Images: TArray<IAIImageGenerationResult>;
  const FullJsonResponse: string);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoSuccess(Images, FullJsonResponse); end)
  else if Assigned(FOnImageSuccess) then
    InvokeEvent(procedure begin FOnImageSuccess(Self, Images, FullJsonResponse); end);
end;

procedure TAIOpenAIDriver.DoLoadModels(const AvailableModels: TArray<string>);
begin
  if Assigned(FOnLoadModels) then
    InvokeEvent(procedure begin FOnLoadModels(Self, AvailableModels); end);
end;

procedure TAIOpenAIDriver.DoModerationSuccess(Result: TAIModerationResult);
begin
  if Assigned(FOnModerationSuccess) then
    InvokeEvent(procedure begin FOnModerationSuccess(Self, Result); end)
end;

procedure TAIOpenAIDriver.DoTranscriptionSuccess(const ResultText: string);
begin
  if Assigned(FOnTranscriptionSuccess) then
    InvokeEvent(procedure begin FOnTranscriptionSuccess(Self, ResultText); end)
end;

procedure TAIOpenAIDriver.DoTranslationSuccess(const ResultText: string);
begin
  if Assigned(FOnTranslationSuccess) then
    InvokeEvent(procedure begin FOnTranslationSuccess(Self, ResultText); end);
end;

function TAIOpenAIDriver.ExecuteJSONRequest(const AEndpoint: string; const AParams: string; const ACallback: IAIJSONCallback): TGUID;
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
      LStream: TStringStream;
      LResp: IHTTPResponse;
      LJSONResp: TJSONObject;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

      LStream := TStringStream.Create(AParams, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [AEndpoint]), LStream);
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
        try
          LJSONResp := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          if Assigned(ACallback) then
          begin
            if ACallback.PopulateDataset(LJSONResp) then
              ACallback.DoSuccess(LJSONResp.ToJSON)
            else
              DoErrorJson(ACallback, LResp);
          end;
        finally
          LJSONResp.Free;
        end;
      end
      else
        DoErrorJson(ACallback, LResp);
    end);
end;

function TAIOpenAIDriver.ExtractChatContent(AJSON: TJSONObject): string;
var
  LChoices: TJSONArray;
  LMessage: TJSONObject;
begin
  Result := '';
  LChoices := AJSON.GetValue<TJSONArray>('choices');
  if (LChoices <> nil) and (LChoices.Count > 0) then
  begin
    LMessage := LChoices.Items[0].GetValue<TJSONObject>('message');
    if LMessage <> nil then
      Result := LMessage.GetValue<string>('content');
  end;
end;

function TAIOpenAIDriver.FindJSONData(const ARoot: TJSONObject;
  out ADataArray: TJSONArray; out AInnerRoot: TJSONValue;
  out AOwnsArray: Boolean): Boolean;

  function TryOpenAIResponsesPath(
    const R: TJSONObject;
    out Inner: TJSONValue;
    out Arr: TJSONArray;
    out OwnsArr: Boolean
  ): Boolean;
  var
    LOutput, LContent: TJSONArray;
    LMsg, LPart, LInnerObj: TJSONObject;
    LText: string;
    I, J: Integer;
    LPair: TJSONPair;
    LMaybeArr: TJSONArray;
  begin
    Result := False; Inner := nil; Arr := nil; OwnsArr := False;
    if not R.TryGetValue<TJSONArray>('output', LOutput) then Exit;

    for I := 0 to LOutput.Count - 1 do
    begin
      if LOutput.Items[I] is TJSONObject then
      begin
        LMsg := TJSONObject(LOutput.Items[I]);
        if LMsg.TryGetValue<TJSONArray>('content', LContent) then
        begin
          for J := 0 to LContent.Count - 1 do
          begin
            if LContent.Items[J] is TJSONObject then
            begin
              LPart := TJSONObject(LContent.Items[J]);
              if LPart.TryGetValue<string>('text', LText) and (LText <> '') then
              begin
                Inner := TAIUtil.ExtractJSONValueFromText(LText); // caller will free
                if not Assigned(Inner) then
                  Continue;

                // If it's already an array of objects, done
                Arr := TAIUtil.FindArrayOfObjectsDeep(Inner);
                if Assigned(Arr) then
                  Exit(True);

                // Otherwise, support object-with-array-of-primitives
                if Inner is TJSONObject then
                begin
                  LInnerObj := TJSONObject(Inner);
                  for LPair in LInnerObj do
                    if LPair.JsonValue is TJSONArray then
                    begin
                      LMaybeArr := TJSONArray(LPair.JsonValue);

                      if TAIUtil.IsArrayOfObjects(LMaybeArr) then
                      begin
                        Arr := LMaybeArr;
                        Exit(True);
                      end
                      else
                      begin
                        // wrap primitives as objects under the property name
                        Arr := TAIUtil.WrapPrimitiveArrayAsObjects(LMaybeArr, LPair.JsonString.Value);
                        OwnsArr := True;
                        Exit(True);
                      end;
                    end;
                end;

                // If we get here, Inner was not useful
                Inner.Free;
                Inner := nil;
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

  // 1) OpenAI Responses path style
  if TryOpenAIResponsesPath(ARoot, AInnerRoot, ADataArray, AOwnsArray) then
    Exit(True);

  // 2) fallback to base generic style
  Result := inherited FindJSONData(ARoot, ADataArray, AInnerRoot, AOwnsArray);

  AInnerRoot.Free;
end;

function TAIOpenAIDriver.GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID;
var
  LHttpClient: THTTPClient;
  LId: TGUID;
  LState: TAIRequestState;
begin
  LState := BeginRequest(LId);
  Result := LId;
  try
    if (not CheckModel) or (not CheckAPIKey) or (not CheckBaseURL) then
    begin
      ARequest := nil;
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
    LJSON: TJSONObject;
    LResultArray: TJSONArray;
    LItemObj: TJSONObject;
    LResults: TArray<IAIImageGenerationResult>;
    I: Integer;
    LImageCB: IAIImageCallback;
    LBody: string;
    LStream: TStringStream;
  begin
    try
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;
      LBody := TAIUtil.Serialize(TAIOpenAIImageGenerationRequest(ARequest));
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.EndPoint_GenerateImage]), LStream);
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
        try
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          if Supports(ACallback, IAIImageCallback, LImageCB) then
          begin
            case LImageCB.GetDecodeMode of
              idmBase64, idmAuto:
              begin
                LResultArray := LJSON.GetValue<TJSONArray>('data');
                SetLength(LResults, LResultArray.Count);

                for I := 0 to Pred(LResultArray.Count) do
                begin
                  LItemObj := LResultArray.Items[I] as TJSONObject;
                  LResults[I] := TAIUtil.Deserialize<TAIImageGenerationResult>(LItemObj) as IAIImageGenerationResult;
                end;

                DoImageSuccess(ACallback, LResults, LResp.ContentAsString(TEncoding.UTF8));
              end;
            else
              DoErrorImage(ACallback, cOpenAI_Msg_Not_Supported);
            end;
          end;
        finally
          LJSON.Free;
        end;
      end
      else
        DoErrorImage(ACallback, LResp);
    finally
      ARequest := nil;
    end;
  end);
end;

function TAIOpenAIDriver.GetEvents(const AJobID: string): TGUID;
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
      LArr: TJSONArray;
      LEvents: TArray<TAIFineTuneEvent>;
      I: Integer;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.EndPoint_StartFineTuning, AJobID, '/events']));
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
        try
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          LArr := LJSON.GetValue<TJSONArray>('data');
          SetLength(LEvents, LArr.Count);

          for I := 0 to Pred(LArr.Count) do
            LEvents[I] := TAIUtil.Deserialize<TAIFineTuneEvent>(LArr.Items[I] as TJSONObject);

          DoFineTuneEvents(LEvents);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.GetParams: TAIDriverParams;
begin
  Result := FOpenAIParams;
end;

function TAIOpenAIDriver.HandleStandardChat(const ARequest: TOpenAIChatRequest; AFreeRequestObject: Boolean): TGUID;
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
      LJSON: TJSONObject;
      LContent: string;
      Lbody, LJsonOut: string;
      LStream: TStringStream;
    begin
      try
        LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
        LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

        Lbody := TAIUtil.Serialize(ARequest);
        LStream := TStringStream.Create(Lbody, TEncoding.UTF8);
        try
          try
            LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Chat]), LStream);
          except on E: Exception do
            begin
              DoError(E.Message, EAIHTTPException);
              Exit;
            end;
          end;
        finally
          LStream.Free;
        end;

        LJsonOut := LResp.ContentAsString(TEncoding.UTF8);
        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
        begin
          try
            LJSON := TJSONObject.ParseJSONValue(LJsonOut, False, True) as TJSONObject;
          except on E: Exception do
            raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
          end;

          try
            try
              LContent := ExtractChatContent(LJSON);
            except on E: Exception do
              raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
            end;
            DoChatSuccess(nil, LContent, LResp.ContentAsString(TEncoding.UTF8));
          finally
            LJSON.Free;
          end;
        end
        else
          DoError(LResp);
      finally
        if AFreeRequestObject then
          ARequest.Free;
      end;
    end);
end;

function TAIOpenAIDriver.HandleStreamedChat(const ARequest: TOpenAIChatRequest): TGUID;
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
      LLine, LPayload, LContent: string;
      LStream: TStreamReader;
      LPart: TJSONObject;
      LStreamStr: TStringStream;
      Lbody: string;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.CustomHeaders['Accept'] := cOpenAI_CHeader_Accept;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

      Lbody := TAIUtil.Serialize(ARequest);
      LStreamStr := TStringStream.Create(Lbody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Chat]), LStreamStr);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
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
            LLine := LStream.ReadLine;
            if LLine.StartsWith('data: ') then
            begin
              LPayload := LLine.Substring(6).Trim;
              if LPayload <> '[DONE]' then
              begin
                LPart := nil;
                try
                  try
                    LPart := TJSONObject.ParseJSONValue(LPayload, False, True) as TJSONObject;
                    LContent := LPart.GetValue<TJSONArray>('choices').Items[0].GetValue<TJSONObject>('delta').GetValue<string>('content');
                  except on E: Exception do
                    raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
                  end;

                  DoChatPartial(LContent);
                finally
                  if Assigned(LPart) then
                    LPart.Free;
                end;
              end;
            end;
          end;

          DoChatSuccess(nil, cAIStreamEnded, LResp.ContentAsString(TEncoding.UTF8));
        finally
          LStream.Free;
        end;
      end
      else
        DoError(LResp);
    end);
end;

procedure TAIOpenAIDriver.SetParams(const AValue: TAIDriverParams);
begin
  FOpenAIParams.SetStrings(AValue);
end;

function TAIOpenAIDriver.StartFineTuning(const ARequest: TAIStartFineTuneRequest): TGUID;
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
      LBody: string;
      LJsonObj: TJSONObject;
      LParsed: TAIStartFineTuneResponse;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

      LBody := TAIUtil.Serialize(ARequest);
      LStream := TStringStream.Create(LBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.EndPoint_StartFineTuning]), LStream);
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
        try
          LJsonObj := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
          LParsed := TAIUtil.Deserialize<TAIStartFineTuneResponse>(LJsonObj);
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        DoFineTuneCreated(LParsed.ID, LParsed);
      end
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.SynthesizeSpeech(const ARequest: TAITextToSpeechRequest): TGUID;
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
      LJSONBody: string;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

      LJSONBody := TAIUtil.Serialize(ARequest);
      LStream := TStringStream.Create(LJSONBody, TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, FOpenAIParams.EndPoint_SynthesizeSpeech), LStream);
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
        DoAudioSuccess(LResp.ContentStream)
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.TranscribeAudio(const AAudioFile: string; const ARequest: TAITranscriptionRequest): TGUID;
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
      LMultipart: TMultipartFormData;
      LResp: IHTTPResponse;
    begin
      LMultipart := TMultipartFormData.Create;
      try
        LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;

        LMultipart.AddFile('file', AAudioFile);
        LMultipart.AddField('model', ARequest.Model);
        if ARequest.Prompt <> '' then
          LMultipart.AddField('prompt', ARequest.Prompt);
        if ARequest.Language <> '' then
          LMultipart.AddField('language', ARequest.Language);
        LMultipart.AddField('response_format', ARequest.ResponseFormat);
        LMultipart.AddField('temperature', FloatToStr(ARequest.Temperature, TFormatSettings.Invariant));

        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, FOpenAIParams.EndPoint_TranscribeAudio), LMultipart);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
          DoTranscriptionSuccess(LResp.ContentAsString(TEncoding.UTF8))
        else
          DoError(LResp);
      finally
        LMultipart.Free;
      end;
    end);
end;

function TAIOpenAIDriver.TranslateAudio(const AAudioFile: string; const ARequest: TAITranslationRequest): TGUID;
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
      LMultipart: TMultipartFormData;
      LResp: IHTTPResponse;
    begin
      LMultipart := TMultipartFormData.Create;
      try
        LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;

        LMultipart.AddFile('file', AAudioFile);
        LMultipart.AddField('model', ARequest.Model);
        if ARequest.Prompt <> '' then
          LMultipart.AddField('prompt', ARequest.Prompt);
        LMultipart.AddField('response_format', ARequest.ResponseFormat);
        LMultipart.AddField('temperature', FloatToStr(ARequest.Temperature, TFormatSettings.Invariant));

        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, FOpenAIParams.EndPoint_TranslateAudio), LMultipart);
        except on E: Exception do
          begin
            DoError(E.Message, EAIHTTPException);
            Exit;
          end;
        end;

        if LState.Cancelled then
          Exit;

        if TAIUtil.IsSuccessfulResponse(LResp) then
          DoTranslationSuccess(LResp.ContentAsString(TEncoding.UTF8))
        else
          DoError(LResp);
      finally
        LMultipart.Free;
      end;
    end);
end;

function TAIOpenAIDriver.UploadFile(const AFilePath, APurpose: string): TGUID;
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
      LFormData: TMultipartFormData;
      LResp: IHTTPResponse;
      LJSON: TJSONObject;
      LInfo: TAIFileInfo;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LFormData := TMultipartFormData.Create;
      try
        LFormData.AddFile('file', AFilePath);
        LFormData.AddField('purpose', APurpose);

        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Files]), LFormData);
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
          try
            LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
            LInfo := TAIUtil.Deserialize<TAIFileInfo>(LJSON);
          except on E: Exception do
            raise EAIJSONException.Create(E.Message);
          end;

          DoFileUploaded(LInfo);
        end
        else
          DoError(LResp);
      finally
        LFormData.Free;
      end;
    end);
end;

procedure TAIOpenAIDriver.DoErrorJson(const ACallback: IAIJSONCallback; const AResponse: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(TAIUtil.TryExtractError(AResponse)); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, TAIUtil.TryExtractError(AResponse)); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end);
end;

procedure TAIOpenAIDriver.DoErrorStream(const ACallback: IAIStreamCallback; const AResponse: IHTTPResponse);
begin
  if Assigned(ACallback) then
    InvokeEvent(procedure begin ACallback.DoError(TAIUtil.TryExtractError(AResponse)); end)
  else if Assigned(FOnError) then
    InvokeEvent(procedure begin FOnError(Self, TAIUtil.TryExtractError(AResponse)); end)
  else
    InvokeEvent(procedure begin RaiseAIHTTPError(AResponse.StatusCode, AResponse.ContentAsString(TEncoding.UTF8), AResponse.Headers, cAIRequestFailed); end)
end;

function TAIOpenAIDriver.InternalGetAvailableModels: TArray<string>;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LData: TJSONArray;
  LItem, LJSON: TJSONValue;
  LList: TList<string>;
begin
  if (not CheckAPIKey) or (not CheckBaseURL) then
    Exit;

  LList := TList<string>.Create;
  try
    LHttpClient := TAIHttpClientConfig.CreateClient(FHttpClientCustomizer);
    try
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.Endpoint_Models]));
      except on E: Exception do
        begin
          DoError(E.Message, EAIHTTPException);
          Exit;
        end;
      end;

      if TAIUtil.IsSuccessfulResponse(LResp) then
      begin
        try
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          LData := LJSON.GetValue<TJSONArray>('data');
          if Assigned(LData) then
          begin
            for LItem in LData do
              LList.Add(LItem.GetValue<string>('id'));
          end;
        finally
          LJSON.Free;
        end;

        DoLoadModels(LList.ToArray);
      end
      else
        DoError(LResp);
    finally
      LHttpClient.Free;
    end;

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TAIOpenAIDriver.InternalGetDriverName: string;
begin
  Result := cOpenAI_DriverName;
end;

function TAIOpenAIDriver.InternalTestConnection(out AResponse: string): Boolean;
var
  LModels: TArray<string>;
begin
  try
    LModels := InternalGetAvailableModels;
    Result := Length(LModels) > 0;
    if Result then
      AResponse := cOpenAI_Msg_TestConnectionSuccess
    else
      AResponse := cOpenAI_Msg_TestConnectionError;
  except
    on E: Exception do
    begin
      Result := False;
      AResponse := 'Exception: ' + E.Message;
    end;
  end;
end;

function TAIOpenAIDriver.ListJobs: TGUID;
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
      LArr: TJSONArray;
      I: Integer;
      LJobs: TArray<TAIFineTuneJobSummary>;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      try
        LResp := LHttpClient.Get(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.EndPoint_StartFineTuning]));
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
        try
          LJSON := TJSONObject.ParseJSONValue(LResp.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
        except on E: Exception do
          raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
        end;

        try
          LArr := LJSON.GetValue<TJSONArray>('data');
          SetLength(LJobs, LArr.Count);

          for I := 0 to Pred(LArr.Count) do
            LJobs[I] := TAIUtil.Deserialize<TAIFineTuneJobSummary>(LArr.Items[I] as TJSONObject);

          DoFineTuneList(LJobs);
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.Moderate(const ARequest: TAIModerationRequest): TGUID;
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
      LResultArr: TJSONArray;
      LResultObj: TJSONObject;
      LResult: TAIModerationResult;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      LHttpClient.ContentType := cOpenAI_CHeader_JsonContentType;

      LStream := TStringStream.Create(TAIUtil.Serialize(ARequest), TEncoding.UTF8);
      try
        try
          LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [FOpenAIParams.EndPoint_Moderate]), LStream);
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
          LResultArr := LJSON.GetValue<TJSONArray>('results');
          if (LResultArr.Count > 0) and (LResultArr.Items[0] is TJSONObject) then
          begin
            LResultObj := LResultArr.Items[0] as TJSONObject;
            LResult := TAIUtil.Deserialize<TAIModerationResult>(LResultObj);
            DoModerationSuccess(LResult);
          end;
        finally
          LJSON.Free;
        end;
      end
      else
        DoError(LResp);
    end);
end;

function TAIOpenAIDriver.ProcessStream(const AEndpoint: string; const AInputFileName: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID;
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
      LMultipart: TMultipartFormData;
      LStream: TStringStream;
    begin
      LHttpClient.CustomHeaders['Authorization'] := cOpenAI_CHeader_Authorization + FOpenAIParams.APIKey;
      if not AInputFileName.IsEmpty then
      begin
        LMultipart := TMultipartFormData.Create;
        try
          LMultipart.AddFile('file', AInputFileName);
          LMultipart.AddField('model', FOpenAIParams.Model);
          for var Pair in AParams do
            LMultipart.AddField(Pair.JsonString.Value, Pair.JsonValue.Value);

          try
            LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, [AEndpoint]), LMultipart);
          except on E: Exception do
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
            LResp := LHttpClient.Post(TAIUtil.GetSafeFullURL(FOpenAIParams.BaseURL, AEndpoint), LStream);
          except on E: Exception do
            begin
              LHttpClient.Free;
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

procedure RegisterOpenAIDriver;
begin
  TAIDriverRegistry.RegisterDriverClass(
      cOpenAI_DriverName,
      cOpenAI_API_Name,
      cOpenAI_Description,
      cOpenAI_Category,
      TAIOpenAIDriver
    );
end;

initialization
  RegisterOpenAIDriver;

end.
