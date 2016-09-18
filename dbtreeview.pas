{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit DBTreeView;

interface

uses
  DBStringTree, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('DBStringTree', @DBStringTree.Register);
end;

initialization
  RegisterPackage('DBTreeView', @Register);
end.
