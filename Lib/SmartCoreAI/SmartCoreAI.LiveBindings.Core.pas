{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.LiveBindings.Core;

{
  SmartCoreAI.LiveBindings.Core
  -----------------------------
  LiveBindings adapters that expose AI component responses (chat, stream, JSON)
  as bindable lists. Each adapter owns an internal list and a list adapter so
  you can bind UI controls (ListView, Memo, etc.) to incoming results.

  Notes
  -----
  - Wire the corresponding AI request component via SetChatRequest/SetStreamRequest/SetJSONRequest.
  - The adapters append items as events arrive; clear/refresh from your UI as needed.
  - Threading: underlying drivers may synchronize events to the main thread; if not,
    ensure your event handlers marshal updates appropriately before touching UI.
}

interface

uses
  System.Classes, System.Generics.Collections, Data.Bind.Components,
  Data.Bind.ObjectScope, SmartCoreAI.Comp.Chat, SmartCoreAI.Comp.Image,
  SmartCoreAI.Comp.Stream, SmartCoreAI.Comp.JSON, SmartCoreAI.Types,
  System.JSON, System.SysUtils, System.Types;

type
  /// <summary>
  ///   Single chat response item (bindable record).
  /// </summary>
  TChatResponseItem = class
  public
    /// <summary>
    ///   Chat message text to display/bind.
    /// </summary>
    Text: string;
  end;

  /// <summary>
  ///   Bind source that collects chat responses from a TAIChatRequest and exposes
  ///   them via a list adapter for LiveBindings-aware controls.
  /// </summary>
  /// <remarks>
  ///   Call SetChatRequest to attach to an existing TAIChatRequest. As responses arrive,
  ///   new TChatResponseItem entries are added to the internal list and surfaced through FAdapter.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIChatBindSource = class(TAdapterBindSource)
  private
    /// <summary>Owned list of chat response items.</summary>
    FList: TObjectList<TChatResponseItem>;
    /// <summary>List adapter exposing items to LiveBindings.</summary>
    FAdapter: TListBindSourceAdapter<TChatResponseItem>;
    /// <summary>Attached chat request component.</summary>
    FChatRequest: TAIChatRequest;

    /// <summary>
    ///   Handles chat success text and appends it as a new list item.
    /// </summary>
    procedure OnChatResponse(Sender: TObject; const Text: string);

    /// <summary>
    ///   Handles chat errors.
    /// </summary>
    procedure OnChatError(Sender: TObject; const ErrorMessage: string);
  protected
    /// <summary>
    ///   Clears references when the attached request component is removed/destroyed.
    /// </summary>
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>
    ///   Creates the bind source and its internal list/adapter.
    /// </summary>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    ///   Releases the adapter and list.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Attaches to a chat request, wiring response/error events.
    /// </summary>
    procedure SetChatRequest(ARequest: TAIChatRequest);
  end;

  /// <summary>
  ///   Single stream response item (bindable record).
  /// </summary>
  TStreamResponseItem = class
  public
    /// <summary>
    ///   Text extracted/decoded from streamed data (adapter-specific).
    /// </summary>
    Text: string;
  end;

  /// <summary>
  ///   Bind source that collects streamed results from a TAIStreamRequest and exposes
  ///   them via a list adapter for LiveBindings-aware controls.
  /// </summary>
  /// <remarks>
  ///   Call SetStreamRequest to attach to an existing TAIStreamRequest. As data arrives,
  ///   the adapter can decode/append items for binding.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIStreamBindSource = class(TAdapterBindSource)
  private
    /// <summary>Owned list of stream response items.</summary>
    FList: TObjectList<TStreamResponseItem>;
    /// <summary>List adapter exposing items to LiveBindings.</summary>
    FAdapter: TListBindSourceAdapter<TStreamResponseItem>;
    /// <summary>Attached stream request component.</summary>
    FStreamRequest: TAIStreamRequest;

    /// <summary>
    ///   Handles stream success; convert Stream to text/content and append an item.
    /// </summary>
    procedure OnStreamResponse(Sender: TObject; const Stream: TStream);
  protected
    /// <summary>
    ///   Clears references when the attached request component is removed/destroyed.
    /// </summary>
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>
    ///   Creates the bind source and its internal list/adapter.
    /// </summary>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    ///   Releases the adapter and list.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Attaches to a stream request, wiring response events.
    /// </summary>
    procedure SetStreamRequest(ARequest: TAIStreamRequest);
  end;

  /// <summary>
  ///   Single JSON response item (bindable record).
  /// </summary>
  TJSONResponseItem = class
  public
    /// <summary>
    ///   Raw JSON text to display or for further binding/processing.
    /// </summary>
    JSONText: string;
  end;

  /// <summary>
  ///   Bind source that collects JSON responses from a TAIJSONRequest and exposes
  ///   them via a list adapter for LiveBindings-aware controls.
  /// </summary>
  /// <remarks>
  ///   Call SetJSONRequest to attach to an existing TAIJSONRequest. As responses arrive,
  ///   new TJSONResponseItem entries are appended.
  /// </remarks>
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TAIJSONBindSource = class(TAdapterBindSource)
  private
    /// <summary>Owned list of JSON response items.</summary>
    FList: TObjectList<TJSONResponseItem>;
    /// <summary>List adapter exposing items to LiveBindings.</summary>
    FAdapter: TListBindSourceAdapter<TJSONResponseItem>;
    /// <summary>Attached JSON request component.</summary>
    FJSONRequest: TAIJSONRequest;

    /// <summary>
    ///   Handles JSON success and appends the payload as a new item.
    /// </summary>
    procedure OnJSONResponse(Sender: TObject; const AJSON: string);
  protected
    /// <summary>
    ///   Clears references when the attached request component is removed/destroyed.
    /// </summary>
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>
    ///   Creates the bind source and its internal list/adapter.
    /// </summary>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    ///   Releases the adapter and list.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Attaches to a JSON request, wiring response events.
    /// </summary>
    procedure SetJSONRequest(ARequest: TAIJSONRequest);
  end;

implementation


{ TAIChatBindSource }

constructor TAIChatBindSource.Create(AOwner: TComponent);
begin
  inherited;
  FList := TObjectList<TChatResponseItem>.Create(True);
  FAdapter := TListBindSourceAdapter<TChatResponseItem>.Create(Self, FList, True);
  Adapter := FAdapter;
end;

destructor TAIChatBindSource.Destroy;
begin
  if Assigned(FChatRequest) then
  begin
    FChatRequest.OnResponse := nil;
    FChatRequest.OnError    := nil;
  end;

  FAdapter := nil;
  FList := nil;
  inherited;
end;

procedure TAIChatBindSource.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FChatRequest) then
  begin
    FChatRequest.OnResponse := nil;// the request is being destroyed elsewhere
    FChatRequest := nil;
  end;
end;

procedure TAIChatBindSource.SetChatRequest(ARequest: TAIChatRequest);
begin
  if FChatRequest = ARequest then
    Exit;

  if Assigned(FChatRequest) then
  begin
    FChatRequest.RemoveFreeNotification(Self);
    FChatRequest.OnResponse := nil;
    FChatRequest.OnError    := nil;
  end;

  FChatRequest := ARequest;

  if Assigned(FChatRequest) then
  begin
    FChatRequest.FreeNotification(Self);
    FChatRequest.OnResponse := OnChatResponse;
    FChatRequest.OnError    := OnChatError;
  end;
end;

procedure TAIChatBindSource.OnChatError(Sender: TObject; const ErrorMessage: string);
begin
  TThread.Queue(nil,
    procedure
    var
      Item: TChatResponseItem;
    begin
      if csDestroying in ComponentState then Exit;

      FList.Clear;
      Item := TChatResponseItem.Create;
      Item.Text := 'ERROR: ' + ErrorMessage;
      FList.Add(Item);

      FAdapter.Active := True;
      FAdapter.ApplyUpdates;
    end);
end;

procedure TAIChatBindSource.OnChatResponse(Sender: TObject; const Text: string);
begin
  // Marshal to main thread: LiveBindings + list mutations are UI-thread things.
  TThread.Queue(nil,
    procedure
    var
      Item: TChatResponseItem;
    begin
      if csDestroying in ComponentState then
        Exit;

      FList.Clear; // TObjectList owns and frees prior items
      Item := TChatResponseItem.Create;
      Item.Text := Text;
      FList.Add(Item);

      FAdapter.Active := True;
      FAdapter.ApplyUpdates;
    end);
end;

{ TAIStreamBindSource }

constructor TAIStreamBindSource.Create(AOwner: TComponent);
begin
  inherited;
  FList := TObjectList<TStreamResponseItem>.Create(True);
  FAdapter := TListBindSourceAdapter<TStreamResponseItem>.Create(Self, FList, True);
  Adapter := FAdapter;
end;

destructor TAIStreamBindSource.Destroy;
begin
  if Assigned(FStreamRequest) then
    FStreamRequest.OnSuccess := nil;

  Adapter := nil;
  FList := nil;
  inherited;
end;

procedure TAIStreamBindSource.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FStreamRequest) then
  begin
    FStreamRequest.OnSuccess := nil;
    FStreamRequest := nil;
  end;
end;

procedure TAIStreamBindSource.SetStreamRequest(ARequest: TAIStreamRequest);
begin
  if FStreamRequest = ARequest then
    Exit;

  if Assigned(FStreamRequest) then
  begin
    FStreamRequest.RemoveFreeNotification(Self);
    FStreamRequest.OnSuccess := nil;
  end;

  FStreamRequest := ARequest;

  if Assigned(FStreamRequest) then
  begin
    FStreamRequest.FreeNotification(Self);
    FStreamRequest.OnSuccess := OnStreamResponse;
  end;
end;

procedure TAIStreamBindSource.OnStreamResponse(Sender: TObject; const Stream: TStream);
begin
  TThread.Queue(nil,
    procedure
    var
      SL: TStringList;
      Item: TStreamResponseItem;
    begin
      if csDestroying in ComponentState then
        Exit;

      FList.Clear;
      SL := TStringList.Create;
      try
        if Assigned(Stream) then
        begin
          Stream.Position := 0;
          SL.LoadFromStream(Stream); // assumes text; OK for demo
        end;
        Item := TStreamResponseItem.Create;
        Item.Text := SL.Text;
        FList.Add(Item);
      finally
        SL.Free;
      end;
      FAdapter.Active := True;
    end);
end;

{ TAIJSONBindSource }

constructor TAIJSONBindSource.Create(AOwner: TComponent);
begin
  inherited;
  FList := TObjectList<TJSONResponseItem>.Create(True);
  FAdapter := TListBindSourceAdapter<TJSONResponseItem>.Create(Self, FList, True);
  Adapter := FAdapter;
end;

destructor TAIJSONBindSource.Destroy;
begin
  if Assigned(FJSONRequest) then
    FJSONRequest.OnSuccess := nil;

  Adapter := nil;
  FList := nil;
  inherited;
end;

procedure TAIJSONBindSource.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FJSONRequest) then
  begin
    FJSONRequest.OnSuccess := nil;
    FJSONRequest := nil;
  end;
end;

procedure TAIJSONBindSource.SetJSONRequest(ARequest: TAIJSONRequest);
begin
  if FJSONRequest = ARequest then
    Exit;

  if Assigned(FJSONRequest) then
  begin
    FJSONRequest.RemoveFreeNotification(Self);
    FJSONRequest.OnSuccess := nil;
  end;

  FJSONRequest := ARequest;

  if Assigned(FJSONRequest) then
  begin
    FJSONRequest.FreeNotification(Self);
    FJSONRequest.OnSuccess := OnJSONResponse;
  end;
end;

procedure TAIJSONBindSource.OnJSONResponse(Sender: TObject; const AJSON: string);
begin
  TThread.Queue(nil,
    procedure
    var
      Item: TJSONResponseItem;
    begin
      if csDestroying in ComponentState then
        Exit;

      FList.Clear;
      Item := TJSONResponseItem.Create;
      Item.JSONText := AJSON;
      FList.Add(Item);
      FAdapter.Active := True;
    end);
end;

end.

