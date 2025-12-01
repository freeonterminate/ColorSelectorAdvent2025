{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Comp.Image;

{
  SmartCoreAI.Comp.Image
  ----------------------
  Component wrapper for image-generation requests. It delegates execution to the
  active Driver through DriverIntf on the associated Connection and surfaces the
  result via callback events.

  Notes on threading & cancellation
  ---------------------------------
  - Execution is performed by the Driver. Depending on driver settings, events may
    be synchronized to the main thread (e.g., when the driver uses queued calls).
  - If your application supports request cancellation, use the RequestId returned by
    the driver-side invocation to cancel in-flight operations via the driver via
    The Driver.Cancel(RequestId) procedure.
}

interface

uses
  System.Classes, System.SysUtils, System.JSON, SmartCoreAI.Types,
  SmartCoreAI.Comp.Connection;

type
  /// <summary>
  ///   Event raised when image generation completes successfully.
  /// </summary>
  /// <param name="Sender">
  ///   The TAIImageRequest instance that raised the event.
  /// </param>
  /// <param name="Images">
  ///   Array of image results provided by the AI provider. Each result may expose helpers
  ///   to access decoded bitmaps depending on the selected decode mode.
  /// </param>
  /// <param name="FullJsonResponse">
  ///   Raw JSON payload of the provider response, serialized as text. Useful for
  ///   diagnostics or custom parsing.
  /// </param>
  TAIRequestImageSuccessEvent = procedure(Sender: TObject; const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string) of object;

  /// <summary>
  ///   Declarative request component for image generation. It calls the active Driver
  ///   via Connection and raises events for success or error outcomes.
  /// </summary>
  /// <remarks>
  ///   - Set APIRequestObject with the request settings (prompt, size, etc.) before calling Execute.
  ///   - Execute validates Connection, DriverIntf, and APIRequestObject, then forwards the call.
  ///   - DecodeMode instructs the driver how to decode image payloads (for example, base64).
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIImageRequest = class(TAIRequest, IAIImageCallback)
  private
    FImageData: TMemoryStream;
    FAPIRequestObject: IAIImageGenerationRequest;
    FOnSuccess: TAIRequestImageSuccessEvent;
    FOnError: TAIErrorEvent;
    FDecodeMode: TAIImageDecodeMode;
  protected
    /// <summary>
    ///   Executes the image-generation request by delegating to DriverIntf.
    /// </summary>
    /// <exception>
    ///   Raises a configuration exception(EAIConfigException) when Connection, DriverIntf, or APIRequestObject is not assigned.
    /// </exception>
    function DoExecute: TGUID; override;

    // IAIImageCallback

    /// <summary>
    ///   Delivers successful results from the driver.
    /// </summary>
    /// <param name="Images">
    ///   Array of image generation results as provided by the AI provider.
    /// </param>
    /// <param name="FullJsonResponse">
    ///   Raw JSON payload of the response, serialized as text.
    /// </param>
    procedure DoSuccess(const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string); virtual;

    /// <summary>
    ///   Delivers an error message describing the failure.
    /// </summary>
    /// <param name="ErrorMessage">
    ///   Human-readable message already normalized by the driver.
    /// </param>
    procedure DoError(const ErrorMessage: string); virtual;
    /// <summary>
    ///   Returns the current image decode mode used by the driver to interpret results.
    /// </summary>
    function GetDecodeMode: TAIImageDecodeMode; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Request object specifying provider-specific parameters for image generation
    ///   (for example, prompt, size, background, count). Must be assigned before Execute.
    ///  Otherwise an EAIConfigException exception will raise.
    ///  The caller is the owner of the object.
    /// </summary>
    property APIRequestObject: IAIImageGenerationRequest read FAPIRequestObject write FAPIRequestObject;
  published
    property DecodeMode: TAIImageDecodeMode read FDecodeMode write FDecodeMode default idmAuto;
    property OnSuccess: TAIRequestImageSuccessEvent read FOnSuccess write FOnSuccess;
    property OnError: TAIErrorEvent read FOnError write FOnError;
  end;

implementation

uses
  SmartCoreAI.Consts, SmartCoreAI.Exceptions;

{ TAIImageRequest }

constructor TAIImageRequest.Create(AOwner: TComponent);
begin
  inherited;
  FImageData := TMemoryStream.Create;
end;

destructor TAIImageRequest.Destroy;
begin
  FImageData.Free;
  inherited;
end;

procedure TAIImageRequest.DoError(const ErrorMessage: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, ErrorMessage);
end;

function TAIImageRequest.DoExecute: TGUID;
begin
  if not Assigned(Connection) then
    raise EAIConfigException.Create(cAIConnectionNotAssigned);
  if not Assigned(Connection.DriverIntf) then
    raise EAIConfigException.Create(cAIDriverNotFound);
  if not Assigned(FAPIRequestObject) then
    raise EAIConfigException.Create(cAIRequestNotAssigned);

  Result := Connection.DriverIntf.GenerateImage(FAPIRequestObject, Self);
end;

procedure TAIImageRequest.DoSuccess(const Images: TArray<IAIImageGenerationResult>; const FullJsonResponse: string);
begin
  if Assigned(FOnSuccess) then
    FOnSuccess(Self, Images, FullJsonResponse);
end;

function TAIImageRequest.GetDecodeMode: TAIImageDecodeMode;
begin
  Result := FDecodeMode;
end;

end.
