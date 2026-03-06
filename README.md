# MonoLexID

<a href="https://github.com/ekjaisal/MonoLexID/releases"><img height=20 alt="GitHub Release" src="https://img.shields.io/github/v/release/ekjaisal/MonoLexID?color=66023C&label=Release&labelColor=141414&style=flat-square&logo=github&logoColor=F5F3EF&logoWidth=11"></a> <a href="https://github.com/ekjaisal/MonoLexID/blob/main/LICENSE"><img height=20 alt="License: BSD-3-Clause" src="https://img.shields.io/badge/License-BSD_3--Clause-66023C?style=flat-square&labelColor=141414&logoColor=F5F3EF&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI0Y1RjNFRiI+PHBhdGggZD0iTTE0IDJINmMtMS4xIDAtMiAuOS0yIDJ2MTZjMCAxLjEuOSAyIDIgMmgxMmMxLjEgMCAyLS45IDItMlY4bC02LTZ6bTQgMThINlY0aDd2NWg1djExeiIvPjwvc3ZnPg=="></a> <a href="https://github.com/ekjaisal/MonoLexID/stargazers"><img height=20 alt="GitHub Stars" src="https://img.shields.io/github/stars/ekjaisal/MonoLexID?color=66023C&style=flat-square&labelColor=141414&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI0Y1RjNFRiI+PHBhdGggZD0iTTEyIDJsMy4wOSA2LjI2TDIyIDkuMjdsLTUgNC44N2wxLjE4IDYuODhMMTIgMTcuNzdsLTYuMTggMy4yNUw3IDE0LjE0IDIgOS4yN2w2LjkxLTEuMDFMMTIgMnoiLz48L3N2Zz4=&logoColor=F5F3EF&label=Stars"></a> [![Build](https://img.shields.io/github/actions/workflow/status/ekjaisal/MonoLexID/build.yml?branch=main&style=flat-square&color=66023C&labelColor=141414&logo=githubactions&logoColor=F5F3EF&label=Build)](https://github.com/ekjaisal/MonoLexID/actions)

MonoLexID is a time-ordered and sortable Universally Unique Identifier (UUID) generator for Object Pascal (Lazarus/Free Pascal), producing identifiers structurally compatible with the [RFC 9562 UUIDv7](https://www.rfc-editor.org/info/rfc9562) layout while privileging intra-millisecond monotonicity.

## Generation Policy

* **Lexicographic Monotonicity:** Identifiers are time-ordered at millisecond precision, ensuring natural sequential sorting, preventing index fragmentation and optimising database insertion performance.

* **Time Integrity:** The generator privileges chronological truth (clock-dependent). Should the system exhaust the sequence counter (4,096 allocations per millisecond) or detect a retrograde clock shift, generation is suspended via a CPU spin-wait loop. It yields (pauses) until physical time advances, so that identifiers are not generated with a fictitious-future time.

* **Cryptographic Uniqueness:** To preclude collisions in distributed environments, the remainder of the string payload is populated using OS-native, cryptographically secure pseudorandom number generators to minimise collision risk.

## Structure

MonoLexID generates a 36-character string (`xxxxxxxx-xxxx-7xxx-xxxx-xxxxxxxxxxxx`), which breaks down as follows:

* **Chars 1-8:** UNIX Timestamp in Milliseconds (Part 1)
* **Char 9:** Hyphen `-`
* **Chars 10-13:** UNIX Timestamp in Milliseconds (Part 2)
* **Char 14:** Hyphen `-`
* **Chars 15-18:** Version Identifier (`7`) + 12-bit Sequence Counter
* **Char 19:** Hyphen `-`
* **Chars 20-23:** Variant Identifier (`8`, `9`, `a`, or `b`) + Random Data
* **Char 24:** Hyphen `-`
* **Chars 25-36:** Secure Random Data

## Usage

MonoLexID is contained entirely within a single unit with no external dependencies. To integrate it, download the latest version from the [Releases](https://github.com/ekjaisal/MonoLexID/releases) page, include `MonoLexID.pas` in the project directory, and add it to the `uses` clause.

To generate a standard 36-character string format:

```pascal
uses
  MonoLexID;

var
  NewID: String;
begin
  NewID := NewMonoLexID; 
end;
```

Alternatively, to retrieve the raw 16-byte array:

```pascal
uses
  MonoLexID;

var
  RawBytes: TMonoLexIDBytes;
begin
  RawBytes := NewMonoLexIDBytes;
end;
```

### Thread Safety Configuration

* MonoLexID uses `threadvar` by default for state management, providing efficient thread-local monotonic generation. 

* If the application requires a globally monotonic sequence across multiple threads, it can be enabled by adding a `-dMONOLEXID_GLOBAL_MONOTONIC` flag in the project/compiler options or a `{$DEFINE MONOLEXID_GLOBAL_MONOTONIC}` directive at the very top of `MonoLexID.pas`.

### Error Handling

* Due to reliance on physical time and secure OS-level randomisation, generation may fail if system-level anomalies occur (such as a CSPRNG failure or severe clock instability that causes the generation loop to time out).

* MonoLexID provides safe ‘Try’ functions that will return `False` rather than raising an exception. When using these functions, callers must handle the `False` result, as an empty string will be passed downstream. Recommended use for critical applications:

```pascal
var
  NewID: String;
begin
  if TryNewMonoLexID(NewID) then
    WriteLn('Generated ID: ', NewID)
  else
    WriteLn('Critical Error: Could not generate a unique ID.');
end;
```

## Compatibility

MonoLexID compiles and functions under:
* Windows
* Linux/macOS (Requires `BaseUnix` and `/dev/urandom`)
* Free Pascal 3.2.2/Lazarus

## Acknowledgements

This project has benefitted significantly from Google [Gemini 3](https://gemini.google/about)’s assistance for ideation, code generation, and refactoring.

## License

This project is licensed under the BSD 3-Clause License and is provided as-is, without any warranties. Please see the [LICENSE](LICENSE) file for details.

[![Sponsor](https://img.shields.io/badge/Sponsor-66023C?style=flat-square&labelColor=141414&logo=githubsponsors&logoColor=F5F3EF)](https://sponsor.jaisal.in)