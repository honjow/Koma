# Reader processing native dependency

`reader-enhancement-640f310.har` is built from the existing independent
[erosTeam/reader-enhancement](https://github.com/erosTeam/reader-enhancement/tree/640f310ee7addb0c4eb46e55b1f7181017a653df)
commit `640f310ee7addb0c4eb46e55b1f7181017a653df`, the same dependency used by NextE.
It contains the arm64-v8a ncnn/MindSpore image-processing NAPI library and OpenMP runtime.
Model weights are not bundled; installation is an explicit Reader model action.

The host detector/model/queue adapters are ported from NextE commit
`59a7a67970b4d4ac104eaa44efbd7c5e0fe12857`. Koma supplies its own preferences,
public model download transport, source-file leases and export URI. No NextE
application settings, accounts or credentials are imported.

Built from the existing clean checkout with API26 SDK and `assembleHar`,
module `reader_enhancement@default`, product `default`, buildMode `release`.
No NextE application modules or account state are included.

HAR SHA-256: `a386bb0db94f3f6335ffd521be7a08865379ab2836b4ca150315c6826ce9458f`.
MIT, ncnn BSD-3-Clause and OpenMP notices are retained in `reader-enhancement-licenses/`.
