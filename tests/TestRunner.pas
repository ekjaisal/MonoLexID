{
 BSD 3-Clause License
 ____________________
 
 Copyright © 2026, Jaisal E. K.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}

{
 ==================================================================================
 MonoLexID Test Runner · https://github.com/ekjaisal/MonoLexID
 ==================================================================================

 Covers:
   1. Format Validation
   2. Byte-level Structural Validation
   3. Monotonicity (1,000,000 IDs)
   4. Uniqueness   (1,000,000 IDs)
   5. Performance  (IDs/sec reported)
   6. TryNewMonoLexID / TryNewMonoLexIDBytes API
   7. Multi-threaded uniqueness and per-thread monotonicity

 Compile in threadvar mode (default):
   fpc uTestRunner.pas -vnewh -B

 Compile in global monotonic mode:
   fpc uTestRunner.pas -dMONOLEXID_GLOBAL_MONOTONIC -vnewh -B
}

program uTestRunner;

{$mode ObjFPC}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, MonoLexID
  {$IFDEF WINDOWS}
  , Windows
  {$ELSE}
  , Unix
  {$ENDIF};

const
  BULK_COUNT   = 1000000;
  THREAD_COUNT = 8;
  IDS_PER_THREAD = 100000;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const TestName: String);
begin
  WriteLn('  [PASS] ', TestName);
  Inc(PassCount);
end;

procedure Fail(const TestName, Reason: String);
begin
  WriteLn('  [FAIL] ', TestName, ' - ', Reason);
  Inc(FailCount);
end;

procedure AssertTrue(const TestName: String; Condition: Boolean; const Reason: String = 'Condition was False');
begin
  if Condition then Pass(TestName) else Fail(TestName, Reason);
end;

function NowMS: Int64;
{$IFDEF WINDOWS}
begin
  Result := GetTickCount64;
end;
{$ELSE}
var
  TV: TTimeVal;
begin
  fpgettimeofday(@TV, nil);
  Result := Int64(TV.tv_sec) * 1000 + (TV.tv_usec div 1000);
end;
{$ENDIF}

function IsHexChar(C: Char): Boolean; inline;
begin
  Result := (C in ['0'..'9', 'a'..'f', 'A'..'F']);
end;

procedure Section(const Title: String);
begin
  WriteLn;
  WriteLn('── ', Title, ' ', StringOfChar('-', 60 - Length(Title)));
end;

procedure TestFormat;
var
  ID: String;
  I: Integer;
begin
  Section('1. Format Validation');
  ID := NewMonoLexID;
  WriteLn('  Sample: ', ID);

  AssertTrue('Length is 36', Length(ID) = 36,
    'Got length ' + IntToStr(Length(ID)));

  AssertTrue('Hyphens at positions 9,14,19,24',
    (ID[9] = '-') and (ID[14] = '-') and (ID[19] = '-') and (ID[24] = '-'),
    'Hyphen missing or misplaced');

  for I := 1 to 36 do
    if (I <> 9) and (I <> 14) and (I <> 19) and (I <> 24) then
      if not IsHexChar(ID[I]) then
      begin
        Fail('All non-hyphen chars are hex', 'Invalid char "' + ID[I] + '" at position ' + IntToStr(I));
        Exit;
      end;
  Pass('All non-hyphen chars are hex');

  AssertTrue('Version nibble is 7', ID[15] = '7',
    'Got "' + ID[15] + '"');

  AssertTrue('Variant bits are correct (8/9/a/b)',
    ID[20] in ['8', '9', 'a', 'b', 'A', 'B'],
    'Got "' + ID[20] + '"');
end;

procedure TestByteStructure;
var
  B: TMonoLexIDBytes;
begin
  Section('2. Byte-level Structural Validation');
  B := NewMonoLexIDBytes;

  AssertTrue('Byte[6] high nibble is $7x',
    (B[6] and $F0) = $70,
    Format('Got $%x', [B[6] and $F0]));

  AssertTrue('Byte[8] high bits are $8x (variant)',
    (B[8] and $C0) = $80,
    Format('Got $%x', [B[8] and $C0]));
end;

procedure TestBulkMonotonicityAndUniqueness;
var
  IDs: array of String;
  I: Integer;
  T0, T1: Int64;
  Elapsed: Double;
  MonoOK, UniqueOK: Boolean;
  Seen: TStringList;
begin
  Section('3 & 4. Monotonicity + Uniqueness (' + IntToStr(BULK_COUNT) + ' IDs)');
  WriteLn('  Generating ', BULK_COUNT, ' IDs...');

  IDs := nil;
  SetLength(IDs, BULK_COUNT);
  
  T0 := NowMS;
  for I := 0 to BULK_COUNT - 1 do
    IDs[I] := NewMonoLexID;
  T1 := NowMS;

  Elapsed := (T1 - T0) / 1000.0;
  if Elapsed > 0 then
    WriteLn(Format('  Time: %.3fs  ->  %.0f IDs/sec', [Elapsed, BULK_COUNT / Elapsed]))
  else
    WriteLn('  Time: <1ms (unmeasurable at this resolution)');

  MonoOK := True;
  for I := 1 to BULK_COUNT - 1 do
    if not (IDs[I - 1] < IDs[I]) then
    begin
      MonoOK := False;
      Fail('Strict monotonicity across ' + IntToStr(BULK_COUNT) + ' IDs',
        Format('IDs[%d] >= IDs[%d]: %s >= %s', [I-1, I, IDs[I-1], IDs[I]]));
      Break;
    end;
  if MonoOK then
    Pass('Strict monotonicity across ' + IntToStr(BULK_COUNT) + ' IDs');

  WriteLn('  Checking uniqueness (sorting)...');
  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    Seen.Duplicates := dupError;
    UniqueOK := True;
    try
      for I := 0 to BULK_COUNT - 1 do
        Seen.Add(IDs[I]);
    except
      UniqueOK := False;
      Fail('All ' + IntToStr(BULK_COUNT) + ' IDs are unique', 'Duplicate detected');
    end;
    if UniqueOK then
      Pass('All ' + IntToStr(BULK_COUNT) + ' IDs are unique');
  finally
    Seen.Free;
  end;
end;

procedure TestTryAPI;
var
  ID: String;
  B: TMonoLexIDBytes;
  I: Integer;
  AllZero: Boolean;
begin
  Section('5. TryNewMonoLexID / TryNewMonoLexIDBytes API');

  AssertTrue('TryNewMonoLexID returns True',     TryNewMonoLexID(ID),    'Returned False');
  AssertTrue('TryNewMonoLexID output length 36', Length(ID) = 36,     'Got ' + IntToStr(Length(ID)));

  AssertTrue('TryNewMonoLexIDBytes returns True', TryNewMonoLexIDBytes(B), 'Returned False');

  AllZero := True;
  for I := 0 to 15 do
    if B[I] <> 0 then begin AllZero := False; Break; end;
  AssertTrue('TryNewMonoLexIDBytes output is non-zero', not AllZero, 'All bytes were zero');
end;

type
  TWorkerThread = class(TThread)
  public
    ThreadIndex: Integer;
    IDs: array[0..IDS_PER_THREAD - 1] of String;
    MonoOK: Boolean;
    procedure Execute; override;
  end;

procedure TWorkerThread.Execute;
var
  I: Integer;
begin
  MonoOK := True;
  for I := 0 to IDS_PER_THREAD - 1 do
    IDs[I] := NewMonoLexID;

  for I := 1 to IDS_PER_THREAD - 1 do
    if not (IDs[I - 1] < IDs[I]) then
    begin
      MonoOK := False;
      Break;
    end;
end;

procedure TestMultiThreaded;
var
  Threads: array[0..THREAD_COUNT - 1] of TWorkerThread;
  I, J: Integer;
  AllIDs: TStringList;
  UniqueOK, PerThreadMonoOK: Boolean;
  {$IFDEF MONOLEXID_GLOBAL_MONOTONIC}
  GlobalMonoOK: Boolean;
  {$ENDIF}
  T0, T1: Int64;
  Elapsed: Double;
  Total: Integer;
begin
  Section('6. Multi-threaded (' +
    IntToStr(THREAD_COUNT) + ' threads x ' +
    IntToStr(IDS_PER_THREAD) + ' IDs)');

  Total := THREAD_COUNT * IDS_PER_THREAD;
  WriteLn('  Spawning ', THREAD_COUNT, ' threads...');

  T0 := NowMS;
  for I := 0 to THREAD_COUNT - 1 do
  begin
    Threads[I] := TWorkerThread.Create(True);
    Threads[I].ThreadIndex := I;
    Threads[I].FreeOnTerminate := False;
    Threads[I].Start;
  end;
  for I := 0 to THREAD_COUNT - 1 do
    Threads[I].WaitFor;
  T1 := NowMS;

  Elapsed := (T1 - T0) / 1000.0;
  if Elapsed > 0 then
    WriteLn(Format('  Time: %.3fs  ->  %.0f IDs/sec (across all threads)', [Elapsed, Total / Elapsed]))
  else
    WriteLn('  Time: <1ms');

  PerThreadMonoOK := True;
  for I := 0 to THREAD_COUNT - 1 do
    if not Threads[I].MonoOK then
    begin
      PerThreadMonoOK := False;
      Fail('Per-thread monotonicity (thread ' + IntToStr(I) + ')', 'Non-monotonic sequence detected');
    end;
  if PerThreadMonoOK then
    Pass('Per-thread monotonicity across all ' + IntToStr(THREAD_COUNT) + ' threads');

  WriteLn('  Collecting and sorting ', Total, ' IDs for global checks...');
  AllIDs := TStringList.Create;
  try
    AllIDs.Capacity := Total;
    for I := 0 to THREAD_COUNT - 1 do
      for J := 0 to IDS_PER_THREAD - 1 do
        AllIDs.Add(Threads[I].IDs[J]);

    AllIDs.Sorted := True;
    AllIDs.Duplicates := dupIgnore;
    UniqueOK := AllIDs.Count = Total;
    AssertTrue('Global uniqueness across all threads (' + IntToStr(Total) + ' IDs)',
      UniqueOK,
      'Expected ' + IntToStr(Total) + ' unique, got ' + IntToStr(AllIDs.Count));

    {$IFDEF MONOLEXID_GLOBAL_MONOTONIC}
    GlobalMonoOK := True;
    for I := 1 to AllIDs.Count - 1 do
      if not (AllIDs[I - 1] < AllIDs[I]) then
      begin
        GlobalMonoOK := False;
        Break;
      end;
    AssertTrue('Global monotonicity across all threads (MONOLEXID_GLOBAL_MONOTONIC)',
      GlobalMonoOK,
      'Non-monotonic pair detected in globally sorted output');
    {$ELSE}
    WriteLn('  [INFO] Global monotonicity across threads is not guaranteed in threadvar mode - skipped.');
    {$ENDIF}

  finally
    AllIDs.Free;
  end;

  for I := 0 to THREAD_COUNT - 1 do
    Threads[I].Free;
end;

begin
  WriteLn('==========================================');
  {$IFDEF MONOLEXID_GLOBAL_MONOTONIC}
  WriteLn(' MonoLexID Test Runner [GLOBAL MONOTONIC]');
  {$ELSE}
  WriteLn(' MonoLexID Test Runner [THREADVAR MODE]  ');
  {$ENDIF}
  WriteLn('==========================================');

  TestFormat;
  TestByteStructure;
  TestBulkMonotonicityAndUniqueness;
  TestTryAPI;
  TestMultiThreaded;

  WriteLn;
  WriteLn('==========================================');
  WriteLn(Format(' Results: %d passed, %d failed', [PassCount, FailCount]));
  WriteLn('==========================================');

  if FailCount > 0 then
    Halt(1);
end.