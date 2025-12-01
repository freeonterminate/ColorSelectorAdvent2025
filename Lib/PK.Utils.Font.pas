(*
 * Font Utility
 *
 * PLATFORMS
 *   Windows / macOS / iOS / Android
 *
 * LICENSE
 *   Copyright (c) 2022 HOSOKAWA Jun
 *   Released under the MIT license
 *   http://opensource.org/licenses/mit-license.php
 *
 * HISTROY
 *   2022/12/19 Version 1.0.0  First Release
 *
 * Programmed by HOSOKAWA Jun (twitter: @pik)
 *)

unit PK.Utils.Font;

interface

type
  TFontUtils = record
  public
    class function GetMonospaceFont: String; static;
  end;

implementation

{ TFontUtils }

class function TFontUtils.GetMonospaceFont: String;
begin
  {$IFDEF MSWINDOWS}
    Result := 'MS Gothic'; // ‰pŽš‚¾‚¯‚Å—Ç‚¢‚È‚ç Consolas
  {$ENDIF}
  {$IFDEF OSX}
    Result := 'Osaka-mono'; // ‰pŽš‚¾‚¯‚Å—Ç‚¢‚È‚ç Menlo
  {$ENDIF}
  {$IFDEF iOS}
    Result := 'Courier'
  {$ENDIF}
  {$IFDEF Android}
    Result := 'monospace';
  {$ENDIF}
end;

end.