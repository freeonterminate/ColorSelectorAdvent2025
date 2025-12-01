{*******************************************************}
{                                                       }
{                Delphi Runtime Library                 }
{                                                       }
{ Copyright(c) 2025 Embarcadero Technologies, Inc.      }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit SmartCoreAI.Driver.Registry;

interface

uses
  System.Classes, System.Generics.Collections, SmartCoreAI.Types;

type
  TAIDriverFactory = reference to function(AOwner: TComponent): IAIDriver;

  TAIDriverMetadata = record
    Name: string;
    DisplayName: string;
    Description: string;
    Category: string;
    Factory: TAIDriverFactory;
  end;

  TAIDriverClass = class of TAIDriver;

  TAIDriverRegistry = class
  private
    class var FRegistry: TDictionary<string, TAIDriverMetadata>;
  public
    class constructor Create;
    class destructor Destroy;

    // Overloads for registration
    class procedure RegisterDriver(const AName, ADisplayName, ADescription, ACategory: string; const AFactory: TAIDriverFactory);
    class procedure RegisterDriverClass(const AName, ADisplayName, ADescription, ACategory: string; AClass: TAIDriverClass);

    // Driver creation
    class function CreateDriver(const AName: string; AOwner: TComponent): IAIDriver;

    // Metadata access
    class function RegisteredDrivers: TArray<string>;
    class function GetDriverMetadata(const AName: string): TAIDriverMetadata;
    class function GetAllMetadata: TArray<TAIDriverMetadata>;
  end;

implementation

uses
  System.SysUtils, SmartCoreAI.Consts, SmartCoreAI.Exceptions;

{ TAIDriverRegistry }

class constructor TAIDriverRegistry.Create;
begin
  FRegistry := TDictionary<string, TAIDriverMetadata>.Create;
end;

class destructor TAIDriverRegistry.Destroy;
begin
  FRegistry.Free;
end;

class procedure TAIDriverRegistry.RegisterDriver(const AName, ADisplayName, ADescription, ACategory: string; const AFactory: TAIDriverFactory);
var
  LMeta: TAIDriverMetadata;
begin
  if AName.IsEmpty then
    raise EAIRegisterException.Create(cAIDriverEmptyNameError);

  if not Assigned(AFactory) then
    raise EAIRegisterException.Create(cAI_Msg_NilFactoryParam);

  LMeta.Name := AName;
  LMeta.DisplayName := ADisplayName;
  LMeta.Description := ADescription;
  LMeta.Category := ACategory;
  LMeta.Factory := AFactory;
  FRegistry.AddOrSetValue(AName.ToLower, LMeta);
end;

class procedure TAIDriverRegistry.RegisterDriverClass(const AName, ADisplayName, ADescription, ACategory: string; AClass: TAIDriverClass);
begin
  if not Assigned(AClass) then
    raise EAIRegisterException.Create(cAI_Msg_NilClassParam);
  
  RegisterDriver(
    AName,
    ADisplayName,
    ADescription,
    ACategory,
    function(AOwner: TComponent): IAIDriver
    begin
      Result := AClass.Create(AOwner);
    end
  );
end;

class function TAIDriverRegistry.CreateDriver(const AName: string; AOwner: TComponent): IAIDriver;
var
  LMeta: TAIDriverMetadata;
begin
  if AName.IsEmpty then
    raise EAIRegisterException.Create(cAIDriverEmptyNameError);

  if not FRegistry.TryGetValue(AName.ToLower, LMeta) then
    raise EAIRegisterException.CreateFmt(cAIDriverNotRegesteredError, [AName]);
  Result := LMeta.Factory(AOwner);
end;

class function TAIDriverRegistry.RegisteredDrivers: TArray<string>;
begin
  Result := FRegistry.Keys.ToArray;
end;

class function TAIDriverRegistry.GetDriverMetadata(const AName: string): TAIDriverMetadata;
begin
  if AName.IsEmpty then
    raise EAIRegisterException.Create(cAIDriverEmptyNameError);

  if not FRegistry.TryGetValue(AName.ToLower, Result) then
    raise EAIRegisterException.CreateFmt(cAIDriverMetaDtaError, [AName]);
end;

class function TAIDriverRegistry.GetAllMetadata: TArray<TAIDriverMetadata>;
begin
  Result := FRegistry.Values.ToArray;
end;

end.

