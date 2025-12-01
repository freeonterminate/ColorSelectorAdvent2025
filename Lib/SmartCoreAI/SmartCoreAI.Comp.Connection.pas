{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Comp.Connection;

{
  SmartCoreAI.Comp.Connection
  ---------------------------
  Core components for wiring a Driver into an AI connection and for issuing requests.

  - TAIConnection acts as the host, It also forwards an optional HTTP client
    customizer (TAIHttpClientCustomizer) to drivers that support IAIHttpClientCustomizable.

  - TAIRequest is a lightweight base component for executable requests. It holds a
    reference to a TAIConnection and provides a guarded Execute() that verifies
    configuration before Execute.
}
interface

uses
  System.Classes, SmartCoreAI.Types, SmartCoreAI.HttpClientConfig;

type
  /// <summary>
  ///   Central connection component. Optionally forwards an HTTP client customizer
  ///   to drivers that implement IAIHttpClientCustomizable.
  /// </summary>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIConnection = class(TComponent, IAIConnection)
  private
    FDriver: TAIDriver;
    FHttpClientCustomizer: TAIHttpClientCustomizer;

    procedure SetDriver(const AValue: TAIDriver);
    procedure PushHttpCustomizerToDriver;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    ///   Retrieves the active driver's IAIDriver interface.
    /// </summary>
    /// <returns>The IAIDriver interface implemented by the assigned driver.</returns>
    /// <exception> "SmartCoreAI.Exceptions.EAIConfigException">
    ///   Raised if no driver is assigned or the assigned driver does not support
    ///   IAIDriver.
    /// </exception>
    function GetDriverIntf: IAIDriver;
    /// <summary>
    ///   Convenience property exposing the active driver's interface. Equivalent to
    ///   calling "GetDriverIntf".
    /// </summary>
    property DriverIntf: IAIDriver read GetDriverIntf;
    /// <summary>
    ///   Optional property allowing callers to customize HTTP clients created by
    ///   drivers that support IAIHttpClientCustomizable. When set, the value
    ///   is propagated to the driver via "PushHttpCustomizerToDriver".
    /// </summary>
    property HttpClientCustomizer: TAIHttpClientCustomizer read FHttpClientCustomizer write FHttpClientCustomizer;
  published
    property Driver: TAIDriver read FDriver write SetDriver;
  end;


  /// <summary>
  ///   Base class for executable AI requests. Holds a reference to a
  ///   "TAIConnection" and provides a guarded "Execute" entry point.
  ///   Derived classes should implement "DoExecute".
  /// </summary>
  TAIRequest = class(TComponent, IAIRequest)
  private
    FConnection: TAIConnection;
    /// <summary>
    ///   Assigns the owning "TAIConnection"
    /// </summary>
    /// <param name="AValue">The connection instance to associate with this request.</param>
    procedure SetConnection(const AValue: TAIConnection);
  protected
    /// <summary>
    ///   Template method that concrete requests must implement. Called by
    ///   "Execute" after configuration validation.
    /// </summary>
    function DoExecute: TGUID; virtual; abstract;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>
    ///   Validates that "Connection" is assigned and then calls
    ///   "DoExecute". Raises a configuration exception when not configured.
    /// </summary>
    function Execute: TGUID; virtual;
  published
    property Connection: TAIConnection read FConnection write SetConnection;
  end;

implementation

uses
  System.SysUtils, SmartCoreAI.Consts, SmartCoreAI.Exceptions;

{ TAIConnection }

constructor TAIConnection.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TAIConnection.Destroy;
begin
  inherited Destroy;
end;

function TAIConnection.GetDriverIntf: IAIDriver;
begin
  if not Assigned(FDriver) then
    raise EAIConfigException.Create(cAIDriverNotAssignedError);

  if not Supports(FDriver, IAIDriver, Result) then
    raise EAIConfigException.Create(cAIDriverNotSupported);
end;

procedure TAIConnection.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDriver) then
    FDriver := nil;
end;

procedure TAIConnection.PushHttpCustomizerToDriver;
var
  Customizable: IAIHttpClientCustomizable;
begin
  if Assigned(FDriver) and Supports(FDriver, IAIHttpClientCustomizable, Customizable) then
    Customizable.SetHttpClientCustomizer(FHttpClientCustomizer);
end;

procedure TAIConnection.SetDriver(const AValue: TAIDriver);
var
  LAIDriver: IAIDriver;
begin
  if FDriver <> AValue then
  begin
    if FDriver <> nil then
      FDriver.RemoveFreeNotification(Self);

    if (AValue <> nil) and (not Supports(AValue, IAIDriver, LAIDriver)) then
      raise EAIConfigException.Create(cAIDriverNotSupported);

    FDriver := AValue;

    if FDriver <> nil then
      FDriver.FreeNotification(Self);
  end;

  if Assigned(FDriver) then
    PushHttpCustomizerToDriver;
end;

{ TAIRequest }

function TAIRequest.Execute: TGUID;
begin
  if not Assigned(FConnection) then
    raise EAIConfigException.Create(cAIConnectionNotAssigned);

  Result := DoExecute;
end;

procedure TAIRequest.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FConnection) then
    FConnection := nil;
end;

procedure TAIRequest.SetConnection(const AValue: TAIConnection);
var
  LAIConnection: IAIConnection;
begin
  if FConnection <> AValue then
  begin
    if FConnection <> nil then
      FConnection.RemoveFreeNotification(Self);

    if (AValue <> nil) and (not Supports(AValue, IAIConnection, LAIConnection)) then
      raise EAIConfigException.Create(cAIConnectionNotSupported);

    FConnection := AValue;

    if FConnection <> nil then
      FConnection.FreeNotification(Self);
  end
end;

end.
