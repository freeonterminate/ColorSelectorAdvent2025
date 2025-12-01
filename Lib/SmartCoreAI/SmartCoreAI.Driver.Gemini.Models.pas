{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Gemini.Models;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils,
  System.NetEncoding, System.JSON.Serializers, System.JSON.Converters,
  System.Json.Types, System.JSON, SmartCoreAI.HttpClientConfig,
  SmartCoreAI.Types, SmartCoreAI.Consts;

type
  TAIGeminiSchemaField = class;
  TAIGeminiFunctionParamSchema = class;

  TAIGeminiSchemaFieldListConverter  = class(TJsonListConverter<TAIGeminiSchemaField>);
  TAIStringVariantDictConverter      = class(TJsonStringDictionaryConverter<Variant>);
  TAIGeminiParamSchemaDictConverter  = class(TJsonStringDictionaryConverter<TAIGeminiFunctionParamSchema>);
  TAIGeminiEnumNameConverter         = class(TJsonEnumNameConverter);

  // Inline audio file input for understanding (base64 encoded)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiAudioInput = class
  private
    FMimeType: string;
    FData: string;
  public
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;
    [JSONName('data')]     property Data: string read FData write FData;
  end;
                                                       
  // Request to analyze an audio file
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandAudioRequest = class
  private
    FAudio: TAIGeminiAudioInput;
    FPrompt: string;
  public
    [JSONName('audio')]  property Audio: TAIGeminiAudioInput read FAudio write FAudio;
    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
  end;

  // Response with analysis/transcription of audio
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandAudioResponse = class
  private
    FText: string;
  public
    [JSONName('text')] property Text: string read FText write FText;
  end;

  // Request to synthesize speech (text-to-speech)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiSpeechGenerationRequest = class
  private
    FText: string;
    FVoice: string;
    FLanguageCode: string;
  public
    [JSONName('text')]         property Text: string read FText write FText;
    [JSONName('voice')]        property Voice: string read FVoice write FVoice;
    [JSONName('languageCode')] property LanguageCode: string read FLanguageCode write FLanguageCode;
  end;

  // Response containing base64 audio
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiSpeechGenerationResponse = class
  private
    FAudioData: string;
    FMimeType: string;
  public
    [JSONName('audioData')] property AudioData: string read FAudioData write FAudioData;
    [JSONName('mimeType')]  property MimeType: string read FMimeType write FMimeType;
  end;

  //Imagen Predict
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiImagenPredictParameters = class
  private
    FSampleCount: Integer;
    FAspectRatio: string;
    FSampleImageSize: string;
    FPersonGeneration: string;
  public
    constructor Create;

    [JSONName('sampleCount')]      property SampleCount: Integer read FSampleCount write FSampleCount; // default 1..4
    [JSONName('aspectRatio')]      property AspectRatio: string read FAspectRatio write FAspectRatio; // "1:1","16:9", etc.
    [JSONName('sampleImageSize')]  property SampleImageSize: string read FSampleImageSize write FSampleImageSize; // "1K","2K" (Std/Ultra)
    [JSONName('personGeneration')] property PersonGeneration: string read FPersonGeneration write FPersonGeneration; // "allow_adult"/"dont_allow"
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiImagenPredictInstance = class
  private
    FPrompt: string;
  public
    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiImagenPredictRequest = class
  private
    FInstances: TObjectList<TAIGeminiImagenPredictInstance>;
    FParameters: TAIGeminiImagenPredictParameters;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetPrompt(const AValue: string);
    function BuildJSON: string;

    [JSONName('instances')]  property Instances: TObjectList<TAIGeminiImagenPredictInstance> read FInstances;
    [JSONName('parameters')] property Parameters: TAIGeminiImagenPredictParameters read FParameters;
  end;

  // Represents binary image content (e.g., inline base64-encoded image)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiInlineData = class
  private
    FMimeType: string;
    FData: string;
  public
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;
    [JSONName('data')]     property Data: string read FData write FData;
  end;

  // Image part (used in image understanding or generation prompts)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiImagePart = class
  private
    FText: string;
    FInlineData: TAIGeminiInlineData;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('text')]       property Text: string read FText write FText;
    [JSONName('inlineData')] property InlineData: TAIGeminiInlineData read FInlineData write FInlineData;
  end;

  // Request for generating an image
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateImageRequest = class(TInterfacedObject, IAIImageGenerationRequest)
  private
    FPrompt: string;
    FImages: TObjectList<TAIGeminiInlineData>;
    function GetPrompt: string;
    procedure SetPrompt(const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;

    function BuildGenerateContentJSON: string;
    procedure AddImageBase64(const AMimeType, ABase64: string);
    procedure AddImageFromStream(AStream: TStream; const AMimeType: string);

    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
    [JsonIgnore]         property Images: TObjectList<TAIGeminiInlineData> read FImages;
  end;

  // Response metadata (for each generated image)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiImageGenerationResult = class(TInterfacedObject, IAIImageGenerationResult)
  private
    FMimeType: string;
    FData: string;
    FStream: TStream;

    //IAIImageGenerationResult
    function GetImageB64: string;
    function GetImageURL: string;
    function GetMimeType: string;
    function GetImageStream: TStream;
  public
    destructor Destroy; override;

    [JSONName('mimeType')] property MimeType: string read GetMimeType write FMimeType;
    [JSONName('data')]     property Data: string read FData write FData;
    [JsonIgnore]           property ImageB64: string read GetImageB64;
    [JsonIgnore]           property ImageURL: string read GetImageURL;
    [JsonIgnore]           property ImageStream: TStream read GetImageStream;
  end;

  // Response from image generation API
  TAIGeminiGenerateImageResponse = class
  private
    FImages: TArray<IAIImageGenerationResult>;
  public
    [JSONName('images')] property Images: TArray<IAIImageGenerationResult> read FImages write FImages;
  end;

  TAIGeminiRole = (
    grUser,
    grModel,
    grFunction
  );

  TAIGeminiFinishReason = (
    frNone,
    frStop,
    frMaxTokens,
    frSafety,
    frRecitation,
    frOther
  );

  TAIGeminiSafetyRatingCategory = (
    scNone,
    scHarassment,
    scHateSpeech,
    scSexual,
    scDangerous,
    scSelfHarm,
    scViolence,
    scCivicIntegrity,
    scOther
  );

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiTextPart = class
  private
    FText: string;
  public
    constructor Create(const AText: string);
    [JSONName('text')] property Text: string read FText write FText;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionCall = class
  private
    FName: string;
    FArgs: TDictionary<string, Variant>;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('name')] property Name: string read FName write FName;
    [JSONName('args')] [JsonConverter(TAIStringVariantDictConverter)] property Args: TDictionary<string, Variant> read FArgs write FArgs;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionResponse = class
  private
    FName: string;
    FResponse: TDictionary<string, Variant>;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('name')] property Name: string read FName write FName;
    [JSONName('response')] [JsonConverter(TAIStringVariantDictConverter)] property Response: TDictionary<string, Variant> read FResponse write FResponse;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiPart = class
  private
    FText: string;
    FFunctionCall: TAIGeminiFunctionCall;
    FFunctionResponse: TAIGeminiFunctionResponse;
    FInlineData: TAIGeminiInlineData;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('text')]             property Text: string read FText write FText;
    [JSONName('functionCall')]     property FunctionCall: TAIGeminiFunctionCall read FFunctionCall write FFunctionCall;
    [JSONName('functionResponse')] property FunctionResponse: TAIGeminiFunctionResponse read FFunctionResponse write FFunctionResponse;
    [JSONName('inlineData')]       property InlineData: TAIGeminiInlineData read FInlineData write FInlineData;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiContent = class
  private
    FRole: TAIGeminiRole;
    FParts: TArray<TAIGeminiPart>;
    function GetRoleText: string;
    procedure SetRoleText(const S: string);
  public
    destructor Destroy; override;
    [JsonIgnore]        property Role: TAIGeminiRole read FRole write FRole;
    [JSONName('role')]  property RoleText: string read GetRoleText write SetRoleText;
    [JSONName('parts')] property Parts: TArray<TAIGeminiPart> read FParts write FParts;
  end;

  TAIGeminiSafetyRating = class
  private
    FCategory: TAIGeminiSafetyRatingCategory;
    FProbability: string;
    FBlocked: Boolean;
    function GetCategoryText: string;
    procedure SetCategoryText(const S: string);
  public
    [JSONName('category')]
    property CategoryText: string read GetCategoryText write SetCategoryText;
    [JSONName('probability')] property Probability: string read FProbability write FProbability;
    [JSONName('blocked')]     property Blocked: Boolean read FBlocked write FBlocked;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiPromptFeedback = class
  private
    FSafetyRatings: TArray<TAIGeminiSafetyRating>;
  public
    destructor Destroy; override;
    [JSONName('safetyRatings')] property SafetyRatings: TArray<TAIGeminiSafetyRating> read FSafetyRatings write FSafetyRatings;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiCandidate = class
  private
    FContent: TAIGeminiContent;
    FFinishReason: TAIGeminiFinishReason;
    FSafetyRatings: TArray<TAIGeminiSafetyRating>;
    function GetFinishReasonText: string;
    procedure SetFinishReasonText(const S: string);
  public
    destructor Destroy; override;

    [JSONName('content')]
    property Content: TAIGeminiContent read FContent write FContent;
    [JSONName('finishReason')]
    property FinishReasonText: string read GetFinishReasonText write SetFinishReasonText;
    [JSONName('safetyRatings')]
    property SafetyRatings: TArray<TAIGeminiSafetyRating> read FSafetyRatings write FSafetyRatings;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateContentRequest = class
  private
    FContents: TArray<TAIGeminiContent>;
  public
    [JSONName('contents')] property Contents: TArray<TAIGeminiContent> read FContents write FContents;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateContentResponse = class
  private
    FCandidates: TArray<TAIGeminiCandidate>;
    FPromptFeedback: TAIGeminiPromptFeedback;
  public
    destructor Destroy; override;
    [JSONName('candidates')]     property Candidates: TArray<TAIGeminiCandidate> read FCandidates write FCandidates;
    [JSONName('promptFeedback')] property PromptFeedback: TAIGeminiPromptFeedback read FPromptFeedback write FPromptFeedback;
  end;

  // Represents a document to be understood (inline or referenced by URL)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiDocumentInput = class
  private
    FData: string;
    FUrl: string;
    FMimeType: string;
  public
    [JSONName('data')]     property Data: string read FData write FData;// Base64 encoded document data (e.g., PDF)
    [JSONName('url')]      property Url: string read FUrl write FUrl;// Optional external URL to a hosted document
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;// MIME type (e.g., application/pdf)
  end;

  // Request to process a document with a prompt
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandDocumentRequest = class
  private
    FDocument: TAIGeminiDocumentInput;
    FPrompt: string;
  public
    [JSONName('document')] property Document: TAIGeminiDocumentInput read FDocument write FDocument;
    [JSONName('prompt')]   property Prompt: string read FPrompt write FPrompt;
  end;

  // Response with extracted or reasoned content
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandDocumentResponse = class
  private
    FText: string;
  public
    [JSONName('text')] property Text: string read FText write FText;
  end;

  // Describes a function parameter's type and schema
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionParamSchema = class
  private
    FType: string;
    FDescription: string;
  public
    [JSONName('type')] property &Type: string read FType write FType;
    [JSONName('description')] property Description: string read FDescription write FDescription;
  end;

  // Function parameters (dictionary of schema fields)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionParameters = class
  private
    FType: string;
    FProperties: TDictionary<string, TAIGeminiFunctionParamSchema>;
    FRequired: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('type')] property &Type: string read FType write FType;
    [JSONName('properties')] [JsonConverter(TAIGeminiParamSchemaDictConverter)] property Properties: TDictionary<string, TAIGeminiFunctionParamSchema> read FProperties write FProperties;
    [JSONName('required')] property Required: TArray<string> read FRequired write FRequired;
  end;

  // Declares one callable function
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionDeclaration = class
  private
    FName: string;
    FDescription: string;
    FParameters: TAIGeminiFunctionParameters;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('name')]        property Name: string read FName write FName;
    [JSONName('description')] property Description: string read FDescription write FDescription;
    [JSONName('parameters')]  property Parameters: TAIGeminiFunctionParameters read FParameters write FParameters;
  end;

  // Full tool config for function calling
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiFunctionTool = class
  private
    FFunctionDeclarations: TArray<TAIGeminiFunctionDeclaration>;
  public
    [JSONName('functionDeclarations')]
    property FunctionDeclarations: TArray<TAIGeminiFunctionDeclaration> read FFunctionDeclarations write FFunctionDeclarations;
  end;

  // Request to generate music using prompt
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateMusicRequest = class
  private
    FPrompt: string;
    FGenre: string;
    FMood: string;
    FDurationSeconds: Integer;
  public
    [JSONName('prompt')]          property Prompt: string read FPrompt write FPrompt;
    [JSONName('genre')]           property Genre: string read FGenre write FGenre;
    [JSONName('mood')]            property Mood: string read FMood write FMood;
    [JSONName('durationSeconds')] property DurationSeconds: Integer read FDurationSeconds write FDurationSeconds;
  end;

  // Generated music track
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGeneratedMusic = class
  private
    FData: string;
    FMimeType: string;
  public
    [JSONName('data')]     property Data: string read FData write FData;
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;
  end;

  // Music generation response
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateMusicResponse = class
  private
    FMusic: TAIGeminiGeneratedMusic;
  public
    [JSONName('music')] property Music: TAIGeminiGeneratedMusic read FMusic write FMusic;
  end;

  // Defines a schema field for structured output
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiSchemaField = class
  private
    FName: string;
    FType: string;
    FDescription: string;
    FRequired: Boolean;
  public
    [JSONName('name')]        property Name: string read FName write FName;
    [JSONName('type')]        property &Type: string read FType write FType;
    [JSONName('description')] property Description: string read FDescription write FDescription;
    [JSONName('required')]    property Required: Boolean read FRequired write FRequired;
  end;

  // Top-level schema definition
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiStructuredSchema = class
  private
    FTitle: string;
    FType: string;
    FProperties: TObjectList<TAIGeminiSchemaField>;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('title')] property Title: string read FTitle write FTitle;
    [JSONName('type')]  property &Type: string read FType write FType;

    [JSONName('properties')]
    [JsonConverter(TAIGeminiSchemaFieldListConverter)]
    property Properties: TObjectList<TAIGeminiSchemaField> read FProperties write FProperties;
  end;

  // Structured output configuration in request
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiStructuredOutputConfig = class
  private
    FSchema: TAIGeminiStructuredSchema;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('schema')] property Schema: TAIGeminiStructuredSchema read FSchema write FSchema;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiContextualUrl = class
  private
    FUrl: string;
    FDescription: string;
  public
    [JSONName('url')]         property Url: string read FUrl write FUrl;// Required URL to crawl/index
    [JSONName('description')] property Description: string read FDescription write FDescription;// Optional description or hint for grounding
  end;

  // Used in requests that want to provide URL-based grounding
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiURLContext = class
  private
    FUrls: TArray<TAIGeminiContextualUrl>;
  public
    [JSONName('urlContexts')] property Urls: TArray<TAIGeminiContextualUrl> read FUrls write FUrls;
  end;

  // For uploading or referencing a video (URL or inline)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiVideoSource = class
  private
    FUrl: string;
    FMimeType: string;
    FData: string;
  public
    [JSONName('url')]      property Url: string read FUrl write FUrl;// For referencing a video hosted externally
    [JSONName('data')]     property Data: string read FData write FData;// For base64 inline video data
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;// Mime type: video/mp4, video/webm, etc.
  end;

  // Video generation prompt (for Veo)
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateVideoRequest = class
  private
    FPrompt: string;
  public
    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
  end;

  // Generated video content
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGeneratedVideo = class
  private
    FData: string;
    FMimeType: string;
  public
    [JSONName('data')]     property Data: string read FData write FData;
    [JSONName('mimeType')] property MimeType: string read FMimeType write FMimeType;
  end;

  // Response from Veo video generation
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiGenerateVideoResponse = class
  private
    FVideo: TAIGeminiGeneratedVideo;
  public
    [JSONName('video')] property Video: TAIGeminiGeneratedVideo read FVideo write FVideo;
  end;

  // Request to understand a video
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandVideoRequest = class
  private
    FVideo: TAIGeminiVideoSource;
    FPrompt: string;
  public
    [JSONName('video')]  property Video: TAIGeminiVideoSource read FVideo write FVideo;
    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
  end;

  // Response from video understanding
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIGeminiUnderstandVideoResponse = class
  private
    FText: string;
  public
    [JSONName('text')] property Text: string read FText write FText;
  end;

implementation

uses
  System.Net.HttpClient, SmartCoreAI.Exceptions;

{ TAIGeminiTextPart }

constructor TAIGeminiTextPart.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
end;

{ TAIGeminiFunctionCall }

constructor TAIGeminiFunctionCall.Create;
begin
  inherited Create;
  FArgs := TDictionary<string, Variant>.Create;
end;

destructor TAIGeminiFunctionCall.Destroy;
begin
  FArgs.Free;
  inherited;
end;

{ TAIGeminiFunctionResponse }

constructor TAIGeminiFunctionResponse.Create;
begin
  inherited Create;
  FResponse := TDictionary<string, Variant>.Create;
end;

destructor TAIGeminiFunctionResponse.Destroy;
begin
  FResponse.Free;
  inherited;
end;

{ TAIGeminiPart }

constructor TAIGeminiPart.Create;
begin
  inherited Create;
  FFunctionCall := nil;
  FFunctionResponse := nil;
  FInlineData := nil;
end;

destructor TAIGeminiPart.Destroy;
begin
  FFunctionCall.Free;
  FFunctionResponse.Free;
  FInlineData.Free;
  inherited;
end;

{ TAIGeminiFunctionParameters }

constructor TAIGeminiFunctionParameters.Create;
begin
  inherited Create;
  FProperties := TDictionary<string, TAIGeminiFunctionParamSchema>.Create;
end;

destructor TAIGeminiFunctionParameters.Destroy;
var
  Pair: TPair<string, TAIGeminiFunctionParamSchema>;
begin
  for Pair in FProperties do
    Pair.Value.Free;
  FProperties.Free;
  inherited;
end;

{ TAIGeminiFunctionDeclaration }

constructor TAIGeminiFunctionDeclaration.Create;
begin
  inherited Create;
  FParameters := TAIGeminiFunctionParameters.Create;
end;

destructor TAIGeminiFunctionDeclaration.Destroy;
begin
  FParameters.Free;
  inherited;
end;

{ TAIGeminiImagePart }

constructor TAIGeminiImagePart.Create;
begin
  inherited Create;
  FInlineData := TAIGeminiInlineData.Create;
end;

destructor TAIGeminiImagePart.Destroy;
begin
  FInlineData.Free;
  inherited;
end;

{ TAIGeminiGenerateImageRequest }

procedure TAIGeminiGenerateImageRequest.AddImageBase64(const AMimeType, ABase64: string);
var
  B: TAIGeminiInlineData;
begin
  B := TAIGeminiInlineData.Create;
  B.MimeType := AMimeType;
  B.Data := ABase64;
  FImages.Add(B);
end;

procedure TAIGeminiGenerateImageRequest.AddImageFromStream(AStream: TStream; const AMimeType: string);
var
  Bytes: TBytes;
  Base64: string;
  LPos: Int64;
begin
  if not Assigned(AStream) then Exit;

  LPos := 0;
  try
    try
      LPos := AStream.Position;
    except
      //Ignore if not seekable.
    end;

    SetLength(Bytes, AStream.Size);
    AStream.Position := 0;
    if Length(Bytes) > 0 then
      AStream.ReadBuffer(Bytes[0], Length(Bytes));
  finally
    try
      if LPos <> 0 then
        AStream.Position := LPos;
    except
      //Ignore if not seekable.
    end;
  end;

  Base64 := TNetEncoding.Base64.EncodeBytesToString(Bytes); // no wraps
  AddImageBase64(AMimeType, Base64);
end;

function TAIGeminiGenerateImageRequest.BuildGenerateContentJSON: string;
var
  Root, ContentObj, PartObj, InlineObj: TJSONObject;
  ContentsArr, PartsArr: TJSONArray;
  Img: TAIGeminiInlineData;
begin
  Root := TJSONObject.Create;
  ContentsArr := TJSONArray.Create;
  ContentObj := TJSONObject.Create;
  PartsArr := TJSONArray.Create;
  PartObj := TJSONObject.Create;

  try
    Root.AddPair('contents', ContentsArr);
    ContentsArr.AddElement(ContentObj);
    ContentObj.AddPair('parts', PartsArr);

    // First part: the prompt text
    PartObj.AddPair('text', FPrompt);
    PartsArr.AddElement(PartObj);

    // Additional parts: inline_data for each image (if any)
    for Img in FImages do
    begin
      PartObj := TJSONObject.Create;
      InlineObj := TJSONObject.Create;
      InlineObj.AddPair('mime_type', Img.MimeType);
      InlineObj.AddPair('data', Img.Data); // base64 string
      PartObj.AddPair('inline_data', InlineObj);
      PartsArr.AddElement(PartObj);
    end;

    Result := Root.ToJSON;
  finally
    FreeAndNil(Root);
  end;
end;

constructor TAIGeminiGenerateImageRequest.Create;
begin
  inherited Create;
  FImages := TObjectList<TAIGeminiInlineData>.Create(True);
end;

destructor TAIGeminiGenerateImageRequest.Destroy;
begin
  FImages.Free;
  inherited;
end;

function TAIGeminiGenerateImageRequest.GetPrompt: string;
begin
  Result := FPrompt;
end;

procedure TAIGeminiGenerateImageRequest.SetPrompt(const AValue: string);
begin
  FPrompt := AValue;
end;

{ TAIGeminiImageGenerationResult }

destructor TAIGeminiImageGenerationResult.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TAIGeminiImageGenerationResult.GetImageB64: string;
begin
  Result := FData;
end;

function TAIGeminiImageGenerationResult.GetImageStream: TStream;
begin
  if (FStream = nil) and (FData <> '') then
  begin
    FStream := TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes(FData));
    // Optional: set FMimeType by sniffing the first bytes if empty
  end;
  Result := FStream;
end;

function TAIGeminiImageGenerationResult.GetImageURL: string;
begin
  Result := cGemini_Msg_Not_Supported;
end;

function TAIGeminiImageGenerationResult.GetMimeType: string;
begin
  Result := FMimeType;
end;

{ TAIGeminiStructuredSchema }

constructor TAIGeminiStructuredSchema.Create;
begin
  inherited Create;
  FProperties := TObjectList<TAIGeminiSchemaField>.Create(True);
end;

destructor TAIGeminiStructuredSchema.Destroy;
begin
  FProperties.Free;
  inherited;
end;

{ TAIGeminiStructuredOutputConfig }

constructor TAIGeminiStructuredOutputConfig.Create;
begin
  inherited Create;
  FSchema := TAIGeminiStructuredSchema.Create;
end;

destructor TAIGeminiStructuredOutputConfig.Destroy;
begin
  FSchema.Free;
  inherited;
end;

{ TAIGeminiContent }

destructor TAIGeminiContent.Destroy;
begin
  for var LP in FParts do
    LP.Free;

  inherited;
end;

function TAIGeminiContent.GetRoleText: string;
begin
  case FRole of
    grUser:     Result := 'user';
    grModel:    Result := 'model';
    grFunction: Result := 'function';
  end;
end;

procedure TAIGeminiContent.SetRoleText(const S: string);
begin
  if SameText(S, 'model') then
    FRole := grModel
  else if SameText(S, 'function') then
    FRole := grFunction
  else FRole := grUser;
end;

{ TAIGeminiImagenPredictParameters }

constructor TAIGeminiImagenPredictParameters.Create;
begin
  inherited Create;
  FSampleCount := 1;      // sensible defaults
  FAspectRatio := '';     // leave empty, let API choose
  FSampleImageSize := ''; // leave empty unless user sets
  FPersonGeneration := 'allow_adult'; // safe default; note EEA restrictions in docs
end;

{ TAIGeminiImagenPredictRequest }

function TAIGeminiImagenPredictRequest.BuildJSON: string;
var
  Root, Params: TJSONObject;
  Arr: TJSONArray;
  Inst: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    // instances
    Arr := TJSONArray.Create;
    Root.AddPair('instances', Arr);
    Inst := TJSONObject.Create;
    Inst.AddPair('prompt', FInstances[0].Prompt);
    Arr.AddElement(Inst);

    // parameters (only add set values)
    Params := TJSONObject.Create;
    if FParameters.SampleCount > 0 then
      Params.AddPair('sampleCount', TJSONNumber.Create(FParameters.SampleCount));
    if FParameters.AspectRatio <> '' then
      Params.AddPair('aspectRatio', FParameters.AspectRatio);
    if FParameters.SampleImageSize <> '' then
      Params.AddPair('sampleImageSize', FParameters.SampleImageSize);
    if FParameters.PersonGeneration <> '' then
      Params.AddPair('personGeneration', FParameters.PersonGeneration);
    Root.AddPair('parameters', Params);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

constructor TAIGeminiImagenPredictRequest.Create;
begin
  inherited Create;
  FInstances := TObjectList<TAIGeminiImagenPredictInstance>.Create(True);
  FParameters := TAIGeminiImagenPredictParameters.Create;
end;

destructor TAIGeminiImagenPredictRequest.Destroy;
begin
  FInstances.Free;
  FParameters.Free;
  inherited;
end;

procedure TAIGeminiImagenPredictRequest.SetPrompt(const AValue: string);
var
  I: TAIGeminiImagenPredictInstance;
begin
  FInstances.Clear;
  I := TAIGeminiImagenPredictInstance.Create;
  I.Prompt := AValue;
  FInstances.Add(I);
end;

{ TAIGeminiCandidate }

function FinishReasonToString(const V: TAIGeminiFinishReason): string;
begin
  case V of
    frStop:        Result := 'STOP';
    frMaxTokens:   Result := 'MAX_TOKENS';
    frSafety:      Result := 'SAFETY';
    frRecitation:  Result := 'RECITATION';
    frOther:       Result := 'OTHER';
  else
    Result := ''; // frNone or unknown
  end;
end;

function StringToFinishReason(const S: string): TAIGeminiFinishReason;
var
  U: string;
begin
  U := UpperCase(S);
  if U = 'STOP'          then Exit(frStop);
  if U = 'MAX_TOKENS'    then Exit(frMaxTokens);
  if U = 'SAFETY'        then Exit(frSafety);
  if U = 'RECITATION'    then Exit(frRecitation);
  if U = 'OTHER'         then Exit(frOther);
  if U = ''              then Exit(frNone);
  Result := frOther; // graceful fallback for future values
end;

destructor TAIGeminiCandidate.Destroy;
begin
  for var LRating in FSafetyRatings do
    LRating.Free;

  FSafetyRatings := nil;

  FContent.Free;
  FContent := nil;
  inherited;
end;

function TAIGeminiCandidate.GetFinishReasonText: string;
begin
  Result := FinishReasonToString(FFinishReason);
end;

procedure TAIGeminiCandidate.SetFinishReasonText(const S: string);
begin
  FFinishReason := StringToFinishReason(S);
end;

{ TAIGeminiSafetyRating }

function SafetyCategoryToString(const V: TAIGeminiSafetyRatingCategory): string;
begin
  case V of
    scHarassment:     Exit('HARM_CATEGORY_HARASSMENT');
    scHateSpeech:     Exit('HARM_CATEGORY_HATE_SPEECH');
    scSexual:         Exit('HARM_CATEGORY_SEXUAL');
    scDangerous:      Exit('HARM_CATEGORY_DANGEROUS');
    scSelfHarm:       Exit('HARM_CATEGORY_SELF_HARM');        // if you use this
    scViolence:       Exit('HARM_CATEGORY_VIOLENCE');          // if present
    scCivicIntegrity: Exit('HARM_CATEGORY_CIVIC_INTEGRITY');   // if present
    scOther:          Exit('OTHER');
  else
    Result := ''; // scNone
  end;
end;

function StringToSafetyCategory(const S: string): TAIGeminiSafetyRatingCategory;
var U: string;
begin
  U := UpperCase(S);
  if U = 'HARM_CATEGORY_HARASSMENT'      then Exit(scHarassment);
  if U = 'HARM_CATEGORY_HATE_SPEECH'     then Exit(scHateSpeech);
  if U = 'HARM_CATEGORY_SEXUAL'          then Exit(scSexual);
  if U = 'HARM_CATEGORY_DANGEROUS'       then Exit(scDangerous);
  if U = 'HARM_CATEGORY_SELF_HARM'       then Exit(scSelfHarm);       // optional
  if U = 'HARM_CATEGORY_VIOLENCE'        then Exit(scViolence);       // optional
  if U = 'HARM_CATEGORY_CIVIC_INTEGRITY' then Exit(scCivicIntegrity); // optional
  if U = ''                              then Exit(scNone);
  Result := scOther; // forward-compatible fallback
end;

function TAIGeminiSafetyRating.GetCategoryText: string;
begin
  Result := SafetyCategoryToString(FCategory);
end;

procedure TAIGeminiSafetyRating.SetCategoryText(const S: string);
begin
  FCategory := StringToSafetyCategory(S);
end;

{ TAIGeminiGenerateContentResponse }

destructor TAIGeminiGenerateContentResponse.Destroy;
begin
  for var LIC in FCandidates do
    LIC.Free;

  FPromptFeedback.Free;
  inherited;
end;

{ TAIGeminiPromptFeedback }

destructor TAIGeminiPromptFeedback.Destroy;
begin
  for var LSR in FSafetyRatings do
    LSR.Free;
  inherited;
end;

end.
