{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Consts;

interface

resourcestring
{$REGION 'resourcestrings'}
{$REGION 'General'}
  cAIConnectionFailed = 'Failed to connect to the AI provider.';
  cAIDriverNotFound = 'No AI Driver assigned to the connection.';
  cAIConnectionNotAssigned = 'Connection not assigned';
  cAIRequestNotAssigned = 'Request not assigned';
  cAIDriverNotSupported = 'The assigned driver does not support IAIDriver interface.';
  cAIConnectionNotSupported = 'The assigned connection is not supported.';
  cAIConnectionEditor = '&Connection Editor ...';
  cAIDriverNotAssignedError = 'Driver not assigned';
  cAIDriverEmptyNameError = 'Driver name cannot be empty';
  cAIDriverNotRegesteredError = 'AI Driver not registered: %s';
  cAIDriverMetaDtaError = 'Driver metadata not found: %s';
  cAIRequiredFieldMissingError = 'Required field "%s" is missing in JSON.';
  cAIInvalidJSONError = 'Invalid JSON Error: %s';
  cAIRequestFailed = 'Request failed.';
  cAIStreamEnded = '[stream ended]';
  cAI_Msg_ModelsError = 'Failed to fetch models: HTTP %d - %s';
  cAI_Msg_BatchesError = 'Failed to list batches: HTTP %d - %s';
  cAI_Msg_ListFilesError = 'Failed to list files: HTTP %d - %s';
  cAI_Msg_CreateBatcheError = 'Failed to create batch: HTTP %d - %s';
  cAI_Msg_HttpError = 'HTTP Error, %d: %s';
  cAI_Msg_Stream_NotSupport = 'Stream operations is not supported by %s driver';
  cAI_Msg_Image_NotSupport = 'Image generation is not supported by %s driver';
  cAI_Msg_JSON_NotSupported = 'JSON Structured generation is not supported by %s driver';
  cAI_Msg_Execution_Not_Supported = 'Execution is not supported with this component, use Chat method instead.';
  cAI_Msg_UnknownMode = 'Unknown mode';
  cAI_Msg_DataSetNotAssigned = 'PopulateDataSet: DataSet is not assigned.';
  cAI_Msg_NilJson = 'PopulateDataSet: input JSON object is nil.';
  cAI_Msg_DataImportFaile = 'PopulateDataSet: data import failed : %s';
  cAI_Msg_NoInputFilePath = 'No input file path has been set.';
  cAI_Msg_EmptyEndpoint = 'No endpoint is assigned.';
  cAI_Msg_NilFactoryParam = 'AFactory param cannot be nil.';
  cAI_Msg_NilClassParam = 'AClass param cannot be nil.';
  cAI_Msg_ParamsNotAssigned = 'Params must be assigned (not nil) before Execute.';
  cAI_Msg_Nil_Stream = 'The stream param cannot be nil.';
  cAI_Msg_Empty_URL = 'URL is empty';
  cAI_Msg_EventHandlerFailed = 'Event handler failed: %s: %s';
  cAI_Msg_OperationCancelled = 'Operation cancelled.';

  cAI_Design_Msg_ErrorFetchingModels = '[Error fetching models]';
{$ENDREGION}

{$REGION 'Claude'}
  cClaude_Msg_TestConnectionSuccess = 'Connection established.';
  cClaude_Msg_TestConnectionError = 'Connection Failed.';
  cClaude_Msg_CallbackSupportError = 'Missing or invalid Callback object passed to Claude driver.';
  cClaude_Msg_OnGenerateError = 'HTTP Error %d: %s';
  cClaude_Msg_MissingModelsError = 'Model parameter is missing. Please set it in the driver parameters.';
  cClaude_Msg_APIKeyError = 'APIKey parameter is missing. Please set it in the driver parameters.';
  cClaude_Msg_MissingBaseURLError = 'Base URL is missing. Please set it in the driver parameters.';
  cClaude_Msg_PromptMissingError = 'Prompt is empty.';
  cClaude_Msg_FilePathError = 'File doesn''t exist.';
{$ENDREGION}

{$REGION 'Gemini'}
  //Messages
  cGemini_Msg_MissingModelsError = 'Model parameter is missing. Please set it in the driver parameters.';
  cGemini_Msg_APIKeyError = 'APIKey parameter is missing. Please set it in the driver parameters.';
  cGemini_Msg_MissingBaseURLError = 'Base URL is missing. Please set it in the driver parameters.';
  cGemini_Msg_PromptMissingError = 'Prompt is empty.';
  cGemini_Msg_ContentMissingError = 'Content is empty.';
  cGemini_Msg_RequestObjMissingError = 'Request Object is not assigned.';
  cGemini_Msg_TextMissingError = 'Text is empty.';
  cGemini_Msg_VoiceMissingError = 'Voice is empty.';
  cGemini_Msg_LanguageCodeMissingError = 'LanguageCode is empty.';
  cGemini_Msg_GenreMissingError = 'Genre is empty.';
  cGemini_Msg_MoodMissingError = 'Mood is empty.';
  cGemini_Msg_TestConnectionSuccess = 'Connection established.';
  cGemini_Msg_TestConnectionError = 'Connection Failed.';
  cGemini_Msg_OnGenerateError = 'HTTP Error %d: %s';
  cGemini_Msg_CallbackSupportError = 'Missing or invalid Callback object passed to Gemini driver';
  cGemini_Msg_Not_Supported = 'Not supported.';
  cAIGemini_Msg_NoCandidate = 'No content in response: %s';

{$ENDREGION}

{$REGION 'Ollama'}
  cOllama_Msg_ModelsFound = '%d models found.';
  cOllama_Msg_OnGenerateError = 'HTTP Error %d: %s';
  cOllama_Msg_CallbackSupportError = 'Missing or invalid Callback object passed to Ollama driver';
  cOllama_Msg_MissingModelsError = 'Model parameter is missing. Please set it in the driver parameters.';
  cOllama_Msg_MissingBaseURLError = 'Base URL is missing. Please set it in the driver parameters.';
  cOllama_Msg_PromptMissingError = 'Prompt is empty.';
  cOllama_Msg_MissingPathError = 'Path is empty.';
  cOllama_Msg_MissingNameError = 'Name is empty.';
{$ENDREGION}

{$REGION 'OpenAI'}
  cOpenAI_Msg_MissingModelsError = 'Model parameter is missing. Please set it in the driver parameters.';
  cOpenAI_Msg_APIKeyError = 'APIKey parameter is missing. Please set it in the driver parameters.';
  cOpenAI_Msg_MissingBaseURLError = 'Base URL is missing. Please set it in the driver parameters.';
  cOpenAI_Msg_PromptMissingError = 'Prompt is empty.';
  cOpenAI_Msg_RequestObjMissingError = 'Request Object is not assigned.';

  cOpenAI_Msg_TestConnectionSuccess = 'Connection established.';
  cOpenAI_Msg_TestConnectionError = 'Connection Failed.';
  cOpenAI_Msg_HttpErrorType = 'HTTP Error, %s (Type: %s)';
  cOpenAI_Msg_HttpErrorFull = 'HTTP Error, %s (Code: %s; Type: %s)';
  cOpenAI_Msg_CallbackSupportError = 'Missing or invalid Callback object passed to OpenAI driver';
  cOpenAI_Msg_NoValidMessageInContentError = 'No valid message content in response.';
  cOpenAI_Msg_Not_Supported = 'Decode mode not supported.';
  cOpenAI_Msg_InvalidRole = 'Invalid role: %s';
  cOpenAI_Msg_InvalidVerbosity = 'Invalid verbosity: %s';
  cOpenAI_Msg_InvalidReasoningEffort = 'Invalid reasoning.effort: %s';
{$ENDREGION}

{$ENDREGION}

const
{$REGION 'Consts'}

{$REGION 'General'}
  cAIDefaultConnectionTimeout = 60000; // 60 seconds
  cAIDefaultResponseTimeout = 120000; // 120 seconds
  cAIDefaultHandleRedirects = True;
{$ENDREGION}

{$REGION 'Claude'}
  //General
  cClaude_DriverName = 'Claude';// Do not translate
  cClaude_API_Name = 'Claude API';// Do not translate
  cClaude_Description = 'Embarcadero Anthropic driver';// Do not translate
  cClaude_Category = 'LLM Providers';// Do not translate

  //Default values
  cClaude_Def_Model = 'claude-sonnet-4-latest';
  cClaude_Def_MaxToken = 1024;

  // Endpoints
  cClaude_BaseURL = 'https://api.anthropic.com/v1';// Do not translate
  cClaude_MessagesEndpoint = '/messages';// Do not translate
  cClaude_FilesEndpoint = '/files';// Do not translate
  cClaude_ModelsEndpoint = '/models';// Do not translate
  cClaude_BatchesEndPoint = '/message_batches';// Do not translate

  //Http Custom Headers
  cClaude_CHeader_APIKey = 'x-api-key';// Do not translate
  cClaude_CHeader_AnthropicVersion = 'anthropic-version';// Do not translate
  cClaude_CHeader_JsonContentType = 'application/json';// Do not translate
  cClaude_CHeader_Accept = 'text/event-stream';// Do not translate

  // field names
  cClaude_FldName_BaseURL = 'BaseURL';// Do not translate
  cClaude_FldName_APIKey = 'APIKey';// Do not translate
  cClaude_FldName_AnthropicVersion = 'AnthropicVersion';// Do not translate
  cClaude_FldName_MaxToken = 'MaxToken';// Do not translate
  cClaude_FldName_Model = 'Model';// Do not translate
  cClaude_FldName_Timeout = 'Timeout';// Do not translate
  cClaude_FldName_Accept = 'Accept';// Do not translate
  cClaude_FldName_MessagesEndpoint = 'MessagesEndpoint';// Do not translate
  cClaude_FldName_FilesEndpoint = 'FilesEndpoint';// Do not translate
  cClaude_FldName_ModelsEndpoint = 'ModelsEndpoint';// Do not translate
  cClaude_FldName_BatchesEndPoint = 'BatchesEndPoint';// Do not translate
{$ENDREGION}

{$REGION 'Gemini'}
  //General
  cGemini_DriverName = 'Gemini';// Do not translate
  cGemini_API_Name = 'Gemini API';// Do not translate
  cGemini_Description = 'Embarcadero Gemini driver';// Do not translate
  cGemini_Category = 'LLM Providers';// Do not translate

  //Default values
  cGemini_Def_MaxToken = 1024;
  cGemini_Def_SampleCount = 1;
  cGemini_Def_Temperature = 1.0;
  cGemini_Def_TopK = 1;
  cGemini_Def_TopP = 1.0;
  cGemini_Def_AspectRatio = '';
  cGemini_Def_SampleImageSize = '';
  cGemini_Def_PersonGeneration = 'allow_adult';// Do not translate
  cGemini_Def_Model = 'gemini-2.0-flash';

  // Endpoints
  cGemini_BaseURL = 'https://generativelanguage.googleapis.com/v1beta/models';// Do not translate
  cGemini_GenerateContentEndpoint = '/%s:generateContent?key=%s';// Do not translate
  cGemini_ModelsEndpoint = '?key=';// Do not translate
  cGemini_GenerateImageEndPoint = '/%s:generateContent?key=%s';// Do not translate
  cGemini_GenerateImagePredictEndPoint = '/%s:predict?key=%s';// Do not translate
  cGemini_GenerateVideoEndPoint = '/%s:generateVideo?key=%s';// Do not translate
  cGemini_UnderstandVideoEndPoint = '/%s:understandVideo?key=%s';// Do not translate
  cGemini_UnderstandAudioEndPoint = '/%s:understandAudio?key=%s';// Do not translate
  cGemini_GenerateSpeechEndPoint = '/%s:generateSpeech?key=%s';// Do not translate
  cGemini_GenerateMusicEndPoint = '/%s:generateMusic?key=%s';// Do not translate
  cGemini_UnderstandDocumentEndPoint = '/%s:understandDocument?key=%s';// Do not translate
  cGemini_LoadModels_template = '%s%s';

  //Http Custom Headers
  cGemini_CHeader_JsonContentType = 'application/json';// Do not translate

  // field names
  cGemini_FldName_BaseURL = 'BaseURL';// Do not translate
  cGemini_FldName_APIKey = 'APIKey';// Do not translate
  cGemini_FldName_MaxToken = 'MaxToken';// Do not translate
  cGemini_FldName_Model = 'Model';// Do not translate
  cGemini_FldName_Temperature = 'Temperature';// Do not translate
  cGemini_FldName_TopK = 'TopK';// Do not translate
  cGemini_FldName_TopP = 'TopP';// Do not translate
  cGemini_FldName_Timeout = 'Timeout';// Do not translate
  cGemini_FldName_SampleCount = 'SampleCount';// Do not translate
  cGemini_FldName_AspectRatio = 'AspectRatio';// Do not translate
  cGemini_FldName_SampleImageSize = 'SampleImageSize';// Do not translate
  cGemini_FldName_PersonGeneration = 'PersonGeneration';// Do not translate
  cGemini_FldName_GenerateContentEndpoint = 'GenerateContentEndpoint';// Do not translate
  cGemini_FldName_ModelsEndpoint = 'ModelsEndpoint';// Do not translate
  cGemini_FldName_Header_Authorization = 'Authorization';// Do not translate
  cGemini_FldName_GenerateImageEndPoint = 'GenerateImageEndPoint';// Do not translate
  cGemini_FldName_GenerateImagePredictEndPoint = 'GenerateImagePredictEndPoint';// Do not translate
  cGemini_FldName_GenerateVideoEndPoint = 'GenerateVideoEndPoint';// Do not translate
  cGemini_FldName_UnderstandVideoEndPoint = 'UnderstandVideoEndPoint';// Do not translate
  cGemini_FldName_GenerateSpeechEndPoint = 'GenerateSpeechEndPoint';// Do not translate
  cGemini_FldName_UnderstandAudioEndPoint = 'UnderstandAudioEndPoint';// Do not translate
  cGemini_FldName_GenerateMusicEndPoint = 'GenerateMusicEndPoint';// Do not translate
  cGemini_FldName_UnderstandDocumentEndPoint = 'UnderstandDocumentEndPoint';// Do not translate
{$ENDREGION}

{$REGION 'Ollama'}
  //General
  cOllama_DriverName = 'Ollama'; // Do not translate
  cOllama_API_Name = 'Ollama API'; // Do not translate
  cOllama_Description = 'Embarcadero Ollama driver'; // Do not translate
  cOllama_Category = 'LLM Providers'; // Do not translate

  //Default values
  cOllama_Def_Model = 'llama3.1:8b';

  // Endpoints
  cOllama_BaseURL = 'http://localhost:11434/api';
  cOllama_GenerateEndpoint = '/generate'; // Do not translate
  cOllama_ChatEndpoint = '/chat'; // Do not translate
  cOllama_ModelsEndpoint = '/tags'; // Do not translate
  cOllama_CreateModelEndPoint = '/create'; // Do not translate
  cOllama_DeleteModelEndPoint = '/delete'; // Do not translate
  cOllama_PullEndPoint = '/pull'; // Do not translate
  cOllama_PushEndPoint = '/push'; // Do not translate
  cOllama_ShowEndPoint = '/show'; // Do not translate

  //Http Custom Headers
  cOllama_CHeader_Accept = 'text/event-stream';// Do not translate

  // field names
  cOllama_FldName_BaseURL = 'BaseURL'; // Do not translate
  cOllama_FldName_Model = 'Model'; // Do not translate
  cOllama_FldName_Raw = 'Raw'; // Do not translate
  cOllama_FldName_SystemPrompt = 'SystemPrompt'; // Do not translate
  cOllama_FldName_Template = 'Template'; // Do not translate
  cOllama_FldName_Timeout = 'Timeout'; // Do not translate
  cOllama_FldName_GenerateEndpoint = 'GenerateEndpoint'; // Do not translate
  cOllama_FldName_ChatEndpoint = 'ChatEndpoint'; // Do not translate
  cOllama_FldName_ModelsEndpoint = 'ModelsEndpoint'; // Do not translate
  cOllama_FldName_CreateModelEndPoint ='CreateModelEndPoint'; // Do not translate
  cOllama_FldName_DeleteModelEndPoint ='DeleteModelEndPoint'; // Do not translate
  cOllama_FldName_PullEndPoint = 'PullEndPoint'; // Do not translate
  cOllama_FldName_PushEndPoint = 'PushEndPoint'; // Do not translate
  cOllama_FldName_ShowEndPoint = 'ShowEndPoint'; // Do not translate
{$ENDREGION}

{$REGION 'OpenAI'}
  //General
  cOpenAI_DriverName = 'OpenAI';// Do not translate
  cOpenAI_API_Name = 'OpenAI API';// Do not translate
  cOpenAI_Description = 'Embarcadero OpenAI driver';// Do not translate
  cOpenAI_Category = 'LLM Providers';// Do not translate

  // Default values
  cOpenAI_Def_Model = 'gpt-5';
  cOpenAI_Def_MaxToken = 1024;
  cOpenAI_Def_Temperature = 1.0;
  cOpenAI_Def_TopP = 1;
  cOpenAI_Def_Stream = False;
  cOpenAI_Def_ResponseFormat = 'text';
  cOpenAI_Def_FrequencyPenalty = 1.0;
  cOpenAI_Def_PresencePenalty = 1.0;
  cOpenAI_Def_N = 1;
  cOpenAI_Def_Verbosity = 'low';
  cOpenAI_Def_ReasoningEffort = 'low';
  cOpenAI_ReasoningEfforts: array[0..3] of string = ('minimal', 'low', 'medium', 'high');
  cOpenAI_Verbosities: array[0..2] of string = ('low', 'medium', 'high');

  // Endpoints
  cOpenAI_BaseURL = 'https://api.openai.com/v1';// Do not translate
  cOpenAI_ChatEndpoint = '/chat/completions';// Do not translate
  cOpenAI_ModelsEndpoint = '/models';// Do not translate
  cOpenAI_FilesEndpoint = '/files';// Do not translate
  cOpenAI_StartFineTuningEndPoint = '/fine_tuning/jobs';// Do not translate
  cOpenAI_CancelJobEndPoint = '/fine_tuning/jobs/%s/cancel';// Do not translate
  cOpenAI_GenerateImageEndPoint = '/images/generations';// Do not translate
  cOpenAI_SynthesizeSpeechEndPoint = '/audio/speech';// Do not translate
  cOpenAI_TranscribeAudioEndPoint = '/audio/transcriptions';// Do not translate
  cOpenAI_TranslateAudioEndPoint = '/audio/translations';// Do not translate
  cOpenAI_ModerateEndPoint = '/moderations';// Do not translate
  cOpenAI_ResponsesEndPoint = '/responses';// Do not translate

  //Http Custom Headers
  cOpenAI_CHeader_JsonContentType = 'application/json';// Do not translate
  cOpenAI_CHeader_Authorization = 'Bearer ';// Do not translate
  cOpenAI_CHeader_Purpose = 'fine-tune';// Do not translate
  cOpenAI_CHeader_Accept = 'text/event-stream';// Do not translate

  // field names
  cOpenAI_FldName_BaseURL = 'BaseURL';// Do not translate
  cOpenAI_FldName_APIKey = 'APIKey';// Do not translate
  cOpenAI_FldName_MaxToken = 'MaxToken';// Do not translate
  cOpenAI_FldName_Model = 'Model';// Do not translate
  cOpenAI_FldName_Temperature = 'Temperature';// Do not translate
  cOpenAI_FldName_Timeout = 'Timeout';// Do not translate
  cOpenAI_FldName_TopP = 'TopP';// Do not translate
  cOpenAI_FldName_Stream = 'Stream';// Do not translate
  cOpenAI_FldName_ResponseFormat = 'ResponseFormat';// Do not translate
  cOpenAI_FldName_FrequencyPenalty = 'FrequencyPenalty';// Do not translate
  cOpenAI_FldName_N = 'N';// Do not translate
  cOpenAI_FldName_PresencePenalty = 'PresencePenalty';// Do not translate
  cOpenAI_FldName_Verbosity = 'Verbosity';// Do not translate (GPT-5)
  cOpenAI_FldName_ReasoningEffort = 'ReasoningEffort';// Do not translate (GPT-5)

  cOpenAI_FldName_ChatEndpoint = 'ChatEndpoint';// Do not translate
  cOpenAI_FldName_ModelsEndpoint = 'ModelsEndpoint';// Do not translate
  cOpenAI_FldName_FilesEndpoint = 'FilesEndpoint';// Do not translate
  cOpenAI_FldName_CancelJobEndPoint = 'CancelJobEndPoint';// Do not translate
  cOpenAI_FldName_GenerateImageEndPoint = 'GenerateImage';// Do not translate
  cOpenAI_FldName_StartFineTuningEndPoint = 'StartFineTuningEndPoint';// Do not translate
  cOpenAI_FldName_SynthesizeSpeechEndPoint = 'SynthesizeSpeechEndPoint';// Do not translate
  cOpenAI_FldName_TranscribeAudioEndPoint = 'TranscribeAudioEndPoint';// Do not translate
  cOpenAI_FldName_TranslateAudioEndPoint = 'TranslateAudioEndPoint';// Do not translate
  cOpenAI_FldName_ModerateEndPoint = 'ModerateEndPoint';// Do not translate
{$ENDREGION}

{$ENDREGION}

implementation

end.
