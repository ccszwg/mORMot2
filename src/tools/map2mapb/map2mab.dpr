/// Command Line .map to .mab Conversion Tool
// - this program is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
program map2mab;

{
  *****************************************************************************

  Command-Line Tool to Generate .mab files from existing .map files
  - if some .map file name is specified (you can use wild chars), it will
  process all those .map files, then create the corresponding .mab files
  - if some .exe/.dll file name is specified (you can use wild chars), will
  process all matching .exe/.dll files with an associated .map file, and will
  create the .mab files, then embedd the .mab content to the .exe/.dll
  - if no file name is specified, will process *.map into *.mab from the
  current directory
  - with FPC, will use DWARF debugging information instead of the `.map` file

  *****************************************************************************
}

{$I ..\..\mormot.defines.inc}

{$ifdef OSWINDOWS}
  {$apptype console}
  {$R ..\..\mormot.win.default.manifest.res}
{$endif OSWINDOWS}

uses
  {$I ..\..\mormot.uses.inc}
  classes,
  sysutils,
  mormot.core.base         in '..\..\core\mormot.core.base.pas',
  mormot.core.os           in '..\..\core\mormot.core.os.pas',
  mormot.core.text         in '..\..\core\mormot.core.text.pas',
  mormot.core.log          in '..\..\core\mormot.core.log.pas';

procedure Process(const FileName: TFileName);
var
  SR: TSearchRec;
  Path, FN: TFileName;
  Ext, Count: integer;
  AllOk: boolean;
begin
  AllOk := True;
  Ext := GetFileNameExtIndex(FileName, 'map,dbg,exe,dll,ocx,bpl');
  if (Ext >= 0) and
     (FindFirst(FileName, faAnyFile, SR) = 0) then
  try
    Path := ExtractFilePath(FileName);
    repeat
      FN := Path + SR.Name;
      if SearchRecValidFile(SR) then
      try
        // generate the mab content, maybe into the executable itself
        with TDebugFile.Create(FN, {MabCreate=}true) do
        try
          Count := length(Symbols);
          if not HasDebugInfo then
          begin
            WriteLn('Error: no Debug Info found on ', FN);
            AllOk := False;
          end
          else if Ext > 1 then // has debug info and is not a map/dbg
            SaveToExe(FN);     // embedd into the executable
        finally
          Free;
        end;
        // ensure the generated mab content is actually readable
        with TDebugFile.Create(FN, {MabCreate=}false) do
        try
          if Count <> length(Symbols) then
            raise ESynLogException.Create('Invalid .mab content');
        finally
          Free;
        end;
      except
        on E: Exception do
        begin
          // ignore any problem here: just print it and process next file
          WriteLn('Error: ', E.ClassName, ' ', E.Message);
          AllOk := False;
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end
  else
  begin
    WriteLn('Error: cant find any file to process matching: ', FileName);
    ExitCode := 2;
  end;
  if not AllOk then
    ExitCode := 1;
end;

begin
  if ParamCount > 0 then
    Process(ParamStr(1))
  else
    Process('*.map');
end.

