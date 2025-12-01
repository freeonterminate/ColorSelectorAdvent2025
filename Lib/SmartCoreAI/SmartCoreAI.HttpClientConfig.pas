{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.HttpClientConfig;

{
  SmartCoreAI.HttpClientConfig
  ----------------------------
  Central place for creating THTTPClient instances with sane defaults and
  optional customization hooks.

  - TAIHttpClientCustomizer is a callback invoked to tweak a newly created
    THTTPClient (TLS, headers, proxy, timeouts, events, etc).
  - TAIHttpClientConfig.CreateClient applies defaults, then a process-wide
    global customizer (if any), and finally a per-call customizer.

  Notes
  -----
  - Ownership: CreateClient returns a new THTTPClient owned by the caller.
  - Order: Global customizer runs first; PerCall customizer runs last and can
    override any global settings.
  - Cancellation: If you're implementing cooperative cancellation, you may set
    Client.OnReceiveData in a customizer to flip AAbort based on your driver's
    cancellation token/state.
  - Threading: THTTPClient instances aren't generally shared across threads; prefer
    one client per request or per worker.
}

interface

uses
  System.SysUtils, System.Net.HttpClient, SmartCoreAI.Exceptions;

type
  /// <summary>
  ///   Procedure reference used to mutate a newly created THTTPClient
  ///   (e.g., TLS policy, proxy, headers, timeouts, event handlers).
  /// </summary>
  /// <remarks>
  ///   Typical uses:
  ///   - Set SecureProtocols, ProxySettings, ConnectionTimeout/ResponseTimeout.
  ///   - Assign event handlers like OnReceiveData for cooperative cancellation.
  ///   - Adjust ProtocolVersion (when available in the RTL).
  /// </remarks>
  TAIHttpClientCustomizer = reference to procedure(const Client: THTTPClient);

  /// <summary>
  ///   HTTP client factory with an optional global customization pipeline.
  /// </summary>
  /// <remarks>
  ///   Defaults are applied first (from SmartCoreAI.Consts), then the global
  ///   customizer (if set), then the per-call customizer (if provided).
  ///   If any customizer raises, the client is freed and an EAIConfigException is raised.
  /// </remarks>
  TAIHttpClientConfig = record
  private
    class var FGlobalCustomizer: TAIHttpClientCustomizer;
  public
    /// <summary>
    ///   Sets an optional process-wide customizer applied to every client creation.
    /// </summary>
    /// <param name="Customizer">
    ///   Callback that configures a newly created client. Pass nil to clear.
    /// </param>
    /// <remarks>
    ///   Safe to set during application startup. Changing this later only affects
    ///   clients created after the change.
    /// </remarks>
    class procedure SetGlobalCustomizer(const Customizer: TAIHttpClientCustomizer); static;

    /// <summary>
    ///   Creates a new THTTPClient and applies: defaults, global customizer, per-call customizer.
    /// </summary>
    /// <param name="PerCallCustomizer">
    ///   Optional callback applied after the global customizer to override settings.
    /// </param>
    /// <returns>
    ///   A newly created THTTPClient instance owned by the caller.
    /// </returns>
    /// <remarks>
    ///   Defaults include ConnectionTimeout, ResponseTimeout, and HandleRedirects.
    ///   Use a customizer to register OnReceiveData if you need cooperative cancellation.
    /// </remarks>
    class function CreateClient(const PerCallCustomizer: TAIHttpClientCustomizer = nil): THTTPClient; static;
  end;

implementation

uses
  SmartCoreAI.Consts;

{ TAIHttpClientConfig }

class function TAIHttpClientConfig.CreateClient(const PerCallCustomizer: TAIHttpClientCustomizer): THTTPClient;
begin
  Result := THTTPClient.Create;
  try
    // Baseline defaults (can be overridden by customizers)
    Result.ConnectionTimeout := cAIDefaultConnectionTimeout;
    Result.ResponseTimeout   := cAIDefaultResponseTimeout;
    Result.HandleRedirects   := cAIDefaultHandleRedirects;

    if Assigned(FGlobalCustomizer) then
      FGlobalCustomizer(Result);

    if Assigned(PerCallCustomizer) then
      PerCallCustomizer(Result);

  except on E: Exception do
    begin
      Result.Free;
      raise EAIConfigException.Create(E.Message);
    end;
  end;
end;

class procedure TAIHttpClientConfig.SetGlobalCustomizer(const Customizer: TAIHttpClientCustomizer);
begin
  FGlobalCustomizer := Customizer;
end;

(* Example things you can set in a customizer

  Option A (global baseline for everything):

    TAIHttpClientConfig.SetGlobalCustomizer(
    procedure(const C: THTTPClient)
    begin
      // TLS policy
      C.SecureProtocols := [THTTPSecureProtocol.TLS12, THTTPSecureProtocol.TLS13];

      // HTTP version (depends on RTL)
      {$IF Declared(THTTPProtocolVersion)}
      C.ProtocolVersion := THTTPProtocolVersion.HTTP_2_0;
      {$ENDIF}
      // (older RTL may expose C.UseHTTP2 := True)

      // Proxy (adjust to your RTL)
      var P := C.ProxySettings;
      P.Host := 'proxy.company.local';
      P.Port := 8080;
      P.UserName := 'svc_user';
      P.Password := '***';
      C.ProxySettings := P;

      // Timeouts (override if needed)
      C.ConnectionTimeout := 30000;
      C.ResponseTimeout   := 90000;
    end);


  Option B (per-connection override):

    AIConnection1.HttpClientCustomizer :=
    procedure(const C: THTTPClient)
    var P: TProxySettings;
    begin
      {$IF Declared(THTTPProtocolVersion)}
      C.ProtocolVersion := THTTPProtocolVersion.HTTP_1_1; // vendor needs 1.1
      {$IFEND}
      P := C.ProxySettings;
      P.Host := 'eu-proxy.vendor.local';
      P.Port := 8080;
      C.ProxySettings := P;
      C.ResponseTimeout := 180000;
    end;

*)

end.
