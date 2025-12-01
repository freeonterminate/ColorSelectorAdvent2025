{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.OpenAI.Models;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Rtti,
  System.NetEncoding, System.JSON.Converters, System.JSON.Writers, System.JSON.Readers,
  System.JSON.Serializers, System.TypInfo, System.StrUtils, System.JSON.Types,
  SmartCoreAI.Exceptions, SmartCoreAI.Types, SmartCoreAI.Consts, SmartCoreAI.HttpClientConfig;

type
  {$REGION 'Audio'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAITextToSpeechRequest = class
  private
    FModel: string;
    FInput: string;
    FVoice: string;
    FResponseFormat: string;
    FSpeed: Double;
  public
    constructor Create;

    [JSONName('model')]
    property Model: string read FModel write FModel;
    [JSONName('input')]
    property Input: string read FInput write FInput;
    [JSONName('voice')]
    property Voice: string read FVoice write FVoice;
    [JSONName('response_format')]
    property ResponseFormat: string read FResponseFormat write FResponseFormat;
    [JSONName('speed')]
    property Speed: Double read FSpeed write FSpeed;
  end;
  {$ENDREGION}

  {$REGION 'Transcription'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAITranscriptionRequest = class
  private
    FModel: string;
    FPrompt: string;
    FResponseFormat: string;
    FTemperature: Double;
    FLanguage: string;
  public
    constructor Create;

    [JSONName('model')]
    property Model: string read FModel write FModel;
    [JSONName('prompt')]
    property Prompt: string read FPrompt write FPrompt;
    [JSONName('response_format')]
    property ResponseFormat: string read FResponseFormat write FResponseFormat;
    [JSONName('temperature')]
    property Temperature: Double read FTemperature write FTemperature;
    [JSONName('language')]
    property Language: string read FLanguage write FLanguage;
  end;

  {$ENDREGION}

  {$REGION 'Translation'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAITranslationRequest = class
  private
    FModel: string;
    FPrompt: string;
    FResponseFormat: string;
    FTemperature: Double;
  public
    constructor Create;

    [JSONName('model')]
    property Model: string read FModel write FModel;
    [JSONName('prompt')]
    property Prompt: string read FPrompt write FPrompt;
    [JSONName('response_format')]
    property ResponseFormat: string read FResponseFormat write FResponseFormat;
    [JSONName('temperature')]
    property Temperature: Double read FTemperature write FTemperature;
  end;
  {$ENDREGION}

  {$REGION 'Chat'}
  TAIChatMessageRole = (cmrSystem, cmrUser, cmrAssistant, cmrFunction, cmrTool);
  TOpenAIResponseFormatKind = (rfText, rfJSONObject);

  [JsonSerialize(TJsonMemberSerialization.Fields)]
  TOpenAIResponseFormat = class
  private
    [JSONName('type')]
    FTypeText: string; // 'text' | 'json_object'
  public
    constructor Create(AKind: TOpenAIResponseFormatKind); reintroduce;
    class function Text: TOpenAIResponseFormat; static;
    class function JSONObject: TOpenAIResponseFormat; static;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIChatMessage = class
  private
    FRole: TAIChatMessageRole;
    FContent: string;

    function GetRoleText: string;
    procedure SetRoleText(const Value: string);
  public
    constructor Create(ARole: TAIChatMessageRole; const AContent: string);

    [JsonIgnore]
    property Role: TAIChatMessageRole read FRole write FRole;

    [JSONName('role')] // Expose the JSON-facing view:
    property RoleText: string read GetRoleText write SetRoleText;

    [JSONName('content')]
    property Content: string read FContent write FContent;
  end;

  TAIChatMessages = TObjectList<TAIChatMessage>;
  TAIChatMessageListConverter = class(TJsonListConverter<TAIChatMessage>);
  TAILogitBiasConverter = class(TJsonStringDictionaryConverter<Double>);
  TAIStringDictConverter = class(TJsonStringDictionaryConverter<string>);

  TAIOptionalStringDictConverter = class(TJsonConverter)
  public
    function CanConvert(ATypeInf: PTypeInfo): Boolean; override;
    function ReadJson(const AReader: TJsonReader; ATypeInf: PTypeInfo;
      const AExistingValue: TValue; const ASerializer: TJsonSerializer): TValue; override;
    procedure WriteJson(const AWriter: TJsonWriter; const AValue: TValue;
      const ASerializer: TJsonSerializer); override;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOpenAIChatRequest = class
  private
    FModel: string;
    FMessages: TAIChatMessages;
    FTemperature: Double;
    FTopP: Double;
    FN: Integer;
    FStream: Boolean;
    FStop: string;
    FMaxTokens: Integer;
    FPresencePenalty: Double;
    FFrequencyPenalty: Double;
    FLogitBias: TDictionary<string, Double>;
    FUser: string;
    FStore: Boolean;
    FResponseFormat: TOpenAIResponseFormat;
    FVerbosity: string;
    FReasoningEffort: string;
    FTextOptions: TDictionary<string, string>;
    FReasoningOptions: TDictionary<string, string>;

    // helpers to keep the nested objects in sync with the strings
    procedure SetVerbosity(const Value: string);
    procedure SetReasoningEffort(const Value: string);
    function SupportsGPT5Knobs: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('model')] property Model: string read FModel write FModel;
    [JSONName('messages')] [JsonConverter(TAIChatMessageListConverter)] property Messages: TObjectList<TAIChatMessage> read FMessages write FMessages;
    [JSONName('temperature')] property Temperature: Double read FTemperature write FTemperature;
    [JSONName('top_p')] property TopP: Double read FTopP write FTopP;
    [JSONName('n')] property N: Integer read FN write FN;
    [JSONName('stream')] property Stream: Boolean read FStream write FStream;
    [JSONName('stop')] property Stop: string read FStop write FStop;
    [JSONName('max_tokens')] property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    [JSONName('presence_penalty')] property PresencePenalty: Double read FPresencePenalty write FPresencePenalty;
    [JSONName('frequency_penalty')] property FrequencyPenalty: Double read FFrequencyPenalty write FFrequencyPenalty;
    [JSONName('logit_bias')] [JsonConverter(TAILogitBiasConverter)] property LogitBias: TDictionary<string, Double> read FLogitBias write FLogitBias;
    [JSONName('user')] property User: string read FUser write FUser;
    [JsonIgnore] property Store: Boolean read FStore write FStore;
    [JSONName('response_format')] property ResponseFormat: TOpenAIResponseFormat read FResponseFormat write FResponseFormat;
    [JsonIgnore] property Verbosity: string read FVerbosity write SetVerbosity;
    [JsonIgnore] property ReasoningEffort: string read FReasoningEffort write SetReasoningEffort;
    [JsonIgnore] [JsonConverter(TAIOptionalStringDictConverter)] property TextOptions: TDictionary<string, string> read FTextOptions write FTextOptions;
    [JsonIgnore] [JsonConverter(TAIOptionalStringDictConverter)] property ReasoningOptions: TDictionary<string, string> read FReasoningOptions write FReasoningOptions;
  end;

  {$ENDREGION}

  {$REGION 'Files'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIFileInfo = class
  private
    FID: string;
    FObjectType: string;
    FFileName: string;
    FPurpose: string;
    FBytes: Integer;
  public
    [JSONName('id')] property ID: string read FID write FID;
    [JSONName('object')] property ObjectType: string read FObjectType write FObjectType;
    [JSONName('filename')] property FileName: string read FFileName write FFileName;
    [JSONName('purpose')] property Purpose: string read FPurpose write FPurpose;
    [JSONName('bytes')] property Bytes: Integer read FBytes write FBytes;
  end;
  {$ENDREGION}

  {$REGION 'FineTuning'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIFileReference = class
  private
    FFileID: string;
  public
    [JSONName('file_id')] property FileID: string read FFileID write FFileID;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIStartFineTuneRequest = class
  private
    FTrainingFile: string;
    FValidationFile: string;
    FModel: string;
    FSuffix: string;
    FHyper: TDictionary<string, string>;
    FIntegrations: TArray<string>; // reserved
    FNEpochs: Integer;
    FBatchSize: Integer;
    FLearningRateMultiplier: Double;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('training_file')] property TrainingFile: string read FTrainingFile write FTrainingFile;
    [JSONName('validation_file')] property ValidationFile: string read FValidationFile write FValidationFile;
    [JSONName('model')] property Model: string read FModel write FModel;
    [JSONName('suffix')] property Suffix: string read FSuffix write FSuffix;
    [JSONName('n_epochs')] property NEpochs: Integer read FNEpochs write FNEpochs;
    [JSONName('batch_size')] property BatchSize: Integer read FBatchSize write FBatchSize;
    [JSONName('learning_rate_multiplier')] property LearningRateMultiplier: Double read FLearningRateMultiplier write FLearningRateMultiplier;
    [JSONName('hyperparameters')] [JsonConverter(TAIStringDictConverter)] property Hyperparameters: TDictionary<string, string> read FHyper write FHyper;
    [JSONName('integrations')] property Integrations: TArray<string> read FIntegrations write FIntegrations;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIStartFineTuneResponse = class
  private
    FID: string;
    FStatus: string;
    FModel: string;
  public
    [JSONName('id')] property ID: string read FID write FID;
    [JSONName('status')] property Status: string read FStatus write FStatus;
    [JSONName('model')] property Model: string read FModel write FModel;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIFineTuneJobSummary = class
  public
    [JSONName('id')] ID: string;
    [JSONName('model')] Model: string;
    [JSONName('status')] Status: string;
    [JSONName('created_at')] CreatedAt: Int64;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIFineTuneEvent = class
  public
    [JSONName('created_at')] CreatedAt: Int64;
    [JSONName('level')] Level: string;
    [JSONName('message')] Message: string;
  end;
  {$ENDREGION}

  {$REGION 'Images'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIOpenAIImageGenerationRequest = class(TInterfacedObject, IAIImageGenerationRequest)
  private
    FPrompt: string;
    FModel: string;
    FN: Integer;
    FSize: string;
    FResponseFormat: string;
    FStyle: string;
    FQuality: string;
    FUser: string;
    function GetPrompt: string;
    procedure SetPrompt(const AValue: string);
  public
    constructor Create;

    [JSONName('prompt')] property Prompt: string read FPrompt write FPrompt;
    [JSONName('model')] property Model: string read FModel write FModel;
    [JSONName('n')] property N: Integer read FN write FN;
    [JSONName('size')] property Size: string read FSize write FSize;
    [JSONName('output_format')] [JsonIgnore] property ResponseFormat: string read FResponseFormat write FResponseFormat;
    [JsonIgnore] property Style: string read FStyle write FStyle;
    [JSONName('quality')] property Quality: string read FQuality write FQuality;
    [JSONName('user')] property User: string read FUser write FUser;
    [JsonIgnore] property RefCount;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIImageGenerationResult = class(TInterfacedObject, IAIImageGenerationResult)
  private
    FURL: string;
    FB64: string;
    FStream: TStream;
    FMimeType: string;

    //IAIImageGenerationResult
    function GetImageB64: string;
    function GetImageURL: string;
    function GetMimeType: string;
    function GetImageStream: TStream;
  public
    destructor Destroy; override;

    [JsonIgnore] property ImageB64: string read GetImageB64;
    [JsonIgnore] property ImageURL: string read GetImageURL;
    [JSONName('url')] property URL: string read FURL write FURL;
    [JSONName('b64_json')] property B64: string read FB64 write FB64;
    [JsonIgnore] property MimeType: string read GetMimeType;
    [JsonIgnore] property ImageStream: TStream read GetImageStream;
  end;
  {$ENDREGION}

  {$REGION 'Moderation'}
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIModerationRequest = class
  private
    FInput: string;
    FModel: string; // "text-moderation-latest" or "text-moderation-stable"
  public
    constructor Create;
    [JSONName('input')] property Input: string read FInput write FInput;
    [JSONName('model')] property Model: string read FModel write FModel;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIModerationCategoryScores = class
  public
    [JSONName('hate')] Hate: Double;
    [JSONName('hate/threatening')] HateThreatening: Double;
    [JSONName('self-harm')] SelfHarm: Double;
    [JSONName('sexual')] Sexual: Double;
    [JSONName('sexual/minors')] SexualMinors: Double;
    [JSONName('violence')] Violence: Double;
    [JSONName('violence/graphic')] ViolenceGraphic: Double;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIModerationCategories = class
  public
    [JSONName('hate')] Hate: Boolean;
    [JSONName('hate/threatening')] HateThreatening: Boolean;
    [JSONName('self-harm')] SelfHarm: Boolean;
    [JSONName('sexual')] Sexual: Boolean;
    [JSONName('sexual/minors')] SexualMinors: Boolean;
    [JSONName('violence')] Violence: Boolean;
    [JSONName('violence/graphic')] ViolenceGraphic: Boolean;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TAIModerationResult = class
  public
    [JSONName('flagged')] Flagged: Boolean;
    [JSONName('categories')] Categories: TAIModerationCategories;
    [JSONName('category_scores')] CategoryScores: TAIModerationCategoryScores;
  end;
  {$ENDREGION}

implementation

uses
  System.Net.HttpClient;

{$REGION 'Audio'}
{ TAITextToSpeechRequest }

constructor TAITextToSpeechRequest.Create;
begin
  FModel := 'tts-1'; // or tts-1-hd
  FVoice := 'nova'; // or alloy, echo, fable, onyx, shimmer
  FResponseFormat := 'mp3';
  FSpeed := 1.0;
end;
{$ENDREGION}

{$REGION 'Transcription'}
constructor TAITranscriptionRequest.Create;
begin
  FModel := 'whisper-1';
  FResponseFormat := 'json'; // or 'text', 'verbose_json', 'srt', 'vtt'
  FTemperature := 0.0;
end;
{$ENDREGION}

{$REGION 'Translation'}
constructor TAITranslationRequest.Create;
begin
  FModel := 'whisper-1';
  FResponseFormat := 'json'; // or 'text', 'verbose_json', 'srt', 'vtt'
  FTemperature := 0.0;
end;
{$ENDREGION}

{$REGION 'Chat'}
{ TAIChatMessage }

constructor TAIChatMessage.Create(ARole: TAIChatMessageRole; const AContent: string);
begin
  inherited Create;
  FRole := ARole;
  FContent := AContent;
end;

function TAIChatMessage.GetRoleText: string;
begin
  case FRole of
    cmrSystem:    Result := 'system';
    cmrUser:      Result := 'user';
    cmrAssistant: Result := 'assistant';
    cmrFunction:  Result := 'function';
    cmrTool:      Result := 'tool';
  else
    Result := 'user';
  end;
end;

procedure TAIChatMessage.SetRoleText(const Value: string);
var
  S: string;
begin
  S := Value.ToLower;
  if      S = 'system'    then FRole := cmrSystem
  else if S = 'user'      then FRole := cmrUser
  else if S = 'assistant' then FRole := cmrAssistant
  else if S = 'function'  then FRole := cmrFunction
  else if S = 'tool'      then FRole := cmrTool
  else
    raise EAIValidationException.CreateFmt(cOpenAI_Msg_InvalidRole, [Value]);
end;

{ TOpenAIChatRequest }

constructor TOpenAIChatRequest.Create;
begin
  FMessages := TObjectList<TAIChatMessage>.Create(True);
  FLogitBias := TDictionary<string, Double>.Create;
  FModel := 'gpt-4';
  FTemperature := 1.0;
  FTopP := 1.0;
  FN := 1;
  FStream := False;
  FStop := '';
  FMaxTokens := 1024;
  FPresencePenalty := 1;
  FFrequencyPenalty := 1;
  FResponseFormat := TOpenAIResponseFormat.Text;  // default to {"type":"text"}
end;

destructor TOpenAIChatRequest.Destroy;
begin
  FTextOptions.Free;
  FReasoningOptions.Free;
  FMessages.Free;
  FLogitBias.Free;
  FResponseFormat.Free;
  inherited;
end;

procedure TOpenAIChatRequest.SetReasoningEffort(const Value: string);
var
  LVal: string;
begin
  FReasoningEffort := Value;

  if (FReasoningEffort.Trim = '') or (not SupportsGPT5Knobs) then
  begin
    FreeAndNil(FReasoningOptions);
    Exit;
  end;

  if FReasoningOptions = nil then
    FReasoningOptions := TDictionary<string, string>.Create
  else
    FReasoningOptions.Clear;

  LVal := FReasoningEffort.Trim.ToLower;
  if not MatchText(LVal, cOpenAI_ReasoningEfforts) then
    raise EAIValidationException.CreateFmt(cOpenAI_Msg_InvalidReasoningEffort, [FReasoningEffort]);

  FReasoningOptions.Add('effort', LVal);
end;

procedure TOpenAIChatRequest.SetVerbosity(const Value: string);
var
  LVal: string;
begin
  FVerbosity := Value;

  if (FVerbosity.Trim = '') or (not SupportsGPT5Knobs) then
  begin
    FreeAndNil(FTextOptions);
    Exit;
  end;

  if FTextOptions = nil then
    FTextOptions := TDictionary<string, string>.Create
  else
    FTextOptions.Clear;


  LVal := FVerbosity.Trim.ToLower; // OpenAI expects lower-case tokens
  if not MatchText(LVal, cOpenAI_Verbosities) then
    raise EAIValidationException.CreateFmt(cOpenAI_Msg_InvalidVerbosity, [FVerbosity]);

  FTextOptions.Add('verbosity', LVal);
end;

function TOpenAIChatRequest.SupportsGPT5Knobs: Boolean;
begin
  Result := FModel.ToLower.StartsWith('gpt-5'); // adjust if we later allow o*-reasoning via Responses
end;

{ TOpenAIResponseFormat }

constructor TOpenAIResponseFormat.Create(AKind: TOpenAIResponseFormatKind);
begin
  inherited Create;
  case AKind of
    rfText:       FTypeText := 'text';
    rfJSONObject: FTypeText := 'json_object';
  end;
end;

class function TOpenAIResponseFormat.JSONObject: TOpenAIResponseFormat;
begin
  Result := TOpenAIResponseFormat.Create(rfJSONObject);
end;

class function TOpenAIResponseFormat.Text: TOpenAIResponseFormat;
begin
  Result := TOpenAIResponseFormat.Create(rfText);
end;
{$ENDREGION}

{$REGION 'FineTuning'}
{ TAIStartFineTuneRequest }

constructor TAIStartFineTuneRequest.Create;
begin
  FModel := 'gpt-3.5-turbo';
  FHyper := TDictionary<string, string>.Create;
end;

destructor TAIStartFineTuneRequest.Destroy;
begin
  FHyper.Free;
  inherited;
end;
{$ENDREGION}

{$REGION 'Images'}
{ TAIOpenAIImageGenerationRequest }

constructor TAIOpenAIImageGenerationRequest.Create;
begin
  FModel := 'dall-e-3';
  FN := 1;
  FSize := '1024x1024';
  FResponseFormat := 'url';
  FQuality := 'standard';
  FStyle := 'vivid';
end;

function TAIOpenAIImageGenerationRequest.GetPrompt: string;
begin
  Result := FPrompt;
end;

procedure TAIOpenAIImageGenerationRequest.SetPrompt(const AValue: string);
begin
  FPrompt := AValue;
end;

{ TAIImageGenerationResult }

destructor TAIImageGenerationResult.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TAIImageGenerationResult.GetImageB64: string;
begin
  Result := FB64;
end;

function TAIImageGenerationResult.GetImageStream: TStream;
begin
  if (FStream = nil) and (FB64 <> '') then
  begin
    FStream := TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes(FB64));
    FMimeType := GetMimeType;
  end;
  Result := FStream;
end;

function TAIImageGenerationResult.GetImageURL: string;
begin
  Result := FURL;
end;

function TAIImageGenerationResult.GetMimeType: string;
var
  LTmpByteStream: TBytesStream;
begin
  if FMimeType <> EmptyStr then
    Exit(FMimeType);

  // If we have base64, sniff; otherwise fall back to PNG default
  if (FB64 <> EmptyStr) then
  begin
    LTmpByteStream := TBytesStream.Create(TNetEncoding.Base64.DecodeStringToBytes(FB64));
    try
      try
        FMimeType := TAIUtil.DetectImageMime(LTmpByteStream);
      except
        FMimeType := EmptyStr;
      end;
    finally
      LTmpByteStream.Free;
    end;
  end;

  if FMimeType = EmptyStr then
    FMimeType := 'image/png'; // OpenAI b64_json has historically been PNG so it could be default!

  Result := FMimeType;
end;
{$ENDREGION}

{$REGION 'Moderation'}
{ TAIModerationRequest }
constructor TAIModerationRequest.Create;
begin
  FModel := 'text-moderation-latest';
end;
{$ENDREGION}


{ TAIOptionalStringDictConverter }

function TAIOptionalStringDictConverter.CanConvert(ATypeInf: PTypeInfo): Boolean;
begin
  // Attach only to fields of type TDictionary<string,string>
  Result := ATypeInf = TypeInfo(TDictionary<string,string>);
end;

procedure TAIOptionalStringDictConverter.WriteJson(
  const AWriter: TJsonWriter; const AValue: TValue; const ASerializer: TJsonSerializer);
var
  LObj: TObject;
  LDict: TDictionary<string,string>;
  LPair: TPair<string,string>;
begin
  if AValue.IsEmpty then
  begin
    AWriter.WriteNull;
    Exit;
  end;

  LObj := AValue.AsObject;
  if LObj = nil then
  begin
    AWriter.WriteNull;
    Exit;
  end;

  LDict := TDictionary<string,string>(LObj);
  AWriter.WriteStartObject;
  for LPair in LDict do
  begin
    AWriter.WritePropertyName(LPair.Key);
    // write as JSON string; if you need non-strings, adjust here
    AWriter.WriteValue(LPair.Value);
  end;
  AWriter.WriteEndObject;
end;

function TAIOptionalStringDictConverter.ReadJson(
  const AReader: TJsonReader; ATypeInf: PTypeInfo;
  const AExistingValue: TValue; const ASerializer: TJsonSerializer): TValue;
var
  LDict: TDictionary<string,string>;
  LName, LVal: string;
begin
  // null -> nil dictionary
  if AReader.TokenType = TJsonToken.Null then
    Exit(TValue.From<TDictionary<string, string>>(nil));

  if AReader.TokenType <> TJsonToken.StartObject then
    raise EAIException.Create('Expected object for dictionary.');

  LDict := TDictionary<string,string>.Create;
  try
    // Consume object
    while AReader.Read do
    begin
      case AReader.TokenType of
        TJsonToken.PropertyName:
          begin
            LName := AReader.Value.AsString;
            if not AReader.Read then Break;

            case AReader.TokenType of
              TJsonToken.String:   LVal := AReader.Value.AsString;
              TJsonToken.Integer,
              TJsonToken.Float,
              TJsonToken.Boolean:  LVal := AReader.Value.ToString;
              TJsonToken.Null:     LVal := '';
            else
              // If nested objects/arrays appear, serialize them to JSON text if you prefer
              LVal := '';
            end;

            LDict.Add(LName, LVal);
          end;

        TJsonToken.EndObject:
          Break;
      end;
    end;

    Result := TValue.From<TDictionary<string,string>>(LDict);
  except
    LDict.Free;
    raise;
  end;
end;

end.
