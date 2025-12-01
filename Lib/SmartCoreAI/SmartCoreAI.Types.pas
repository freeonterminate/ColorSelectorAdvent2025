{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Types;

interface

uses
  System.Classes, System.SysUtils, System.JSON, System.Net.HttpClient,
  System.Types, System.Generics.Collections, SmartCoreAI.HttpClientConfig;

type
{$REGION 'Basic Types'}
  /// <summary>
  ///   Controls how image payloads returned by providers are decoded or passed through.
  /// </summary>
  TAIImageDecodeMode = (idmAuto, idmBase64, idmURL, idmNone);

  /// <summary>
  ///   Event category used by some drivers to route callback results.
  /// </summary>
  TAIEventType = (etChat, etUnderstandImage);

  /// <summary>
  ///   Logical URL kinds used by drivers to compose provider endpoints.
  /// </summary>
  TAIUrlType = (utGenerateContentEndpoint, utModelsEndpoint, utGenerateImageEndPoint, utGenerateVideoEndPoint,
    utUnderstandVideoEndPoint, utUnderstandAudioEndPoint, utGenerateSpeechEndPoint, utGenerateMusicEndPoint,
    utUnderstandDocumentEndPoint, utGenerateImagePredictEndPoint);

{$ENDREGION}

{$REGION 'Events'}
  /// <summary>
  ///   Generic error event used across components and drivers.
  /// </summary>
  TAIErrorEvent = procedure(Sender: TObject; const ErrorMessage: string) of object;

  /// <summary>
  ///   Event raised when a driver reports available model identifiers.
  /// </summary>
  TAILoadModelsEvent = procedure(Sender: TObject; const AvailableModels: TArray<string>) of object;

  /// <summary>
  ///   Event raised when a chat interaction completes successfully.
  ///   Includes the extracted text and the raw JSON payload as text.
  /// </summary>
  TAIChatSuccessEvent = procedure(Sender: TObject; const ResponseText: string; const FullJsonResponse: string) of object;

  /// <summary>
  ///   Event raised when a request is cancelled. Carries the RequestId.
  /// </summary>
  TAICancelEvent = procedure(Sender: TObject; const RequestId: TGUID) of object;
{$ENDREGION}

{$REGION 'Interfaces'}

  /// <summary>
  ///   Minimal request contract for image generation.
  ///   Implementations usually add provider-specific fields alongside Prompt.
  /// </summary>
  IAIImageGenerationRequest = interface
    ['{AA7299C6-2AEB-4A22-867E-78765421E6D3}']
    /// <summary>Gets the prompt used to guide image generation.</summary>
    function GetPrompt: string;
    /// <summary>Sets the prompt used to guide image generation.</summary>
    procedure SetPrompt(const AValue: string);
    /// <summary>Prompt used by the provider.</summary>
    property Prompt: string read GetPrompt write SetPrompt;
  end;

  /// <summary>
  ///   Normalized result contract for image generation across providers.
  ///   Some fields may be empty depending on the provider and decode mode.
  ///   For example some API methods provide image URL some others provide Base64.
  /// </summary>
  IAIImageGenerationResult = interface
    ['{6B86A8DC-CE6F-41BF-BAC9-46BF54D2BF09}']
    /// <summary>Returns the image as a Base64-encoded string, if available.</summary>
    function GetImageB64: string;
    /// <summary>Returns a URL pointing to the generated image, if available.</summary>
    function GetImageURL: string;
    /// <summary>Returns the MIME type of the image content (e.g., image/png).</summary>
    function GetMimeType: string;
    /// <summary>Returns a stream for the image content, if available.</summary>
    function GetImageStream: TStream;

    /// <summary>Base64-encoded image content.</summary>
    property ImageB64: string read GetImageB64;
    /// <summary>URL to the generated image.</summary>
    property ImageURL: string read GetImageURL;
    /// <summary>Image MIME type.</summary>
    property MimeType: string read GetMimeType;
    /// <summary>Image stream (caller-owned or provider-owned depending on driver).</summary>
    property ImageStream: TStream read GetImageStream;
  end;

  /// <summary>
  /// Defines the callback interface for chat operations, allowing asynchronous handling of requests and responses.
  /// </summary>
  IAIChatCallback = interface
    ['{6CCCD04B-65D4-4F02-B4DF-375B59A439DB}']
    /// <summary>
    /// Called before the request is sent to the AI provider.
    /// </summary>
    procedure DoBeforeRequest;

    /// <summary>
    /// Called after the request is sent but before the response is processed.
    /// </summary>
    procedure DoAfterRequest;

    /// <summary>
    /// Called before processing the response from the AI provider.
    /// </summary>
    procedure DoBeforeResponse;

    /// <summary>
    /// Called after the response has been fully processed.
    /// </summary>
    procedure DoAfterResponse;

    /// <summary>
    /// Called when a full or partial response text is received.
    /// </summary>
    /// <param name="Text">The response text from the AI.</param>
    procedure DoResponse(const Text: string);

    /// <summary>
    /// Called when an error occurs during the operation.
    /// </summary>
    /// <param name="ErrorMessage">The error message.</param>
    procedure DoError(const ErrorMessage: string);

    /// <summary>
    /// Called with the full raw response from the AI provider.
    /// </summary>
    /// <param name="FullJsonResponse">The complete response string.</param>
    procedure DoFullResponse(const FullJsonResponse: string);

    /// <summary>
    /// Called for each partial response in streamed operations.
    /// </summary>
    /// <param name="PartialText">The incremental partial text.</param>
    procedure DoPartialResponse(const PartialText: string);
  end;

  /// <summary>
  /// Defines the callback interface for image generation operations.
  /// </summary>
  IAIImageCallback = interface
    ['{E5DB94B5-6523-48C2-82FE-A76F330DF69B}']
    /// <summary>
    /// Called on successful image generation.
    /// </summary>
    /// <param name="Images">Array of generated image results.</param>
    /// <param name="FullJsonResponse">The full JSON response from the service.</param>
    procedure DoSuccess(const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string);

    /// <summary>
    /// Called when an error occurs during image generation.
    /// </summary>
    /// <param name="ErrorMessage">The error description.</param>
    procedure DoError(const ErrorMessage: string);

    /// <summary>
    /// Called to determine the decod mode for images.
    /// </summary>
    function GetDecodeMode: TAIImageDecodeMode;
  end;

  /// <summary>
  /// Defines the callback interface for generic JSON-based requests, such as structured output or moderation.
  /// </summary>
  IAIJSONCallback = interface
    ['{B1DDC739-A72A-4DBD-97FC-D0CEBEF02F95}']
    /// <summary>
    /// Called on successful JSON response.
    /// </summary>
    /// <param name="Response">The parsed JSON response object.</param>
    procedure DoSuccess(const Response: string);

    /// <summary>
    /// Called when an error occurs during the JSON request.
    /// </summary>
    /// <param name="ErrorMessage">The error description.</param>
    procedure DoError(const ErrorMessage: string);

    /// <summary>
    /// Populates Json array into the Dataset
    /// </summary>
    /// <param name="JSONObject">The JSON object contained in response.</param>
    function PopulateDataset(const JSONObject: TJSONObject): Boolean;
  end;

  /// <summary>
  /// Defines the callback interface for stream-based operations, such as audio or video processing.
  /// </summary>
  IAIStreamCallback = interface
    ['{E19360B9-6E03-41B3-A650-31FD2BC31299}']
    /// <summary>
    /// Called on successful stream completion.
    /// </summary>
    /// <param name="Stream">The resulting stream data (e.g., audio/video).</param>
    procedure DoSuccess(const Stream: TStream);

    /// <summary>
    /// Called when an error occurs during streaming.
    /// </summary>
    /// <param name="ErrorMessage">The error description.</param>
    procedure DoError(const ErrorMessage: string);

    /// <summary>
    /// Called for partial data in progressive streaming.
    /// </summary>
    /// <param name="PartialData">The incremental byte data.</param>
    procedure DoPartial(const PartialData: TBytes);
  end;

  IAIJSONDataProvider = interface
    ['{08F81F06-8C39-4878-BC6C-C63F7F482A34}']
    /// <summary>
    /// Locate an array-of-objects suitable for tabular import within Root.
    /// InnerRoot is owned by the caller when not nil (e.g., when parsing stringified JSON).
    /// If OwnsArray = True, caller must free DataArray.
    /// </summary>
    function FindJSONData(const Root: TJSONObject; out DataArray: TJSONArray;
      out InnerRoot: TJSONValue; out OwnsArray: Boolean): Boolean;
  end;

  /// <summary>
  /// Defines the core interface for AI provider, providing methods for common operations across different AI services (e.g., OpenAI, Claude, Gemini, Ollama).
  /// Drivers must implement these methods; unsupported features should raise exceptions.
  /// Updated for 2025 APIs: Supports latest models like 'gpt-4.1' (OpenAI), 'claude-sonnet-4' (Claude), 'gemini-2.5-pro' (Gemini).
  /// </summary>
  IAIDriver = interface
    ['{F8E75763-8029-4C9F-B80D-68EB8A8A6FDA}']
    /// <summary>
    /// Returns the name of the driver (e.g., 'OpenAI', 'Claude').
    /// </summary>
    function GetDriverName: string;

    /// <summary>
    /// Tests the connection to the AI provider.
    /// </summary>
    /// <param name="AResponse">Output message indicating success or failure details.</param>
    /// <returns>True if connected successfully, False otherwise.</returns>
    function TestConnection(out AResponse: string): Boolean;

    /// <summary>
    /// Loads the list of available models from the AI provider.
    /// </summary>
    /// <returns>Array of model names.</returns>
    function LoadModels: TArray<string>;

    /// <summary>
    /// Performs a simple chat operation with the AI.
    /// </summary>
    /// <param name="APrompt">The user prompt.</param>
    /// <param name="ACallback">Callback for handling responses asynchronously.</param>
    /// <returns>RequestId that identifies this chat invocationId, can be used in Driver.Cancel(ID).</returns>
    function Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID;

    /// <summary>
    /// Generates images based on the request.
    /// </summary>
    /// <param name="ARequest">The image generation request parameter.</param>
    /// <param name="ACallback">Callback for image results or errors.</param>
    /// <returns>RequestId that identifies this request invocation Id, can be used in Driver.Cancel(ID).</returns>
    function GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID;

    /// <summary>
    /// Executes a generic JSON-based request to a custom endpoint (e.g., for moderation, fine-tuning).
    /// </summary>
    /// <param name="AEndpoint">The relative endpoint URL.</param>
    /// <param name="AParams">The JSON body for the request.</param>
    /// <param name="ACallback">Callback for JSON response or errors.</param>
    /// <returns>RequestId that identifies this request invocation Id, can be used in Driver.Cancel(ID).</returns>
    function ExecuteJSONRequest(const AEndpoint: string; const AParams: string; const ACallback: IAIJSONCallback): TGUID;

    /// <summary>
    /// Processes a stream-based operation (e.g., audio synthesis, video processing; supported by OpenAI, Gemini).
    /// </summary>
    /// <param name="AEndpoint">The relative endpoint URL.</param>
    /// <param name="AInput">Input fila path (e.g., file upload).</param>
    /// <param name="AParams">Additional JSON parameters.</param>
    /// <param name="ACallback">Callback for stream results or errors.</param>
    /// <returns>RequestId that identifies this request invocation Id, can be used in Driver.Cancel(ID).</returns>
    function ProcessStream(const AEndpoint: string; const AInput: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID;

    property DriverName: string read GetDriverName;
  end;

  /// <summary>
  ///  Auxiliary interface that lets a connection to provide a THTTPClient customizer
  ///  to a driver, so the driver can adjust TLS, proxy, headers, timeouts, and events.
  /// </summary>
  IAIHttpClientCustomizable = interface
    ['{B992DAB4-DAF4-4B3D-85B2-BEBC674A6393}']
     /// <summary>
    ///   HttpClient customizer procedure to handle TLS, proxy, headers, and other policies.
    /// </summary>
    procedure SetHttpClientCustomizer(const ACustomizer: TAIHttpClientCustomizer);
  end;

  /// <summary>
  ///   Minimal request abstraction consumed by component wrappers (Execute triggers action).
  /// </summary>
  IAIRequest = interface
    ['{C7934181-567D-4D61-8847-2833DAEAFD97}']
    /// <summary>Executes the configured request.</summary>
    function Execute: TGUID;
  end;

  /// <summary>
  ///   Connection abstraction exposing the active driver interface.
  /// </summary>
  IAIConnection = interface
    ['{17141BC9-0AE8-4DCD-B5A5-EFD443DA28BE}']
    /// <summary>Returns the driver interface bound to this connection.</summary>
    function GetDriverIntf: IAIDriver;
  end;
{$ENDREGION}

{$REGION 'Types'}

  /// <summary>
  ///   Parameter bag base class used by drivers. Accessors provide typed reads/writes
  ///   with defaults and optional normalization (for example paths).
  /// </summary>
  TAIDriverParams = class(TStringList)
  protected
    /// <summary>Reads a named integer value with a default.</summary>
    function AsInteger(const AName: string; ADefault: Integer): Integer;
    /// <summary>Reads a named floating-point value with a default.</summary>
    function AsFloat(const AName: string; ADefault: Double): Double;
    /// <summary>Reads a named boolean value with a default.</summary>
    function AsBoolean(const AName: string; ADefault: Boolean): Boolean;
    /// <summary>Reads a named string value with a default.</summary>
    function AsString(const AName: string; const ADefault: string): string;
    /// <summary>Reads a named path value with a default (may normalize).</summary>
    function AsPath(const AName: string; const ADefault: string): string;
    /// <summary>Writes a named integer value; removes key if equal to default.</summary>
    procedure SetAsInteger(const AName: string; const AValue: Integer; ADefault: Integer);
    /// <summary>Writes a named floating-point value; removes key if equal to default.</summary>
    procedure SetAsFloat(const AName: string; const AValue: Double; ADefault: Double);
    /// <summary>Writes a named boolean value; removes key if equal to default.</summary>
    procedure SetAsBoolean(const AName: string; const AValue: Boolean; ADefault: Boolean);
    /// <summary>Writes a named string value; removes key if equal to default.</summary>
    procedure SetAsString(const AName, AValue: string; const ADefault: string);
    /// <summary>Writes a named path value; removes key if equal to default.</summary>
    procedure SetAsPath(const AName, AValue: string; const ADefault: string);
    /// <summary>Deletes a key/value pair by name if present.</summary>
    procedure RemoveValue(const AName: string);
  public
    /// <summary>Creates the parameter bag with default options.</summary>
    constructor Create; virtual;
    /// <summary>Assigns from another persistent; merges values appropriately.</summary>
    procedure Assign(Source: TPersistent); override;
    /// <summary>Removes all keys and restores default values.</summary>
    procedure RestoreDefaults;
  end;


  /// <summary>
  ///   Per-request state tracked by drivers for cooperative cancellation.
  /// </summary>
  TAIRequestState = class
  public
    /// <summary>Unique identifier for this request.</summary>
    Id: TGUID;
    /// <summary>True when cancellation has been requested.</summary>
    Cancelled: Boolean;
  end;

  /// <summary>
  /// Abstract base class for AI drivers, implementing common functionality and declaring abstract methods for specific operations.
  /// Subclasses must implement all abstract methods.
  /// </summary>
  TAIDriver = class(TComponent, IAIDriver, IAIHttpClientCustomizable, IAIJSONDataProvider)
  private
    /// <summary>
    ///   Active requests keyed by RequestId. Used for cooperative cancellation and tracking.
    /// </summary>
    FActive: TObjectDictionary<TGUID, TAIRequestState>;

    /// <summary>
    ///   Cancels a specific Request by RequestId (internal helper that toggles state and raises OnCancel).
    /// </summary>
    procedure DoCancel(const AId: TGUID);

    /// <summary>
    ///   Checks if any request is running, True if FActive is empty.
    /// </summary>
    function GetIsRuning: Boolean;
  protected
    /// <summary>
    /// HttpClient Customizer Proc
    /// </summary>
    FHttpClientCustomizer: TAIHttpClientCustomizer;

    /// <summary>
    /// Event raised when a request is cancelled.
    /// </summary>
    FOnCancel: TAICancelEvent;

    /// <summary>
    /// Event raised when a request failed.
    /// </summary>
    FOnError: TAIErrorEvent;

    /// <summary>
    ///   When True, driver fires events synchronized to the main thread; otherwise,
    ///   events may be raised from background worker threads.
    /// </summary>
    FSynchronizeEvents: Boolean;

    /// <summary>
    /// Gets the driver parameters.
    /// </summary>
    function GetParams: TAIDriverParams; virtual; abstract;

    /// <summary>
    /// Sets the driver parameters.
    /// </summary>
    /// <param name="AValue">The parameters to set.</param>
    procedure SetParams(const AValue: TAIDriverParams); virtual; abstract;

    /// <summary>
    /// Internal method to get the driver name.
    /// </summary>
    function InternalGetDriverName: string; virtual; abstract;

    /// <summary>
    /// Internal method to test the connection.
    /// </summary>
    /// <param name="AResponse">Output response message.</param>
    /// <returns>True if successful.</returns>
    function InternalTestConnection(out AResponse: string): Boolean; virtual; abstract;

    /// <summary>
    /// Internal method to load available models.
    /// </summary>
    /// <returns>Array of model names.</returns>
    function InternalGetAvailableModels: TArray<string>; virtual; abstract;

    /// <summary>
    /// Locate an array-of-objects suitable for tabular import within Root.
    /// InnerRoot is owned by the caller when not nil (e.g., when parsing stringified JSON).
    /// If OwnsArray = True, caller must free DataArray.
    /// </summary>
    function FindJSONData(const ARoot: TJSONObject; out ADataArray: TJSONArray;
      out AInnerRoot: TJSONValue; out AOwnsArray: Boolean): Boolean; virtual;

    /// <summary>
    ///   Invokes AProc either directly or through synchronization depending on SynchronizeEvents.
    /// </summary>
    procedure InvokeEvent(const AProc: TProc);

    /// <summary>
    /// Raises a normalized error when the RUN method fails.
    /// </summary>
    procedure DoRequestError(const AId: TGUID; const E: Exception);

    /// <summary>
    ///   Registers a new active request and returns its state and RequestId.
    /// </summary>
    function BeginRequest(out AId: TGUID): TAIRequestState;

    /// <summary>
    ///   Adds an existing active request.
    /// </summary>
    function AddRequest(AId: TGUID): TAIRequestState;

    /// <summary>
    ///   Unregisters a completed/failed request.
    /// </summary>
    procedure EndRequest(const AId: TGUID);

    /// <summary>
    ///   Helper that executes AWork with a prepared THTTPClient and wires cooperative
    ///   cancellation using AState. Implementations call this to run HTTP work.
    ///   AClient will be freed inside this procedure, not by the Caller.
    /// </summary>
    procedure Run(const AState: TAIRequestState; AId: TGuid; const AClient: THTTPClient; const AWork: TProc);
  public
    /// <summary>
    /// Constructor for the driver.
    /// </summary>
    /// <param name="AOwner">Owner component.</param>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Destructor for the driver.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Gets the driver name.
    /// </summary>
    function GetDriverName: string;

    /// <summary>
    /// Tests the connection.
    /// </summary>
    /// <param name="AResponse">Response message.</param>
    /// <returns>True if successful.</returns>
    function TestConnection(out AResponse: string): Boolean;

    /// <summary>
    /// Loads available models.
    /// </summary>
    /// <returns>Array of models.</returns>
    function LoadModels: TArray<string>;

    /// <summary>
    /// Performs a chat operation (abstract; implement in subclasses).
    /// </summary>
    /// <param name="APrompt">Prompt text.</param>
    /// <param name="ACallback">Callback.</param>
    /// <returns>RequestId that identifies this chat invocationId, can be used in Driver.Cancel(ID).</returns>
    function Chat(const APrompt: string; const ACallback: IAIChatCallback): TGUID; virtual; abstract;

    // New abstract methods for extended interface
    /// <summary>
    /// Generates images based on the request (abstract; implement in subclasses like OpenAI, Gemini).
    /// </summary>
    /// <param name="ARequest">Image generation request parameter.</param>
    /// <param name="ACallback">Callback for results.</param>
    /// <returns>RequestId that identifies this chat invocationId, can be used in Driver.Cancel(ID).</returns>
    function GenerateImage(ARequest: IAIImageGenerationRequest; const ACallback: IAIImageCallback): TGUID; virtual; abstract;

    /// <summary>
    /// Executes a generic JSON request (abstract; implement in subclasses).
    /// </summary>
    /// <param name="AEndpoint">Endpoint URL.</param>
    /// <param name="AParams">JSON body.</param>
    /// <param name="ACallback">Callback for results.</param>
    /// <returns>RequestId that identifies this chat invocationId, can be used in Driver.Cancel(ID).</returns>
    function ExecuteJSONRequest(const AEndpoint: string; const AParams: string; const ACallback: IAIJSONCallback): TGUID; virtual; abstract;

    /// <summary>
    /// Processes a stream operation (abstract; implement in subclasses like OpenAI, Gemini).
    /// </summary>
    /// <param name="AEndpoint">Endpoint URL.</param>
    /// <param name="AInput">Input file path.</param>
    /// <param name="AParams">Additional parameters.</param>
    /// <param name="ACallback">Callback for results.</param>
    /// <returns>RequestId that identifies this chat invocationId, can be used in Driver.Cancel(ID).</returns>
    function ProcessStream(const AEndpoint: string; const AInput: string; const AParams: TJSONObject; const ACallback: IAIStreamCallback): TGUID; virtual; abstract;

    /// <summary>
    /// HttpClient Customizer procedure to handle TLs, proxy, etc if needed.
    /// </summary>
    procedure SetHttpClientCustomizer(const ACustomizer: TAIHttpClientCustomizer);

    /// <summary>
    /// UI hook: cancels all in-flight requests for this driver
    /// </summary>
    procedure CancelAll;

    /// <summary>
    /// Cancel a single request
    /// </summary>
    procedure Cancel(const AId: TGUID);

    /// <summary>
    /// Driver name property.
    /// </summary>
    property DriverName: string read GetDriverName;

    /// <summary>
    /// Checks if any request is running, True if FActive is empty.
    /// </summary>
    property IsRuning: Boolean read GetIsRuning;
  published
    property Params: TAIDriverParams read GetParams write SetParams;
    property OnCancel: TAICancelEvent read FOnCancel write FOnCancel;
    property SynchronizeEvents: Boolean read FSynchronizeEvents write FSynchronizeEvents default True;

  end;

  /// <summary>
  ///   Small helper that wraps an existing OnReceiveData (if any) and injects
  ///   cooperative cancellation by setting AAbort when the request state is cancelled.
  /// </summary>
  TAIReceiveDataHook = class
  private
    /// <summary>Previous handler to call before applying cancellation logic.</summary>
    FPrev: TReceiveDataEvent;
    /// <summary>Request state to observe for cancellation.</summary>
    FState: TAIRequestState;
  public
    /// <summary>
    ///   Creates the hook with an optional previous handler and a request state.
    /// </summary>
    constructor Create(const APrev: TReceiveDataEvent; const AState: TAIRequestState);

    /// <summary>
    ///   Combined receive-data handler that respects FPrev and flips AAbort when cancelled.
    /// </summary>
    procedure Handle(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean);
  end;


  /// <summary>
  ///   Utility helpers used across drivers and components.
  /// </summary>
  TAIUtil = class
  public
    /// <summary>
    ///   Returns True if the HTTP response indicates success (status code in 2xx).
    /// </summary>
    class function IsSuccessfulResponse(const AResponse: IHTTPResponse): Boolean;

    /// <summary>
    ///   Safely combines a base URL with one or more endpoint segments, avoiding duplicate slashes.
    /// </summary>
    class function GetSafeFullURL(const ABaseURL: string; const AEndPoints: array of string): string;

    /// <summary>
    ///   Serializes an object to JSON text (using RTTI/attributes as supported).
    /// </summary>
    class function Serialize(AObject: TObject): string;

    /// <summary>
    ///   Serializes an object to a TJSONObject instance.
    /// </summary>
    class function SerializeToJSONObject(const AValue: TObject): TJSONObject;

    /// <summary>
    ///   Deserializes a TJSONObject into an instance of T.
    /// </summary>
    class function Deserialize<T: class>(const AJSON: TJSONObject): T;

    /// <summary>
    ///   Detects the MIME type for the given byte array based on magic numbers.
    /// </summary>
    class function DetectImageMime(const Bytes: TBytes): string; overload;

    /// <summary>
    ///   Detects the MIME type for an image stream (position may be preserved by the implementation).
    /// </summary>
    class function DetectImageMime(const AStream: TStream): string; overload;

    /// <summary>
    ///   Downloads an image into a stream using TAIHttpClientCustomizer (optional).
    ///   Caller owns the returned stream.
    /// </summary>
    class function DownloadImage(AURL: string; AAIHttpClientCustomizer: TAIHttpClientCustomizer = nil): TStream;

    /// <summary>
    ///   Attempts to extract a JSON value from free-form text (for example fenced code blocks).
    /// </summary>
    class function ExtractJSONValueFromText(const S: string): TJSONValue; // parses code-fenced or embedded JSON

    /// <summary>
    ///   Searches deeply for a JSON array of objects within a JSON value.
    /// </summary>
    class function FindArrayOfObjectsDeep(const V: TJSONValue): TJSONArray;

     /// <summary>
    /// Converts a JSON array into an array of objects by wrapping each element under a given key.
    /// </summary>
    /// <param name="A">
    /// Source JSON array. Must not be nil. Typically an array of primitives (string/number/boolean/null),
    /// but any JSON value is accepted and will be cloned into the wrapper object.
    /// </param>
    /// <param name="AKey">
    /// Property name used for the wrapped value in each output object (e.g. "value" or the original field name).
    /// Should be non-empty and a valid JSON property name.
    /// </param>
    /// <returns>
    /// A newly allocated "System.JSON.TJSONArray" where each element is a
    /// System.JSON.TJSONObject" containing a single pair.
    /// The caller owns the returned instance and is responsible for freeing it.
    /// </returns>
    /// <remarks>
    /// The function performs a deep clone of each input element (via JSON round-trip) to avoid aliasing
    /// with the source array. The output length equals A.Count.
    /// If A is empty, an empty array is returned.
    /// </remarks>
    class function WrapPrimitiveArrayAsObjects(const A: TJSONArray; const AKey: string): TJSONArray;

    /// <summary>
    /// Determines whether the given JSON array is a non-empty array whose elements are all JSON objects.
    /// </summary>
    /// <param name="A">JSON array to inspect.</param>
    /// <returns>
    /// True if A is not nil, has at least one element, and every element is a
    /// "System.JSON.TJSONObject", otherwise False.
    /// </returns>
    class function IsArrayOfObjects(const A: TJSONArray): Boolean;

    /// <summary>
    ///   Attempts to extract a provider-specific error from an HTTP response.
    /// </summary>
    class function TryExtractError(const AResponse: IHTTPResponse): string;
  end;

 {$ENDREGION}

  const
    /// <summary>
    ///   Friendly names for TAIImageDecodeMode values.
    /// </summary>
    DecodeModeNames: array[TAIImageDecodeMode] of string = ('Auto', 'Base64', 'URL', 'None');


implementation

uses
  System.StrUtils, SmartCoreAI.Consts, System.JSON.Serializers, System.JSON.Readers,
  SmartCoreAI.Exceptions, System.TypInfo, System.Threading;

{$REGION 'Helper functions'}

class function TAIUtil.IsArrayOfObjects(const A: TJSONArray): Boolean;
var
  I: Integer;
begin
  Result := (A <> nil) and (A.Count > 0);
  if Result then
    for I := 0 to A.Count - 1 do
      if not (A.Items[I] is TJSONObject) then
        Exit(False);
end;

class function TAIUtil.IsSuccessfulResponse(const AResponse: IHTTPResponse): Boolean;
begin
  Result := (AResponse <> nil) and (AResponse.StatusCode >= 200) and (AResponse.StatusCode <= 299) and
            Assigned(AResponse.ContentStream) and (AResponse.ContentStream.Size > 0);
end;

class function TAIUtil.GetSafeFullURL(const ABaseURL: string; const AEndPoints: array of string): string;

  // Remove only trailing forward slashes (safe for "http://", keeps "://").
  function RStripSlash(const S: string): string;
  var
    I: Integer;
  begin
    I := Length(S);
    while (I > 0) and (S[I] = '/') do
      Dec(I);
    Result := Copy(S, 1, I);
  end;

  // Remove all leading and trailing forward slashes from a segment.
  function StripSlashes(const S: string): string;
  var
    L, R: Integer;
  begin
    L := 1;
    R := Length(S);
    while (L <= R) and (S[L] = '/') do Inc(L);
    while (R >= L) and (S[R] = '/') do Dec(R);
    if L <= R then
      Result := Copy(S, L, R - L + 1)
    else
      Result := '';
  end;

var
  I: Integer;
  Part: string;
begin
  // Start with base URL without trailing slashes
  Result := RStripSlash(Trim(ABaseURL));

  // Append normalized, non-empty endpoint segments
  for I := 0 to High(AEndPoints) do
  begin
    Part := StripSlashes(Trim(AEndPoints[I]));
    if Part = '' then
      Continue;

    if Result <> '' then
      if Part[1] = '?' then
        Result := Result + Part
      else
        Result := Result + '/' + Part
    else
      Result := Part; // handles empty base URL case
  end;
end;

class function TAIUtil.Deserialize<T>(const AJSON: TJSONObject): T;
var
  LRdr: TJsonObjectReader;
  LSer: TJsonSerializer;
begin
  if AJSON = nil then
    Exit(nil);

  LRdr := TJsonObjectReader.Create(AJSON);
  try
    LSer := TJsonSerializer.Create;
    try
      try
        Result := LSer.Deserialize<T>(LRdr);
      except on E: Exception do
        raise EAIJSONException.CreateFmt(
          'Failed to deserialize %s from JSON. %s'#13#10'JSON: %s',
          [GetTypeName(TypeInfo(T)), E.Message, Copy(AJSON.ToJSON, 1, 1024)] // The actual JSON string might be so big.
          );
      end;
    finally
      LSer.Free;
    end;
  finally
    LRdr.Free;
  end;
end;

class function TAIUtil.Serialize(AObject: TObject): string;
var
  LSer: TJsonSerializer;
begin
  LSer := TJsonSerializer.Create;
  try
    try
      Result := LSer.Serialize(AObject);
    except on E: Exception do
      raise EAIJSONException.Create(E.Message);
    end;
  finally
    LSer.Free;
  end;
end;

class function TAIUtil.SerializeToJSONObject(const AValue: TObject): TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(Serialize(AValue), False, True) as TJSONObject;
end;

class function TAIUtil.TryExtractError(const AResponse: IHTTPResponse): string;
var
  LJSON: TJSONObject;
  LBasicErrorMsg: string;

  LErrVal: TJSONValue;
  LErrObj: TJSONObject;

  LMsg, LType, LStatus, LCodeStr: string;
  LCodeInt: Integer;

  LDetails: TJSONArray;
  LDetail: TJSONValue;
  LObj: TJSONObject;
  LFieldViolations: TJSONArray;
  LFVItem: TJSONObject;
  LDesc: string;
begin
  LBasicErrorMsg := Format(cAI_Msg_HttpError, [AResponse.StatusCode, AResponse.StatusText]);
  Result := LBasicErrorMsg;

  try
    LJSON := TJSONObject.ParseJSONValue(AResponse.ContentAsString(TEncoding.UTF8), False, True) as TJSONObject;
  except
    on E: Exception do
      raise EAIJSONException.CreateFmt(cAIInvalidJSONError, [E.Message]);
  end;

  try
    if LJSON = nil then
      Exit;

    // Most providers (OpenAI, Gemini, CLude) wrap details under "error"
    if LJSON.TryGetValue<TJSONValue>('error', LErrVal) then
    begin
      if LErrVal is TJSONObject then
      begin
        LErrObj := TJSONObject(LErrVal);
        LErrObj.TryGetValue<string>('message', LMsg);

        // ---- OpenAI & Clude -style ----
        LErrObj.TryGetValue<string>('type', LType); // e.g., "invalid_request_error"
        if not LErrObj.TryGetValue<string>('code', LCodeStr) then
          if LErrObj.TryGetValue<Integer>('code', LCodeInt) then
            LCodeStr := LCodeInt.ToString;

        // ---- Gemini (Google) style ----
        LErrObj.TryGetValue<string>('status', LStatus); // e.g., "INVALID_ARGUMENT"

        if LType <> '' then
        begin
          if LCodeStr <> '' then
            Exit(Format(cOpenAI_Msg_HttpErrorFull, [LMsg, LCodeStr, LType]))
          else
            Exit(Format(cOpenAI_Msg_HttpErrorType, [LMsg, LType]));
        end
        else if (LStatus <> '') or (LCodeStr <> '') then
        begin
          // Gemini / Google APIs: try extracting a helpful detail line
          if LErrObj.TryGetValue<TJSONArray>('details', LDetails) and (LDetails.Count > 0) then
          begin
            for LDetail in LDetails do
            begin
              if LDetail is TJSONObject then
              begin
                LObj := TJSONObject(LDetail);

                // google BadRequest, fieldViolations[].description
                if LObj.TryGetValue<TJSONArray>('fieldViolations', LFieldViolations) then
                begin
                  if (LFieldViolations.Count > 0) and (LFieldViolations.Items[0] is TJSONObject) then
                  begin
                    LFVItem := TJSONObject(LFieldViolations.Items[0]);
                    if LFVItem.TryGetValue<string>('description', LDesc) and (LDesc <> '') then
                    begin
                      if LMsg = '' then LMsg := LDesc else LMsg := LMsg + ' - ' + LDesc;
                      Break;
                    end;
                  end;
                end
                // if a plain "message" is available inside a details object
                else if LObj.TryGetValue<string>('message', LDesc) and (LDesc <> '') then
                begin
                  if LMsg = '' then
                    LMsg := LDesc
                  else
                    LMsg := LMsg + ' - ' + LDesc;
                  Break;
                end;
              end;
            end;
          end;

          if LMsg = '' then
            LMsg := LBasicErrorMsg;

          if (LStatus <> '') and (LCodeStr <> '') then
            Exit(Format(cOpenAI_Msg_HttpErrorFull, [LMsg, LStatus, LCodeStr]))
          else if (LStatus <> '') then
            Exit(Format('%s (status=%s)', [LMsg, LStatus]))
          else
            Exit(Format(cOpenAI_Msg_HttpErrorType, [LMsg, LCodeStr]));
        end
        else if LMsg <> '' then
          Exit(LMsg)
        else
          Exit(LBasicErrorMsg);
      end
      else if LErrVal is TJSONString then // if the error is just a simple string.
      begin
        LMsg := TJSONString(LErrVal).Value;
        if LMsg <> '' then
          Exit(LMsg);
      end;
    end;

    // if the message is available at the top level
    if LJSON.TryGetValue<string>('message', LMsg) and (LMsg <> '') then
      Exit(LMsg);

    // Fallback to the basic if nothing found.
    Result := LBasicErrorMsg;
  finally
    LJSON.Free;
  end;
end;

class function TAIUtil.WrapPrimitiveArrayAsObjects(const A: TJSONArray; const AKey: string): TJSONArray;
var
  I: Integer;
  LObj: TJSONObject;
  LVal: TJSONValue;
begin
  Result := TJSONArray.Create;
  for I := 0 to A.Count - 1 do
  begin
    LObj := TJSONObject.Create;
    LVal := TJSONValue.ParseJSONValue(A.Items[I].ToJSON, False, True);
    LObj.AddPair(AKey, LVal);
    Result.AddElement(LObj);
  end;
end;

function LStartsWith(const Buf: TBytes; const Sig: array of Byte; const Offset: Integer = 0): Boolean;
var
  I: Integer;
begin
  Result := (Length(Buf) >= Offset + Length(Sig));
  if not Result then Exit;
  for I := 0 to High(Sig) do
    if Buf[Offset + I] <> Sig[I] then
      Exit(False);
  Result := True;
end;

function LASCIIMatch(const Buf: TBytes; const Offset: Integer; const S: AnsiString): Boolean;
var
  I: Integer;
begin
  Result := (Length(Buf) >= Offset + Length(S));
  if not Result then Exit;
  for I := 1 to Length(S) do
    if Byte(Buf[Offset + (I - 1)]) <> Byte(S[I]) then
      Exit(False);
  Result := True;
end;

function LASCIIFind(const Buf: TBytes; const S: AnsiString; StartAt: Integer = 0): Integer;
var
  I, J, L: Integer;
begin
  Result := -1;
  L := Length(S);
  if (L = 0) or (StartAt < 0) or (StartAt >= Length(Buf)) then Exit;
  for I := StartAt to Length(Buf) - L do
  begin
    for J := 1 to L do
      if Byte(Buf[I + (J - 1)]) <> Byte(S[J]) then
        Break
      else if J = L then
        Exit(I);
  end;
end;

function LSkipUTF8BOMAndWS(const Buf: TBytes): Integer;
var
  I: Integer;
begin
  I := 0;
  // UTF-8 BOM: EF BB BF
  if (Length(Buf) >= 3) and (Buf[0] = $EF) and (Buf[1] = $BB) and (Buf[2] = $BF) then
    I := 3;
  // skip ASCII whitespace
  while (I < Length(Buf)) and (Buf[I] in [9, 10, 13, 32]) do
    Inc(I);
  Result := I;
end;

class function TAIUtil.DetectImageMime(const Bytes: TBytes): string;
var
  P: Integer;
  // case-insensitive check for "<svg"
  function LLooksLikeSVG: Boolean;
  const SVG_OPEN_LOWER: array[0..3] of Byte = (Ord('<'), Ord('s'), Ord('v'), Ord('g'));
  var
    I: Integer;
    B: Byte;
  begin
    Result := False;

    if P + 4 > Length(Bytes) then Exit;
    for I := 0 to 3 do
    begin
      B := Bytes[P + I];
      // lowercase
      if (B >= Ord('A')) and (B <= Ord('Z')) then
        B := B + 32;
      if B <> SVG_OPEN_LOWER[I] then
        Exit;
    end;
    Result := True;
  end;

begin
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if LStartsWith(Bytes, [$89, $50, $4E, $47, $0D, $0A, $1A, $0A]) then
    Exit('image/png');

  // JPEG: FF D8 FF
  if LStartsWith(Bytes, [$FF, $D8, $FF]) then
    Exit('image/jpeg');

  // GIF: "GIF87a" or "GIF89a"
  if LASCIIMatch(Bytes, 0, AnsiString('GIF87a')) or LASCIIMatch(Bytes, 0, AnsiString('GIF89a')) then
    Exit('image/gif');

  // WebP: "RIFF"...."WEBP" (at 0 and 8)
  if LASCIIMatch(Bytes, 0, AnsiString('RIFF')) and (Length(Bytes) >= 12) and LASCIIMatch(Bytes, 8, AnsiString('WEBP')) then
    Exit('image/webp');

  // BMP: "BM"
  if lASCIIMatch(Bytes, 0, AnsiString('BM')) then
    Exit('image/bmp');

  // ICO: 00 00 01 00
  if LStartsWith(Bytes, [$00, $00, $01, $00]) then
    Exit('image/vnd.microsoft.icon');

  // TIFF: "II" 2A 00  or  "MM" 00 2A
  if ( LStartsWith(Bytes, [$49, $49, $2A, $00]) or LStartsWith(Bytes, [$4D, $4D, $00, $2A]) ) then
    Exit('image/tiff');

  // ISOBMFF (HEIC/HEIF/AVIF): box[0..3]=size, [4..7]='ftyp', brands after
  if (Length(Bytes) >= 24) and LASCIIMatch(Bytes, 4, AnsiString('ftyp')) then
  begin
    // look for brands in first 64 bytes
    if (LASCIIFind(Bytes, AnsiString('heic'), 8) >= 0) or
       (LASCIIFind(Bytes, AnsiString('heif'), 8) >= 0) or
       (LASCIIFind(Bytes, AnsiString('heix'), 8) >= 0) or
       (LASCIIFind(Bytes, AnsiString('hevc'), 8) >= 0) or
       (LASCIIFind(Bytes, AnsiString('hevx'), 8) >= 0) then
      Exit('image/heic');

    if (LASCIIFind(Bytes, AnsiString('avif'), 8) >= 0) or
       (LASCIIFind(Bytes, AnsiString('avis'), 8) >= 0) then
      Exit('image/avif');
  end;

  // SVG (text): optional BOM/WS then "<svg" (or "<?xml...<svg")
  P := LSkipUTF8BOMAndWS(Bytes);
  if P < Length(Bytes) then
  begin
    if LLooksLikeSVG then
      Exit('image/svg+xml');
    // handle "<?xml"
    if LASCIIMatch(Bytes, P, AnsiString('<?xml')) then
    begin
      // find next '<svg'
      var PosLT := LASCIIFind(Bytes, AnsiString('<svg'), P);
      if PosLT >= 0 then
        Exit('image/svg+xml');
    end;
  end;

  // Unknown
  Result := '';
end;

class function TAIUtil.DetectImageMime(const AStream: TStream): string;
var
  Buf: TBytes;
  LPos: Int64;
  N, ToRead: Integer;
begin
  if AStream = nil then
    Exit('');

  // Read up to 64 bytes (enough for our checks)
  SetLength(Buf, 64);
  LPos := 0;
  try
    try
      LPos := AStream.Position;
    except
      // non-seekable; we still try reading
    end;

    ToRead := Length(Buf);
    N := AStream.Read(Buf, 0, ToRead);
    SetLength(Buf, N);
  finally
    // restore position when possible
    try
      if LPos <> 0 then
        AStream.Position := LPos;
    except
      // ignore if not seekable
    end;
  end;

  Result := DetectImageMime(Buf);
end;

class function TAIUtil.DownloadImage(AURL: string; AAIHttpClientCustomizer: TAIHttpClientCustomizer = nil): TStream;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LTmpStream: TMemoryStream;
begin
  Result := nil;
  if AURL = '' then
    Exit;

  LHttpClient := TAIHttpClientConfig.CreateClient(AAIHttpClientCustomizer);
  try
    try
      LResp := LHttpClient.Get(AURL, nil);
    except on E: Exception do
      raise EAIHTTPException.Create(E.Message);
    end;

    if TAIUtil.IsSuccessfulResponse(LResp) and Assigned(LResp.ContentStream) then
    begin
      LTmpStream := TMemoryStream.Create;
      try
        LResp.ContentStream.Position := 0;
        LTmpStream.CopyFrom(LResp.ContentStream, LResp.ContentStream.Size);
        LTmpStream.Position := 0;
        Result := LTmpStream; // caller takes ownership
      except on E: Exception do
        begin
          LTmpStream.Free;
          raise EAIException.Create(E.Message);
        end;
      end;
    end;
  finally
    LHttpClient.Free;
  end;
end;

class function TAIUtil.ExtractJSONValueFromText(const S: string): TJSONValue;
  function StripFences(const T: string): string;
  var L, R: Integer; S1: string;
  begin
    S1 := T.Trim;
    if S1.StartsWith('```') then
    begin
      L := S1.IndexOf(#10);
      if L >= 0 then S1 := S1.Substring(L + 1).Trim;
      R := S1.LastIndexOf('```');
      if R >= 0 then S1 := S1.Substring(0, R).Trim;
    end;
    Result := S1;
  end;
  function TryCarve(const T: string): TJSONValue;
  var a,i,depth: Integer; C: Char; S1: string;
  begin
    Result := nil;
    a := T.IndexOf('{');
    if a >= 0 then
    begin
      depth := 0;
      for i := a to T.Length - 1 do
      begin
        C := T.Chars[i];
        if C = '{' then Inc(depth) else
        if C = '}' then
        begin
          Dec(depth);
          if depth = 0 then
          begin
            S1 := T.Substring(a, i - a + 1);
            Exit(TJSONObject.ParseJSONValue(S1, False, True));
          end;
        end;
      end;
    end;
    a := T.IndexOf('[');
    if a >= 0 then
    begin
      depth := 0;
      for i := a to T.Length - 1 do
      begin
        C := T.Chars[i];
        if C = '[' then Inc(depth) else
        if C = ']' then
        begin
          Dec(depth);
          if depth = 0 then
          begin
            S1 := T.Substring(a, i - a + 1);
            Exit(TJSONObject.ParseJSONValue(S1, False, True));
          end;
        end;
      end;
    end;
  end;
var T1: string;
begin
  T1 := StripFences(S);
  Result := TJSONObject.ParseJSONValue(T1, False, True);
  if Assigned(Result) then Exit;
  Result := TryCarve(T1);
end;

class function TAIUtil.FindArrayOfObjectsDeep(const V: TJSONValue): TJSONArray;
var
  P: TJSONPair; A: TJSONArray; I: Integer; It: TJSONValue;
  AllObj: Boolean; Found: TJSONArray;
begin
  Result := nil;
  if V is TJSONArray then
  begin
    A := TJSONArray(V);
    if A.Count > 0 then
    begin
      AllObj := True;
      for I := 0 to A.Count - 1 do
        if not (A.Items[I] is TJSONObject) then
          begin AllObj := False; Break; end;
      if AllObj then Exit(A);
    end;
    for I := 0 to A.Count - 1 do
    begin
      Found := FindArrayOfObjectsDeep(A.Items[I]);
      if Assigned(Found) then Exit(Found);
    end;
  end
  else if V is TJSONObject then
    for P in TJSONObject(V) do
    begin
      It := P.JsonValue;
      Found := FindArrayOfObjectsDeep(It);
      if Assigned(Found) then Exit(Found);
    end;
end;

{$ENDREGION}
{ TAIDriverParams }

constructor TAIDriverParams.Create;
begin
  inherited Create;
  StrictDelimiter := True;
  Duplicates := dupIgnore;
  CaseSensitive := False;
end;

procedure TAIDriverParams.Assign(Source: TPersistent);
begin
  if Source is TStrings then
    SetStrings(TStrings(Source))
  else
    inherited Assign(Source);
end;

procedure TAIDriverParams.RestoreDefaults;
begin
  Clear;
end;

function TAIDriverParams.AsInteger(const AName: string; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(Values[AName], ADefault);
end;

function TAIDriverParams.AsFloat(const AName: string; ADefault: Double): Double;
begin
  Result := StrToFloatDef(Values[AName], ADefault);
end;

function TAIDriverParams.AsBoolean(const AName: string; ADefault: Boolean): Boolean;
begin
  Result := StrToBoolDef(Values[AName], ADefault);
end;

function TAIDriverParams.AsString(const AName, ADefault: string): string;
begin
  Result := Values[AName];
  if Result.IsEmpty then
    Result := ADefault;
end;

function TAIDriverParams.AsPath(const AName, ADefault: string): string;
begin
  Result := Values[AName].TrimRight(['/']);
  if Result.IsEmpty then
    Result := ADefault;
end;

procedure TAIDriverParams.RemoveValue(const AName: string);
var
  I: Integer;
begin
  I := IndexOfName(AName);
  if I >= 0 then
    Delete(I);
end;

procedure TAIDriverParams.SetAsInteger(const AName: string; const AValue: Integer;
  ADefault: Integer);
begin
  if AValue = ADefault then
    RemoveValue(AName)
  else
    Values[AName] := IntToStr(AValue);
end;

procedure TAIDriverParams.SetAsFloat(const AName: string; const AValue: Double;
  ADefault: Double);
begin
  if AValue = ADefault then
    RemoveValue(AName)
  else
    Values[AName] := FloatToStr(AValue);
end;

procedure TAIDriverParams.SetAsBoolean(const AName: string; const AValue: Boolean;
  ADefault: Boolean);
begin
  if AValue = ADefault then
    RemoveValue(AName)
  else
    Values[AName] := BoolToStr(AValue, True);
end;

procedure TAIDriverParams.SetAsString(const AName, AValue: string;
  const ADefault: string);
begin
  if AnsiSameText(AValue, ADefault) or AValue.IsEmpty then
    RemoveValue(AName)
  else
    Values[AName] := AValue;
end;

procedure TAIDriverParams.SetAsPath(const AName, AValue: string;
  const ADefault: string);
begin
  if AnsiSameText(AValue.TrimRight(['/']), ADefault.TrimRight(['/'])) or AValue.IsEmpty then
    RemoveValue(AName)
  else
    Values[AName] := AValue;
end;

{ TAIDriver }

constructor TAIDriver.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSynchronizeEvents := True;
  FActive := TObjectDictionary<TGUID, TAIRequestState>.Create([doOwnsValues]);
end;

destructor TAIDriver.Destroy;
begin
  FreeAndNil(FActive);
  inherited;
end;

function TAIDriver.AddRequest(AId: TGUID): TAIRequestState;
begin
  Result := TAIRequestState.Create;
  Result.Id := AId;
  Result.Cancelled := False;

  TMonitor.Enter(FActive);
  try
    if not FActive.ContainsKey(AId) then
      FActive.Add(AId, Result);
  finally
    TMonitor.Exit(FActive);
  end;
end;

function TAIDriver.BeginRequest(out AId: TGUID): TAIRequestState;
begin
  CreateGUID(AId);
  Result := TAIRequestState.Create;
  Result.Id := AId;
  Result.Cancelled := False;

  TMonitor.Enter(FActive);
  try
    FActive.Add(AId, Result);
  finally
    TMonitor.Exit(FActive);
  end;
end;

procedure TAIDriver.EndRequest(const AId: TGUID);
begin
  if FActive = nil then
    Exit;

  TMonitor.Enter(FActive);
  try
    FActive.Remove(AId);
  finally
    TMonitor.Exit(FActive);
  end;
end;

procedure TAIDriver.DoCancel(const AId: TGUID);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self, AId)
  else
    raise EAIException.Create(cAI_Msg_OperationCancelled);
end;

procedure TAIDriver.DoRequestError(const AId: TGUID; const E: Exception);
var
  LMsg: string;
begin
  LMsg := Format(cAI_Msg_EventHandlerFailed, [E.ClassName, E.Message]);

  if E is EAIHTTPException then
  begin
    if EAIHTTPException(E).ErrorCode <> '' then
      LMsg := EAIHTTPException(E).ErrorCode
    else
      LMsg := E.Message;
  end
  else if E is EAIException then
    LMsg := E.Message;

   // Marshal to UI thread explicitly
  TThread.Queue(nil,
    procedure
    begin
      try
        if Assigned(FOnError) then
          FOnError(Self, LMsg);
      except on E: Exception do
        raise EAIException.CreateFmt(cAI_Msg_EventHandlerFailed, [E.ClassName, E.Message]);
      end;
    end);
end;

procedure TAIDriver.Cancel(const AId: TGUID);
var
  LState: TAIRequestState;
begin
  TMonitor.Enter(FActive);
  try
    if FActive.TryGetValue(AId, LState) then
      LState.Cancelled := True;
  finally
    TMonitor.Exit(FActive);
  end;

  DoCancel(AId);
end;

procedure TAIDriver.CancelAll;
var
  P: TPair<TGUID, TAIRequestState>;
begin
  TMonitor.Enter(FActive);
  try
    for P in FActive do
    begin
      P.Value.Cancelled := True;
      DoCancel(P.Value.Id);
    end;
  finally
    TMonitor.Exit(FActive);
  end;
end;

procedure TAIDriver.Run(const AState: TAIRequestState; AId: TGuid; const AClient: THTTPClient; const AWork: TProc);
begin
  TTask.Run(
    procedure
    var
      LHook: TAIReceiveDataHook;
    begin
      try
        // Hook per-request ReceiveData to make the HTTP read abort as soon as possible
        LHook := TAIReceiveDataHook.Create(AClient.OnReceiveData, AState);
        AClient.OnReceiveData := LHook.Handle;
        try
          try
            AWork();

            if AState.Cancelled then
              Exit; // swallows any "success" path silently, OnCancel already fired in Cancel().
          except on E: Exception do
            begin
              if AState.Cancelled then
                Exit;

              DoRequestError(AId, E);
              Exit;
            end;
          end;
        finally
          LHook.Free;
          EndRequest(AId);
        end;
      finally
        AClient.Free;
      end;
    end);
end;

function TAIDriver.FindJSONData(const ARoot: TJSONObject;
  out ADataArray: TJSONArray; out AInnerRoot: TJSONValue;
  out AOwnsArray: Boolean): Boolean;

  function FirstArrayOfObjectsDeep(const V: TJSONValue): TJSONArray;
  var
    P: TJSONPair;
    A: TJSONArray;
    I: Integer;
    It: TJSONValue;
    AllObj: Boolean;
    Found: TJSONArray;
  begin
    Result := nil;
    if V is TJSONArray then
    begin
      A := TJSONArray(V);
      if A.Count > 0 then
      begin
        AllObj := True;
        for I := 0 to A.Count - 1 do
          if not (A.Items[I] is TJSONObject) then
          begin
            AllObj := False; Break;
          end;
        if AllObj then Exit(A);
      end;
      for I := 0 to A.Count - 1 do
      begin
        Found := FirstArrayOfObjectsDeep(A.Items[I]);
        if Assigned(Found) then Exit(Found);
      end;
    end
    else if V is TJSONObject then
      for P in TJSONObject(V) do
      begin
        It := P.JsonValue;
        Found := FirstArrayOfObjectsDeep(It);
        if Assigned(Found) then Exit(Found);
      end;
  end;
begin
  ADataArray := FirstArrayOfObjectsDeep(ARoot);
  AInnerRoot := nil;
  AOwnsArray := False;

  if not Assigned(ADataArray) then
  begin
    // Last resort: wrap whole object as single row
    ADataArray := TJSONArray.Create;
    AOwnsArray := True;
    ADataArray.AddElement(TJSONObject.ParseJSONValue(ARoot.ToJSON, False, True) as TJSONObject);
  end;
  Result := True;
end;

function TAIDriver.LoadModels: TArray<string>;
begin
  Result := InternalGetAvailableModels;
end;

procedure TAIDriver.SetHttpClientCustomizer(const ACustomizer: TAIHttpClientCustomizer);
begin
  FHttpClientCustomizer := ACustomizer;
end;

function TAIDriver.GetDriverName: string;
begin
  Result := InternalGetDriverName;
end;

function TAIDriver.GetIsRuning: Boolean;
begin
  TMonitor.Enter(FActive);
  try
    Result := FActive.Count > 0;
  finally
    TMonitor.Exit(FActive);
  end;
end;

procedure TAIDriver.InvokeEvent(const AProc: TProc);
begin
  if not Assigned(AProc) then
    Exit;

  try
    if FSynchronizeEvents and (TThread.Current.ThreadID <> MainThreadID) then
      TThread.Synchronize(nil,
      procedure
      begin
        AProc;
      end)
    else
      AProc;
  except
    on E: Exception do
      raise EAIException.CreateFmt(cAI_Msg_EventHandlerFailed, [E.ClassName, E.Message]);
  end;
end;

function TAIDriver.TestConnection(out AResponse: string): Boolean;
begin
  Result := InternalTestConnection(AResponse);
end;

{ TReceiveDataHook }

constructor TAIReceiveDataHook.Create(const APrev: TReceiveDataEvent; const AState: TAIRequestState);
begin
  inherited Create;
  FPrev := APrev;
  FState := AState;
end;

procedure TAIReceiveDataHook.Handle(const Sender: TObject; AContentLength, AReadCount: Int64; var AAbort: Boolean);
var
  PrevAbort: Boolean;
begin
  if Assigned(FPrev) then
  begin
    PrevAbort := AAbort;
    FPrev(Sender, AContentLength, AReadCount, PrevAbort);
    AAbort := PrevAbort;
  end;
  if FState.Cancelled then
    AAbort := True;
end;

end.
