{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Exceptions;

{
  SmartCoreAI.Exceptions
  ----------------------
  Exception hierarchy and helpers for SmartCore AI drivers and components.

  - EAIException is the common base. Use ReraiseOrWrap to preserve original exceptions
    while adding AI-specific context.
  - Transport/HTTP-aware exceptions carry status codes, response bodies, header-derived
    metadata, and retry hints.
  - Helper routines assist with parsing provider error JSON and promoting HTTP errors
    to typed exceptions.
}

interface

uses
  System.SysUtils, System.JSON, System.Net.URLClient;

type
  /// <summary>
  ///   Base exception for all SmartCore AI errors.
  /// </summary>
  EAIException = class(Exception)
  public
    /// <summary>
    ///   Creates a new AI exception with the specified message.
    /// </summary>
    /// <param name="AMsg">Human-readable error message.</param>
    constructor Create(const AMsg: string); reintroduce;

    /// <summary>
    ///   Re-raises AE if it is already an AI exception, otherwise wraps it
    ///   inside an EAIException, optionally prefixing with Context.
    /// </summary>
    /// <param name="AE">Original exception.</param>
    /// <param name="AContext">Optional context to prepend to the message.</param>
    class procedure ReraiseOrWrap(const AE: Exception; const AContext: string = '');
  end;

  /// <summary>
  ///   Metaclass type for AI exceptions.
  /// </summary>
  EAIExceptionClass = class of EAIException;

  /// <summary>
  ///   Configuration errors (missing keys, unsupported driver, invalid endpoints).
  /// </summary>
  EAIConfigException = class(EAIException);

  /// <summary>
  ///   Input validation errors (invalid parameters, empty prompt, etc.).
  /// </summary>
  EAIValidationException = class(EAIException);

  /// <summary>
  ///   JSON parsing/structure errors.
  /// </summary>
  EAIJSONException = class(EAIException);

  /// <summary>
  ///   Transport-level errors (timeouts, connectivity, protocol).
  /// </summary>
  EAITransportException = class(EAIException);

  /// <summary>
  ///   Driver registration/initialization errors.
  /// </summary>
  EAIRegisterException = class(EAIException);

  /// <summary>
  ///   HTTP-aware transport exception that includes status code, response body,
  ///   provider error codes/types, parameter hints, and optional retry-after seconds.
  /// </summary>
  EAIHTTPException = class(EAITransportException)
  private
    FStatusCode: Integer;
    FResponseBody: string;
    FErrorCode: string;
    FErrorType: string;
    FParam: string;
    FRetryAfter: Integer;
  public
    /// <summary>
    ///   Creates an HTTP exception with full HTTP and provider error context.
    /// </summary>
    /// <param name="AStatusCode">HTTP status code.</param>
    /// <param name="AMessage">High-level error message.</param>
    /// <param name="AResponseBody">Raw response body for diagnostics.</param>
    /// <param name="AErrorCode">Provider-specific error code if available.</param>
    /// <param name="AErrorType">Provider-specific error type if available.</param>
    /// <param name="AParam">Associated parameter name (if any).</param>
    /// <param name="ARetryAfter">Retry-After seconds parsed from headers (0 if none).</param>
    constructor Create(const AStatusCode: Integer; const AMessage, AResponseBody,
      AErrorCode, AErrorType, AParam: string; const ARetryAfter: Integer = 0); reintroduce; overload;

    /// <summary>
    ///   Creates an HTTP exception with a message only.
    /// </summary>
    constructor Create(const AMessage: string); reintroduce; overload;

    /// <summary>HTTP status code.</summary>
    property StatusCode: Integer read FStatusCode;

    /// <summary>Raw response body returned by the server.</summary>
    property ResponseBody: string read FResponseBody;

    /// <summary>Provider-specific error code.</summary>
    property ErrorCode: string read FErrorCode;

    /// <summary>Provider-specific error type/category.</summary>
    property ErrorType: string read FErrorType;

    /// <summary>Parameter name that caused the error, when supplied by the provider.</summary>
    property Param: string read FParam;

    /// <summary>Retry-After header value (seconds), 0 if not provided.</summary>
    property RetryAfterSeconds: Integer read FRetryAfter;
  end;

  /// <summary>
  ///   Authentication/authorization failures (401/403 and similar).
  /// </summary>
  EAIAuthException = class(EAIHTTPException);

  /// <summary>
  ///   Rate limiting / throttling errors (429 and similar).
  /// </summary>
  EAIRateLimitException = class(EAIHTTPException);

  /// <summary>
  ///   Timeout conditions not tied to an HTTP status (socket/connect/read timeouts).
  /// </summary>
  EAITimeoutException = class(EAITransportException);

  /// <summary>
  ///   Finds a header by name (case-insensitive) and returns its value, or an empty
  ///   string if not found.
  /// </summary>
  /// <param name="AHeaders">Header array to search.</param>
  /// <param name="AName">Header name to look up.</param>
  /// <returns>Header value or empty string.</returns>
  function FindHeader(const AHeaders: TNetHeaders; const AName: string): string;

  /// <summary>
  ///   Attempts to parse a provider-style error JSON string and extract
  ///   message/code/type/param fields.
  /// </summary>
  /// <param name="ABody">Raw JSON text.</param>
  /// <param name="AMessage">Output: extracted error message.</param>
  /// <param name="ACode">Output: provider error code.</param>
  /// <param name="AType_">Output: provider error type.</param>
  /// <param name="AParam">Output: offending parameter.</param>
  /// <returns>True if parsing succeeded and fields were found; otherwise False.</returns>
  function TryParseErrorJSON(const ABody: string; out AMessage, ACode, AType_, AParam: string): Boolean;

  /// <summary>
  ///   Raises a typed AI HTTP exception based on status code, response body,
  ///   and headers. When possible, parses provider error JSON to enrich the message
  ///   and sets retry-after seconds from headers.
  /// </summary>
  /// <param name="AStatusCode">HTTP status code.</param>
  /// <param name="ABody">Raw response body.</param>
  /// <param name="AHeaders">Response headers.</param>
  /// <param name="AFallbackMessage">Optional fallback message when parsing fails.</param>
  procedure RaiseAIHTTPError(const AStatusCode: Integer; const ABody: string;
    const AHeaders: TNetHeaders; const AFallbackMessage: string = '');

implementation


uses System.SysConst;

{ EAIException }

constructor EAIException.Create(const AMsg: string);
begin
  inherited Create(AMsg);
end;

class procedure EAIException.ReraiseOrWrap(const AE: Exception; const AContext: string);
var
  LMsg: string;
begin
  if AE is EAIException then
    raise AE;
  if AContext <> '' then
    LMsg := AContext + ': ' + AE.Message
  else
    LMsg := AE.Message;
  raise EAIException.Create(LMsg) at ReturnAddress;
end;

{ EAIHTTPException }

constructor EAIHTTPException.Create(const AStatusCode: Integer; const AMessage, AResponseBody,
  AErrorCode, AErrorType, AParam: string; const ARetryAfter: Integer);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
  FResponseBody := AResponseBody;
  FErrorCode := AErrorCode;
  FErrorType := AErrorType;
  FParam := AParam;
  FRetryAfter := ARetryAfter;
end;

constructor EAIHTTPException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

function FindHeader(const AHeaders: TNetHeaders; const AName: string): string;
var
  LPair: TNameValuePair;
begin
  for LPair in AHeaders do
    if SameText(LPair.Name, AName) then
      Exit(LPair.Value);
  Result := '';
end;

function GetJSONStr(const AObj: TJSONObject; const AName: string): string;
var
  LVal: TJSONValue;
begin
  Result := '';
  if (AObj = nil) then
    Exit;
  LVal := AObj.GetValue(AName);
  if LVal = nil then
    Exit;
  if LVal is TJSONString then
    Result := TJSONString(LVal).Value
  else
    Result := LVal.ToJSON;
end;

function TryParseErrorJSON(const ABody: string; out AMessage, ACode, AType_, AParam: string): Boolean;
var
  LVal, LErr: TJSONValue;
  LRoot, LErrObj: TJSONObject;
  S: string;
begin
  AMessage := '';
  ACode := '';
  AType_ := '';
  AParam := '';
  Result := False;

  if Trim(ABody) = '' then
    Exit;

  LVal := TJSONObject.ParseJSONValue(ABody, False, True);
  try
    if LVal = nil then
      Exit;

    if LVal is TJSONObject then
    begin
      LRoot := TJSONObject(LVal);

      // Common "error" object
      LErr := LRoot.GetValue('error');
      if (LErr <> nil) and (LErr is TJSONObject) then
      begin
        LErrObj := TJSONObject(LErr);
        AMessage := GetJSONStr(LErrObj, 'message');
        if AMessage = '' then
          AMessage := GetJSONStr(LErrObj, 'error');
        ACode := GetJSONStr(LErrObj, 'code');
        if ACode = '' then
          ACode := GetJSONStr(LErrObj, 'status');
        AType_ := GetJSONStr(LErrObj, 'type');
        AParam := GetJSONStr(LErrObj, 'param');
        Result := (AMessage <> '') or (ACode <> '') or (AType_ <> '') or (AParam <> '');
        Exit;
      end;

      // Root-level error/message
      S := GetJSONStr(LRoot, 'error');
      if S <> '' then
      begin
        AMessage := S;
        Result := True;
        Exit;
      end;
      S := GetJSONStr(LRoot, 'message');
      if S <> '' then
      begin
        AMessage := S;
        Result := True;
        Exit;
      end;
    end
    else if LVal is TJSONString then
    begin
      AMessage := TJSONString(LVal).Value;
      Result := AMessage <> '';
      Exit;
    end;
  finally
    LVal.Free;
  end;
end;

procedure RaiseAIHTTPError(const AStatusCode: Integer; const ABody: string;
  const AHeaders: TNetHeaders; const AFallbackMessage: string);
var
  LMsg, LCode, LType, LParam: string;
  LRetryAfter: Integer;
  LRetryHdr: string;
begin
  if not TryParseErrorJSON(ABody, LMsg, LCode, LType, LParam) then
    LMsg := AFallbackMessage;

  if LMsg = '' then
    LMsg := Format('HTTP %d error', [AStatusCode]);

  LRetryAfter := 0;
  LRetryHdr := FindHeader(AHeaders, 'Retry-After');
  if LRetryHdr <> '' then
    if not TryStrToInt(Trim(LRetryHdr), LRetryAfter) then
      LRetryAfter := 0;

  case AStatusCode of
    401, 403:
      raise EAIAuthException.Create(AStatusCode, LMsg, ABody, LCode, LType, LParam, LRetryAfter);
    408, 504:
      raise EAITimeoutException.Create('Timeout (HTTP ' + AStatusCode.ToString + '): ' + LMsg);
    429:
      raise EAIRateLimitException.Create(AStatusCode, LMsg, ABody, LCode, LType, LParam, LRetryAfter);
  else
    raise EAIHTTPException.Create(AStatusCode, LMsg, ABody, LCode, LType, LParam, LRetryAfter);
  end;
end;

end.
