{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.FMXUI.LiveBindings;

{
  SmartCoreAI.FMXUI.LiveBindings
  ----------------------------
  LiveBindings helpers for FMX that turn AI image results into bindable items.

  - TImageResponseItemFMX wraps an FMX TBitmap plus basic metadata (MIME type, source URL).
  - TAIImageBindSource is a list adapter that accepts IAIImageGenerationResult[] and
    exposes TImageResponseItemFMX items to LiveBindings-aware controls.

  Notes
  -----
  - If AutoDownloadFromURL = True and a result provides ImageURL but no ImageStream,
    the adapter can download via OnDownloadStream or a default THTTPClient-based downloader.
  - Ownership: The adapter owns created TImageResponseItemFMX instances.
}

interface

uses
  System.Classes, System.SysUtils, System.Net.HttpClient,
  Data.Bind.ObjectScope, FMX.Graphics, System.Generics.Collections,
  SmartCoreAI.Types;

type
  /// <summary>
  ///   Optional hook to download a stream for a given URL. Return a stream positioned
  ///   at the beginning; the caller takes ownership of the returned stream.
  /// </summary>
  /// <param name="AURL">Image URL to download.</param>
  /// <returns>Stream containing the downloaded content, or nil to signal failure.</returns>
  TDownloadStreamEvent = function(const AURL: string): TStream of object;

  // Data item exposed to LiveBindings for FMX
  /// <summary>
  ///   Data item exposed to FMX LiveBindings for image scenarios.
  ///   Wraps an FMX bitmap plus basic metadata about the source.
  /// </summary>
  TImageResponseItemFMX = class
  private
    FBitmap: FMX.Graphics.TBitmap;
    FMimeType: string;
    FImageURL: string;
  public
    /// <summary>
    ///   Creates an empty item with an owned FMX bitmap instance.
    /// </summary>
    constructor Create; overload;
    /// <summary>
    ///   Creates an item from an image stream, setting MIME type and source URL.
    ///   The constructor decodes the stream into the internal bitmap.
    /// </summary>
    constructor CreateFromStream(AStream: TStream; const AMimeType, AURL: string); overload;
    /// <summary>
    ///   Frees the owned bitmap and resources.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    ///   Decoded bitmap (caller should not free).
    /// </summary>
    property Bitmap: FMX.Graphics.TBitmap read FBitmap;
    /// <summary>
    ///   Image MIME type (e.g., image/png, image/jpeg).
    /// </summary>
    property MimeType: string read FMimeType;
    /// <summary>
    ///   Original image URL when available.
    /// </summary>
    property ImageURL: string read FImageURL;
  end;

  // Bind source adapter: feed it model results, it produces bindable FMX items
  [ComponentPlatformsAttribute(pidAllPlatforms)]
  /// <summary>
  ///   Bind source adapter that turns AI image generation results into
  ///   TImageResponseItemFMX items for LiveBindings-aware FMX controls.
  /// </summary>
  /// <remarks>
  ///   Call SetResults with the provider results; the adapter rebuilds its internal list.
  ///   If AutoDownloadFromURL is True, the adapter will try to fetch images that have only a URL.
  ///   You can override downloading by assigning OnDownloadStream.
  /// </remarks>
  TAIImageBindSource = class(TListBindSourceAdapter<TImageResponseItemFMX>)
  private
    /// <summary>
    ///   When True, items with ImageURL but no ImageStream are downloaded automatically.
    /// </summary>
    FAutoDownloadFromURL: Boolean;
    /// <summary>
    ///   Optional custom downloader. If not assigned, a default THTTPClient-based
    ///   downloader is used.
    /// </summary>
    FOnDownloadStream: TDownloadStreamEvent;

    /// <summary>
    ///   Default downloader that fetches the URL using THTTPClient and returns a stream.
    /// </summary>
    function DefaultDownload(const AURL: string): TStream;

    /// <summary>
    ///   Converts a single IAIImageGenerationResult into an item, decoding from stream
    ///   when available, or downloading by URL if AutoDownloadFromURL is enabled.
    /// </summary>
    function LoadItemFromResult(const R: IAIImageGenerationResult): TImageResponseItemFMX;
  public
    /// <summary>
    ///   Creates the bind source adapter with an empty list.
    /// </summary>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    ///   Replaces the current list with new image results and updates bindings.
    /// </summary>
    /// <param name="AResults">Array of image generation results.</param>
    procedure SetResults(const AResults: TArray<IAIImageGenerationResult>);

    /// <summary>
    ///   If True and an item has only ImageURL, the adapter will try to download
    ///   the image automatically (using OnDownloadStream or DefaultDownload).
    /// </summary>
    property AutoDownloadFromURL: Boolean read FAutoDownloadFromURL write FAutoDownloadFromURL default False;

    /// <summary>
    ///   Optional custom downloader; return a stream for the given URL.
    ///   If nil, DefaultDownload is used.
    /// </summary>
    property OnDownloadStream: TDownloadStreamEvent read FOnDownloadStream write FOnDownloadStream;
  end;

implementation

uses
  SmartCoreAI.Exceptions;

{ TImageResponseItemFMX }

constructor TImageResponseItemFMX.Create;
begin
  inherited Create;
  FBitmap := FMX.Graphics.TBitmap.Create;
end;

constructor TImageResponseItemFMX.CreateFromStream(AStream: TStream; const AMimeType, AURL: string);
var
  LPos: Int64;
begin
  Create;
  FMimeType := AMimeType;
  FImageURL := AURL;

  if Assigned(AStream) then
  begin
    LPos := AStream.Position;
    try
      AStream.Position := 0;
      // FMX TBitmap can load PNG/JPEG via codecs
      FBitmap.LoadFromStream(AStream);
    finally
      try
        AStream.Position := LPos;
      except
        // ignore non-seekable
      end;
    end;
  end;
end;

destructor TImageResponseItemFMX.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

{ TAIImageBindSource }

constructor TAIImageBindSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Self.SetList(TList<TImageResponseItemFMX>.Create, True); // True => adapter owns the TList and its items
  FAutoDownloadFromURL := False;
end;

function TAIImageBindSource.DefaultDownload(const AURL: string): TStream;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LTempStrm: TMemoryStream;
begin
  Result := nil;
  if AURL = '' then
    Exit;

  LHttpClient := THTTPClient.Create;
  try
    try
      LResp := LHttpClient.Get(AURL, nil);
    except on E: Exception do
      raise EAIHTTPException.Create(E.Message);
    end;

    if TAIUtil.IsSuccessfulResponse(LResp) and Assigned(LResp.ContentStream) then
    begin
      LTempStrm := TMemoryStream.Create;
      try
        LResp.ContentStream.Position := 0;
        LTempStrm.CopyFrom(LResp.ContentStream, LResp.ContentStream.Size);
        LTempStrm.Position := 0;
        Result := LTempStrm; // *** caller takes ownership ***
      except on E: Exception do
        begin
          LTempStrm.Free;
          raise EAIException.Create(E.Message);
        end;
      end;
    end;
  finally
    LHttpClient.Free;
  end;
end;

function TAIImageBindSource.LoadItemFromResult(const R: IAIImageGenerationResult): TImageResponseItemFMX;
var
  S: TStream;
  Tmp: TStream;
begin
  S := R.ImageStream;

  if (S = nil) and FAutoDownloadFromURL and (R.ImageURL <> '') then
  begin
    if Assigned(FOnDownloadStream) then
      Tmp := FOnDownloadStream(R.ImageURL)
    else
      Tmp := DefaultDownload(R.ImageURL);

    try
      Result := TImageResponseItemFMX.CreateFromStream(Tmp, R.MimeType, R.ImageURL);
    finally
      Tmp.Free;
    end;
    Exit;
  end;

  Result := TImageResponseItemFMX.CreateFromStream(S, R.MimeType, R.ImageURL);
end;

procedure TAIImageBindSource.SetResults(const AResults: TArray<IAIImageGenerationResult>);
var
  R: IAIImageGenerationResult;
  Item: TImageResponseItemFMX;
begin
  List.Clear;
  for R in AResults do
  begin
    Item := LoadItemFromResult(R);
    List.Add(Item);
  end;
  Active := True;
end;

end.
