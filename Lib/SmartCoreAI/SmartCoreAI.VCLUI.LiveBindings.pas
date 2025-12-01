{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.VCLUI.LiveBindings;

{
  SmartCoreAI.VCLUI.LiveBindings
  ----------------------------
  LiveBindings helpers for VCL that turn AI image results into bindable items.

  - TImageResponseItemVCL wraps a VCL TBitmap plus basic metadata (MIME type, source URL).
  - TAIImageBindSource is a list adapter that accepts IAIImageGenerationResult[] and
    exposes TImageResponseItemVCL items to LiveBindings-aware controls.

  Notes
  -----
  - If AutoDownloadFromURL = True and a result provides ImageURL but no ImageStream,
    the adapter can download via OnDownloadStream or a default THTTPClient-based downloader.
  - Ownership: The adapter owns created TImageResponseItemVCL instances.
}

interface

uses
  System.Classes, System.SysUtils, System.Net.HttpClient,
  Data.Bind.ObjectScope, Vcl.Graphics, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage,
  SmartCoreAI.Types, System.Generics.Collections, SmartCoreAI.Exceptions,
  SmartCoreAI.HttpClientConfig;

type
  /// <summary>
  ///   Optional hook to download a stream for a given URL. Return a stream positioned
  ///   at the beginning; the caller takes ownership of the returned stream.
  /// </summary>
  /// <param name="AURL">Image URL to download.</param>
  /// <returns>Stream containing the downloaded content, or nil to signal failure.</returns>
  TAIDownloadStreamEvent = function(const AURL: string): TStream of object;

  /// <summary>
  ///   Data item exposed to LiveBindings for VCL image scenarios.
  ///   Wraps a bitmap plus basic metadata about the source.
  /// </summary>
  TImageResponseItemVCL = class
  private
    FBitmap: Vcl.Graphics.TBitmap;
    FMimeType: string;
    FImageURL: string;
  public
    /// <summary>
    ///   Creates an empty item with an owned bitmap instance.
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
    property Bitmap: Vcl.Graphics.TBitmap read FBitmap;
    /// <summary>
    ///   Image MIME type (e.g., image/png, image/jpeg).
    /// </summary>
    property MimeType: string read FMimeType;
    /// <summary>
    ///   Original image URL when available.
    /// </summary>
    property ImageURL: string read FImageURL;
  end;

  /// <summary>
  ///   Bind source adapter that turns AI image generation results into
  ///   TImageResponseItemVCL items for LiveBindings-aware VCL controls.
  /// </summary>
  /// <remarks>
  ///   Call SetResults with the provider results; the adapter rebuilds its internal list.
  ///   If AutoDownloadFromURL is True, the adapter will try to fetch images that have only a URL.
  ///   You can override downloading by assigning OnDownloadStream.
  /// </remarks>
  [ComponentPlatformsAttribute(pfidWindows)]
  TAIImageBindSource = class(TListBindSourceAdapter<TImageResponseItemVCL>)
  private
    /// <summary>
    ///   When True, items with ImageURL but no ImageStream are downloaded automatically.
    /// </summary>
    FAutoDownloadFromURL: Boolean;
    /// <summary>
    ///   Optional custom downloader. If not assigned, a default THTTPClient-based
    ///   downloader is used.
    /// </summary>
    FOnDownloadStream: TAIDownloadStreamEvent;

    /// <summary>
    ///   Default downloader that fetches the URL using THTTPClient and returns a stream.
    /// </summary>
    function DefaultDownload(const AURL: string): TStream;

    /// <summary>
    ///   Converts a single IAIImageGenerationResult into an item, decoding from stream
    ///   when available, or downloading by URL if AutoDownloadFromURL is enabled.
    /// </summary>
    function LoadItemFromResult(const R: IAIImageGenerationResult): TImageResponseItemVCL;
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
    property OnDownloadStream: TAIDownloadStreamEvent read FOnDownloadStream write FOnDownloadStream;
  end;

implementation

{ TImageResponseItemVCL }

constructor TImageResponseItemVCL.Create;
begin
  inherited Create;
  FBitmap := Vcl.Graphics.TBitmap.Create;
end;

constructor TImageResponseItemVCL.CreateFromStream(AStream: TStream; const AMimeType, AURL: string);
var
  LPic: TPicture;
  LPos: Int64;
begin
  Create;
  FMimeType := AMimeType;
  FImageURL := AURL;

  if Assigned(AStream) then
  begin
    LPos := AStream.Position;
    try
      // TPicture auto-detects codecs (JPEG/PNG) via registered classes
      LPic := TPicture.Create;
      try
        AStream.Position := 0;
        LPic.LoadFromStream(AStream);
        FBitmap.Assign(LPic.Graphic);
      finally
        LPic.Free;
      end;
    finally
      try
        AStream.Position := LPos; // Do not own/keep AStream; restore as courtesy if caller reuses it
      except
        // ignore if non-seekable
      end;
    end;
  end;
end;

destructor TImageResponseItemVCL.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

{ TAIImageBindSource }

constructor TAIImageBindSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Self.SetList(TList<TImageResponseItemVCL>.Create, True); // True => adapter owns the TList and its items
  FAutoDownloadFromURL := False;
end;

function TAIImageBindSource.DefaultDownload(const AURL: string): TStream;
var
  LHttpClient: THTTPClient;
  LResp: IHTTPResponse;
  LTmpStream: TMemoryStream;
begin
  Result := nil;
  if AURL = '' then
    Exit;

  LHttpClient := TAIHttpClientConfig.CreateClient;
  try
    try
      LResp := LHttpClient.Get(AURL, nil);
    except on E: Exception do
      raise EAIHTTPException.Create(E.Message);
    end;

    if TAIUtil.IsSuccessfulResponse(LResp) and Assigned(LResp.ContentStream) then
    begin
      LTmpStream := TMemoryStream.Create;
      try
        LResp.ContentStream.Position := 0;
        LTmpStream.CopyFrom(LResp.ContentStream, LResp.ContentStream.Size);
        LTmpStream.Position := 0;
        Result := LTmpStream; // *** caller takes ownership ***
      except on E: Exception do
        begin
          LTmpStream.Free;
          raise EAIException.Create(E.Message);
        end;
      end;
    end;
  finally
    LHttpClient.Free;
  end;
end;

function TAIImageBindSource.LoadItemFromResult(const R: IAIImageGenerationResult): TImageResponseItemVCL;
var
  LStream: TStream;
  LTmpStream: TStream;
begin
  // Try provided stream first
  LStream := R.ImageStream;

  if (LStream = nil) and FAutoDownloadFromURL and (R.ImageURL <> '') then
  begin
    // User hook first
    if Assigned(FOnDownloadStream) then
      LTmpStream := FOnDownloadStream(R.ImageURL)
    else
      LTmpStream := DefaultDownload(R.ImageURL);

    try
      Result := TImageResponseItemVCL.CreateFromStream(LTmpStream, R.MimeType, R.ImageURL);
    finally
      LTmpStream.Free; // we created LTmpStream; item copied its data already
    end;
    Exit;
  end;

  // If stream exists (or nil), construct item (nil is acceptable; bitmap stays empty)
  Result := TImageResponseItemVCL.CreateFromStream(LStream, R.MimeType, R.ImageURL);
end;

procedure TAIImageBindSource.SetResults(const AResults: TArray<IAIImageGenerationResult>);
var
  R: IAIImageGenerationResult;
  Item: TImageResponseItemVCL;
begin
  List.Clear;
  for R in AResults do
  begin
    Item := LoadItemFromResult(R);
    List.Add(Item);
  end;
  Active := True; // let LiveBindings know data is ready
end;

end.
