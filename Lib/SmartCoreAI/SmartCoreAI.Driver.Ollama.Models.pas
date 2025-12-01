{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Ollama.Models;

interface

uses
  System.Generics.Collections, System.JSON, System.Json.Types,
  System.JSON.Serializers, System.JSON.Converters, System.JSON.Readers,
  System.JSON.Writers, System.TypInfo, System.Rtti;

type
  TOllamaModelInfo = class;
  TOllamaModelInfoListConverter = class(TJsonListConverter<TOllamaModelInfo>);

  TOmitEmptyStringConverter = class(TJsonConverter)
  public
    function CanConvert(ATypeInf: PTypeInfo): Boolean; override;
    function CanWrite(const AValue: TValue): Boolean; override;
    function ReadJson(const AReader: TJsonReader; ATypeInf: PTypeInfo;
      const AExistingValue: TValue; const ASerializer: TJsonSerializer): TValue; override;
    procedure WriteJson(const AWriter: TJsonWriter; const AValue: TValue;
      const ASerializer: TJsonSerializer); override;
  end;


  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaModelNameRequest = class
  public
    [JSONName('name')] Name: string;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaCreateModelRequest = class
  public
    [JSONName('name')] Name: string;
    [JSONName('modelfile')] ModelFile: string;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaStatusResponse = class
  public
    [JSONName('status')] Status: string;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaShowModelResponse = class
  public
    [JSONName('modelfile')] ModelFile: string;
    [JSONName('parameters')] Parameters: string;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaGenerateRequest = class
  public
    [JSONName('model')] Model: string;
    [JSONName('prompt')] Prompt: string;
    [JSONName('stream')] Stream: Boolean;
    [JSONName('format')] [JsonConverter(TOmitEmptyStringConverter)] Format: string;
    [JSONName('options')] Options: TJSONObject;
    [JSONName('raw')] Raw: Boolean;
    [JSONName('system')] [JsonConverter(TOmitEmptyStringConverter)] SystemPrompt: string;
    [JSONName('template')] [JsonConverter(TOmitEmptyStringConverter)] Template: string;
    [JSONName('images')] Images: TArray<string>; // base64-encoded strings
    [JSONName('context')] Context: TArray<Integer>;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaGenerateResponse = class
  public
    [JSONName('response')] Response: string;
    [JSONName('done')] Done: Boolean;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaModelInfo = class
  public
    [JSONName('name')] Name: string;
    [JSONName('modified_at')] ModifiedAt: string;
  end;

  [JsonSerialize(TJsonMemberSerialization.Public)]
  TOllamaModelTagResponse = class
  public
    [JSONName('models')]
    [JsonConverter(TOllamaModelInfoListConverter)]
    Models: TObjectList<TOllamaModelInfo>;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TOllamaModelTagResponse }

constructor TOllamaModelTagResponse.Create;
begin
  Models := TObjectList<TOllamaModelInfo>.Create(True);
end;

destructor TOllamaModelTagResponse.Destroy;
begin
  Models.Free;
  inherited;
end;


{ TOmitEmptyStringConverter }

function TOmitEmptyStringConverter.CanConvert(ATypeInf: PTypeInfo): Boolean;
begin
  Result := ATypeInf = System.TypeInfo(string);
end;

function TOmitEmptyStringConverter.CanWrite(const AValue: TValue): Boolean;
begin
  Result := (not AValue.IsEmpty) and (AValue.AsString <> '');
end;

function TOmitEmptyStringConverter.ReadJson(const AReader: TJsonReader;
  ATypeInf: PTypeInfo; const AExistingValue: TValue;
  const ASerializer: TJsonSerializer): TValue;
begin
  if AReader.TokenType = TJsonToken.Null then
    Exit(TValue.From<string>(''));
  Result := TValue.From<string>(AReader.Value.AsString);
end;

procedure TOmitEmptyStringConverter.WriteJson(const AWriter: TJsonWriter;
  const AValue: TValue; const ASerializer: TJsonSerializer);
begin
  AWriter.WriteValue(AValue.AsString);
end;

end.
