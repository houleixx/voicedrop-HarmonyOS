# Share BottomSheet Design QA

- Reference and simulator captures were reviewed locally and are not stored in the repository.
- Device: `VoiceDrop_API22`, 1320 × 2856

## Checks

- Divider endpoints are aligned with the outer edges of the first and fourth icons. Runtime bounds: divider `[109,2360][1211,2364]`; first icon `[109,2006][305,2202]`; fourth icon `[1015,2006][1211,2202]`.
- The scrim extends behind the status bar while the sheet is presented.
- The sheet enters from the bottom over 260 ms with an ease-out curve.
- Dismiss and channel-selection paths move the sheet downward over 200 ms before removing it from the component tree.
- The original status bar color is restored after dismissal, including the book reader's distinct background.
- The sheet is absent from the runtime layout tree after dismissal.

No P0, P1, or P2 visual issues remain for the requested changes.

final result: passed
