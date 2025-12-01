{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Comp.JSON;
{
  SmartCoreAI.Comp.JSON
  ---------------------
  Component wrapper for JSON-oriented requests. It delegates execution to the
  active driver through DriverIntf on the associated Connection and surfaces
  results via success/error events. Optionally maps JSON into a DataSet using a
  bridge helper.

  Notes
  -----
  - Set Endpoint and Params before calling Execute.
  - If DataSet is assigned, PopulateDataset can discover an array in the JSON
    payload and append rows into the target dataset.
  - Threading and event synchronization are controlled by the driver; if your
    UI depends on main-thread handlers, ensure the driver is configured to
    synchronize events.
  - For cancellation, use the RequestId returned by the driver-side invocation
    and call the corresponding cancel routine on the driver.
}

interface

uses
  System.Classes, System.SysUtils, System.JSON, Data.DB, System.Generics.Collections,
  SmartCoreAI.Types, SmartCoreAI.Comp.Connection, Data.DBJson;

type
  /// <summary>
  ///   Event raised when a JSON request completes successfully.
  /// </summary>
  /// <param name="Sender">
  ///   The TAIJSONRequest instance that raised the event.
  /// </param>
  /// <param name="Response">
  ///   The raw JSON response serialized as a string (typically UTF-8).
  /// </param>
  TAIJSONRequestSuccessEvent = procedure(Sender: TObject; const Response: string) of object;

  /// <summary>
  ///   Declarative JSON request component. It delegates execution to the active driver
  ///   through DriverIntf on the associated Connection, and surfaces success/error via events.
  /// </summary>
  /// <remarks>
  ///   - Set Endpoint and Params prior to Execute.
  ///   - If you assign DataSet, PopulateDataset can be used to map JSON into the dataset.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIJSONRequest = class(TAIRequest, IAIJSONCallback)
  private
    FEndpoint: string;
    FParams: string;
    FDataSet: TDataSet;
    FOnSuccess: TAIJSONRequestSuccessEvent;
    FOnError: TAIErrorEvent;

    /// <summary>
    ///   Assigns a dataset.
    /// </summary>
    /// <param name="Value">The dataset to associate with this request.</param>
    procedure SetDataSet(const Value: TDataSet);
  protected
    /// <summary>
    ///   Maps JSON content into DataSet.
    /// </summary>
    /// <param name="AJSONObject">
    ///   Root JSON object received from the provider.
    /// </param>
    /// <returns>
    ///   True when JSON data was found and mapped; otherwise False.
    /// </returns>
    /// <remarks>
    ///   Expects DataSet to be assigned. The internal bridge may close/reopen the dataset,
    ///   define fields, and append rows based on the JSON array discovered within AJSONObject.
    /// </remarks>
    function PopulateDataset(const AJSONObject: TJSONObject): Boolean; virtual;
    /// <summary>
    ///   Validates configuration (Connection, DriverIntf, Endpoint/Params as needed)
    ///   and delegates execution to the driver.
    /// </summary>
    function DoExecute: TGUID; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    // IAIJSONCallback implementation

    /// <summary>
    ///   Delivers the successful JSON response as a string.
    /// </summary>
    /// <param name="AResponse">Raw JSON response text.</param>
    procedure DoSuccess(const AResponse: string); virtual;

    /// <summary>
    ///   Delivers a normalized error message in case of failure.
    /// </summary>
    /// <param name="AErrorMessage">Human-readable error description.</param>
    procedure DoError(const AErrorMessage: string); virtual;
  public
    property Params: string read FParams write FParams;
  published
    property DataSet: TDataSet read FDataSet write SetDataSet;
    property OnSuccess: TAIJSONRequestSuccessEvent read FOnSuccess write FOnSuccess;
    property OnError: TAIErrorEvent read FOnError write FOnError;
    property Endpoint: string read FEndpoint write FEndpoint;
  end;

implementation

uses
  SmartCoreAI.Consts, SmartCoreAI.Exceptions;

function TAIJSONRequest.DoExecute: TGUID;
begin
  if not Assigned(Connection) then
    raise EAIConfigException.Create(cAIConnectionNotAssigned);
  if not Assigned(Connection.DriverIntf) then
    raise EAIConfigException.Create(cAIDriverNotFound);

  Result := Connection.DriverIntf.ExecuteJSONRequest(FEndpoint, FParams, Self);
end;

procedure TAIJSONRequest.DoSuccess(const AResponse: string);
begin
  if Assigned(FOnSuccess) then
    FOnSuccess(Self, AResponse);
end;

procedure TAIJSONRequest.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDataSet) then
    FDataSet := nil;
end;

procedure TAIJSONRequest.DoError(const AErrorMessage: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, AErrorMessage);
end;

function TAIJSONRequest.PopulateDataset(const AJSONObject: TJSONObject): Boolean;
var
  LProvider  : IAIJSONDataProvider;
  LArray     : TJSONArray;
  LInner     : TJSONValue;
  LOwnsArray : Boolean;
  LBridge    : TJSONToDataSetBridge;
begin
  inherited;
  if not Assigned(FDataSet) then
    raise EAIConfigException.Create(cAI_Msg_DataSetNotAssigned);
  if not Assigned(AJSONObject) then
    raise EAIJSONException.Create(cAI_Msg_NilJson);
  if not Supports(Connection.Driver, IAIJSONDataProvider, LProvider) then
    raise EAIException.Create(cAI_Msg_JSON_NotSupported);

  Result := LProvider.FindJSONData(AJSONObject, LArray, LInner, LOwnsArray);
  if not Result then
    raise EAIException.Create(cAI_Msg_JSON_NotSupported);

  LBridge := TJSONToDataSetBridge.Create(nil);
  try
    if FDataSet.Active then FDataSet.Close;
    FDataSet.Fields.Clear;
    LBridge.ObjectView := True;
    LBridge.TypesMode  := TJSONTypesMode.Rich;
    LBridge.Dataset    := FDataSet;
    LBridge.FieldDefs  := FDataSet.FieldDefs;

    try
      LBridge.Define(LArray);
      LBridge.Dataset.Active := True;
      LBridge.Append(LArray);
    except
      on E: Exception do
        raise EAIException.CreateFmt(cAI_Msg_DataImportFaile, [E.Message]);
    end;
  finally
    LBridge.Free;
    LInner.Free;
    if LOwnsArray then
      LArray.Free;
  end;
end;

procedure TAIJSONRequest.SetDataSet(const Value: TDataSet);
begin
  if Value = FDataSet then
    Exit;

  if Assigned(FDataSet) then
    FDataSet.RemoveFreeNotification(Self);

  FDataSet := Value;

  if Assigned(FDataSet) then
    FDataSet.FreeNotification(Self);
end;

end.
