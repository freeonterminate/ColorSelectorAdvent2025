{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Claude.Models;

interface

uses
  System.Generics.Collections, System.Json.Types, System.JSON.Serializers,
  System.JSON.Converters;

type
  // Role definition for messages
  TClaudeRole = (crUser, crAssistant);

  // Message content block
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeContentBlock = class
  private
    FType: string;
    FText: string;
  public
    constructor Create(const AText: string);

    [JSONName('type')] property &Type: string read FType write FType; // must be "text" / "string"
    [JSONName('text')] property Text: string read FText write FText;
  end;

  TClaudeContentBlockListConverter = class(TJsonListConverter<TClaudeContentBlock>);

  // Message structure
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeMessage = class
  private
    FRole: string;
    FContent: TObjectList<TClaudeContentBlock>;
  public
    constructor Create(const ARole, AText: string);
    destructor Destroy; override;

    [JSONName('role')] property Role: string read FRole write FRole;
    [JSONName('content')] [JsonConverter(TClaudeContentBlockListConverter)] property Content: TObjectList<TClaudeContentBlock> read FContent write FContent;
  end;

  TClaudeMessageListConverter = class(TJsonListConverter<TClaudeMessage>);

  // Request to Claude /v1/messages
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeMessageRequest = class
  private
    FModel: string;
    FMessages: TObjectList<TClaudeMessage>;
    FSystem: string;
    FMaxTokens: Integer;
    FStream: Boolean;
    FTemperature: Double;
    FTopK: Integer;
    FTopP: Double;
    FStop: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;

    [JSONName('model')] property Model: string read FModel write FModel;
    [JSONName('messages')] [JsonConverter(TClaudeMessageListConverter)] property Messages: TObjectList<TClaudeMessage> read FMessages write FMessages;
    [JSONName('system')] property System: string read FSystem write FSystem;
    [JSONName('stream')] property Stream: Boolean read FStream write FStream;
    [JSONName('max_tokens')] property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    [JSONName('temperature')] property Temperature: Double read FTemperature write FTemperature;
    [JSONName('top_k')] property TopK: Integer read FTopK write FTopK;
    [JSONName('top_p')] property TopP: Double read FTopP write FTopP;
    [JSONName('stop_sequences')] property StopSequences: TArray<string> read FStop write FStop;
  end;

  // File information returned from Claude API
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeFileInfo = class
  public
    [JSONName('id')] ID: string;
    [JSONName('name')] Name: string;
    [JSONName('type')] FileType: string;
    [JSONName('size')] Size: Integer;
    [JSONName('created_at')] CreatedAt: Int64;
  end;

  // Batch creation request
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeBatchRequest = class
  public
    [JSONName('metadata')] Metadata: string;
    [JSONName('input_file_id')] InputFileID: string;
    [JSONName('completion_parameters')] CompletionParameters: TClaudeMessageRequest;
  end;

  // Claude model info
  [JsonSerialize(TJsonMemberSerialization.Public)]
  TClaudeModelInfo = class
  public
    [JSONName('id')] ID: string;
    [JSONName('name')] Name: string;
    [JSONName('context_length')] ContextLength: Integer;
  end;

implementation

{ TClaudeContentBlock }

constructor TClaudeContentBlock.Create(const AText: string);
begin
  FType := 'text';
  FText := AText;
end;

{ TClaudeMessage }

constructor TClaudeMessage.Create(const ARole, AText: string);
begin
  FRole := ARole;
  FContent := TObjectList<TClaudeContentBlock>.Create(True);
  FContent.Add(TClaudeContentBlock.Create(AText));
end;

destructor TClaudeMessage.Destroy;
begin
  FContent.Free;
  inherited;
end;

{ TClaudeMessageRequest }

constructor TClaudeMessageRequest.Create;
begin
  FMessages := TObjectList<TClaudeMessage>.Create(True);
  FModel := 'claude-3-opus-20240229';
  FStream := False;
  FTemperature := 1.0;
  FTopK := 250;
  FTopP := 1.0;
  FMaxTokens := 1024;
  FStop := nil;
  FSystem := '';
end;

destructor TClaudeMessageRequest.Destroy;
begin
  FMessages.Free;
  inherited;
end;

end.
