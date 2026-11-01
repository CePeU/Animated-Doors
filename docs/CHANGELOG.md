---
title: Changelog
---

# Changelog

[User guide](index.md)

All documented Animated Doors releases are listed newest first. Historical dates
follow the archived release/test reports where available, otherwise repository
history. Entries describe the behavior of their release; later changes supersede
older options and data formats. Separate Foundry integration work is identified
explicitly and is not automatically installed with this mod.

## [1.0.1] / 2026-11-01

### Changed

- The module, exporter, diagnostics and user guide now report version 1.0.1.
- Distribution ZIPs contain runtime and public documentation from `docs/`.

### Removed

- Internal `project_docs/` files from distribution ZIPs; project documentation remains in the source repository alongside the already excluded examples.

## [0.15.10] / 2026-11-01

### Added

- A consolidated changelog and documentation conventions for maintaining the public Markdown user guide alongside user-facing changes.
- A project documentation index and release/documentation workflow.
### Changed

- Project plans, technical release notes, export contracts and validation reports use `project_docs/`; public documentation uses `docs/`.
- The user guide documents the native save dialog, direct metadata export, large-background handling and cancellation behavior introduced in 0.15.9.
- Distribution packaging includes Markdown from both documentation directories and checks that the user guide and changelog are present.
### Removed

- The `examples/` directory from distribution ZIPs. Fixtures remain in the source repository; packaging no longer requires them.

## [0.15.9] / 2026-11-01

### Added

- Direct UVTT export of walls, lights, portals and animated-door data when Include map image is OFF, supporting ordinary doors, crops, combined levels and separate files without map rendering.
### Changed

- Export uses the native OS save dialog; Linux follows the host's Zenity workflow, with a Godot-dialog fallback for engines without a native API.
- The cancellation button is labelled Cancel export / Export abbrechen. Native capture finishes before a cancelled result is discarded.
### Fixed

- Oversized PNG/JPG backgrounds are validated from encoded dimensions and container endings, bypassing Godot's 16,384-pixel image decoding limit while still checking UVTT grid dimensions.
- Metadata-only exports use current full-map or crop bounds instead of cached bounds from a previous render.
### Comments

- Oversized backgrounds do not undergo full pixel decoding during validation. A complete native render at 25,000 × 16,640 and interactive OS-dialog acceptance remain manual checks.

## [0.15.8] / 2026-10-22

### Changed

- Separate-level filenames start with the chosen save-name stem: `Test_.dd2vtt` produces `Test_Ground.dd2vtt` and `Test_Dach.dd2vtt`, with the same rule for PNG/JPG/WebP.
- Combined names are sanitized, length-limited and deduplicated without adding an implicit separator.
### Comments

- The reported missing Foundry background content was traced to an older image reference in the scene. The current UVTT and uploaded background contained the ordinary objects and paths; the exporter needed no render change.

## [0.15.7] / 2026-10-21

### Added

- A batch overwrite confirmation listing every existing level destination before rendering, including later files in the batch.
- Overwrite existing level files without asking in global Export defaults, initially OFF.
- A multi-file completion report listing every saved filename and full path.
### Fixed

- Cancelling the overwrite prompt preserves existing files and releases the pending batch; confirmation retains the planned filenames and export settings.
- Damaged German characters in additional export-default labels.
### Removed

- The redundant Export each level to a separate file action button; Multi file and the regular Export button cover that workflow.

## [0.15.6] / 2026-10-21

### Added

- Multi file / Mehrere Dateien directly below the output selector for separate bottom-to-top UVTT/PNG/JPG/WebP level exports with sanitized, unique filenames.
- Shared `multi_file`, `map_name` and UTC `export_timestamp` metadata under `Levels`; separate UVTT files contain only their own map.
- Dedicated global Export defaults and an Additional export defaults dialog for native and other-module controls, accessible with Export closed.
### Changed

- Defaults retain unavailable module settings, identify format choices by name and use stable paths for unnamed controls.
- Export controls/defaults support English and German, with automatic language detection from Dungeondraft preferences and original saved option values retained behind translations.

## [0.15.5] / 2026-10-20

### Fixed

- Export controls extending beyond the native dialog background. Minimum width/height now follow complete content and margins, including localization, other-module controls and larger fonts.
- Dialog sizing updates on opening and content changes, stays centered within the viewport when possible, and restores original sizing on uninstall.

## [0.15.4] / 2026-10-20

### Added

- An independent per-level export checkbox with undo/redo and map persistence; new and existing levels default to included.
- Drag insertion markers between complete two-row level groups.
### Changed

- Included levels export bottom-to-top, with the lowest at the UVTT root and higher levels consecutively numbered without gaps.
- Single-level export ignores inclusion flags. Excluding every level reports an error before writing; SoftShadows controls remain independent.

## [0.15.3] / 2026-10-20

### Changed

- Bottom/Top captions use the down/up layer icons, included in the distribution.
### Fixed

- Elevation inputs are hidden whenever their level or any Levels ancestor is collapsed, keeping the expand control accessible across repeated folding.

## [0.15.2] / 2026-10-20

### Fixed

- The native hover drag handle is hidden on the non-draggable Bottom/Top detail row while header dragging and grouped reordering remain available.

## [0.15.1] / 2026-10-20

### Changed

- Each level has its native header plus a separate Bottom/Top input line, preserving space for names and switch/enable buttons.
### Fixed

- Reordering moves both lines together; dropping on an input line resolves to its owning level and preserves native tree ordering.

## [0.15.0] / 2026-10-20

### Added

- Signed Bottom/Top elevation inputs in Level Settings, following levels through rename/reorder with undo/redo and persistence through both settings backends.
- `level_name`, `bottom` and `top` in root and additional UVTT levels. A numeric trailing `[bottom,top]` can initialize values; other levels default to zero and export rejects Top below Bottom.
### Changed

- UVTT schema 10 separates readable texture stems, unprefixed hashes, hashed filenames and extensions; Foundry target animation gains texture hash and extension fields.
- New level-elevation components use schema 1; saved door/map schemas remain 6.
### Fixed

- Native Export mode heading, localized background heading and fallback format-row restoration.
- Completion counts include object-source animated doors, ordinary native portals and totals across all exported levels.

## [0.14.1] / 2026-10-19

### Fixed

- Opening Export before using the Select tool no longer dereferences its lazily created transform box. Existing stale selection handles are still hidden safely.

## [0.14.0] / 2026-10-19

### Added

- Include map image, initially ON; OFF writes an empty image string while retaining map data.
- Export levels, initially OFF, with complete level envelopes and one validated combined write; cleanup restores source level and artwork on success, failure or cancellation.
- Persistent export defaults for standalone and _Lib settings, shared with fallback export controls.
### Changed

- Baking and embedding controls are ON/OFF switches with reordered UVTT options.
- Slide markers use a triangle and circle; opened-door guides default to configurable white.
### Fixed

- JPG background support in UVTT, including native callback and validation.

## [0.13.0] / 2026-10-13

### Added

- Play animation and Ctrl+Shift+D for one opening/return of selected declared doors, including all five animation types and double-door previews. _Lib supports shortcut rebinding.
- Map-persisted preview duration, initially 750 ms, with extension-dependent ascend/descend timing and component schema 6.
- UVTT schema 9 with only required finished artwork, grouped source origins/transformations, canonical names, exact placement and compiled Foundry target settings.
### Changed

- Final artwork is cropped, oriented and tinted before a single final encoding. Eligible unchanged PNG/WebP source bytes are verified and preserved exactly.
- Final-byte hashes deduplicate assets; package aliases and derivations retain source identity, and filename collisions select full-hash alternatives.
- Missing export-dialog compatibility preferences initialize from the current Dungeondraft version; explicit empty or existing values remain intentional choices.
- The enabled right-click setting uses a capable live Unofficial Patch menu or automatically falls back for eligible selections; disabling it leaves independent shortcuts available.
### Fixed

- Preview restores source artwork and selection on completion, Escape, selection/level changes, artwork changes, save, export and shutdown without saving a temporary pose.
### Removed

- Separate JPEG door output; unsupported original formats use PNG. Background/raster JPEG remains available.
- Embedded unused source/intermediate images, obsolete custom export-schema adapters and the extra menu-fallback consent dialog.
### Comments

- Re-encoded WebP uses quality 1.0 but can still be lossy; PNG is the pixel-exact option. The separate Foundry importer still targets schema 8 and needs an independent update.

## [0.12.2] / 2026-10-02

### Added

- A persistent Enable Animated Doors right-click menu setting, initially ON, independent of Shift+D.
- Runtime capability probing of the active Unofficial Patch handler rather than relying on its unchanged API version number.
### Changed

- Capable Patch handlers receive nested animation/type/state submenus. Older handlers use a session consent dialog for the full fallback; without Patch, the fallback works automatically.
- Menu suppression is limited to eligible Select-tool gestures and cleaned up when disabled or unloaded.
### Removed

- The category replacement menus introduced in 0.12.1.

## [0.12.1] / 2026-10-01

### Fixed

- Offset arrows, wheel and up/down keys step in whole map pixels while preserving fractional values and committing typed text first, in panel, defaults and both settings backends.
- Older Unofficial Patch handlers with only one submenu level open an Animated Doors category menu for animation type, door type and state, bound to the original selection and level.

## [0.12.0] / 2026-09-30

### Added

- Reusable last-used crop templates per asset, region/frame and axis, shared across settings backends, with a reset action that leaves existing instances unchanged.
- Validated temporary/backup writes for the template library and safe handling of corrupt/future files, changed dimensions and procedural textures.
### Changed

- Offsets at 256 map pixels/grid convert to inward-rounded source-pixel crops; remaining artwork retains native resolution and cross-axis dimensions without resampling.
- Fractional offsets and values above 253 are supported; preview and export use the same effective bounds.
- Double doors use two copies of the complete prepared image instead of a half-texture and symmetry restriction.
- Fresh-install defaults use automatic language, editing enabled, visible-content axis detection, height fallback, a red hinge marker and revised root menu order; stored preferences are retained.
- UVTT schema 8 and component schema 5 retain original offsets/crop recipes and migrate existing saved declarations. The separate commented importer reads prepared schema-8 PNGs without reapplying crops.
### Fixed

- Native image exports suppress and restore selection, transform boxes and hover highlights even when bypassing the Animated Doors file chooser.
- Ascend/descend guide arrows account for the selected image axis and placement rotation.

## [0.11.0] / 2026-09-28

### Added

- Visible-content axis detection using texture alpha bounds, regions/frames and placed scale, with cached analysis and fallback for near-square or indeterminate artwork.
- UVTT schema 7 prepared PNGs, source/pixel hashes, transformation recipes, directed grid endpoints and precomputed thickness parameters.
- Separate commented Foundry integration for schemas 4–7, with verified reusable assets, a world asset registry, wall instance metadata, door states and animation-aware map merging.
### Changed

- Panel declaration defaults are collapsible and initially closed. Once assigned, a concrete door axis is preserved.
### Fixed

- Native portal/object hover highlights are suppressed before capture and restored separately from selection and transform controls.
### Comments

- This historical release's native double-door profile required symmetric artwork; 0.12.0 superseded that restriction.

## [0.10.0] / 2026-09-27

### Added

- A per-export Door asset format selector in compact and fallback UVTT dialogs, independent of background format and hidden/disabled where irrelevant.
- Closed, Open and Locked door states in selected-door controls, map/global defaults and configurable context submenus, with multi-selection, persistence and undo/redo.
- Configurable locked-preview color, initially red, plus distinct vertical movement arrows.
- Grouped global settings and full global panel defaults including offsets; changes initialize new declarations without rewriting existing doors or unrelated map defaults.
- Simultaneous hinges, type outlines and guides for every selected declared door, with explicit mixed values.
### Changed

- UVTT schema 6 adds closed/locked flags; component schema 4 persists state and initializes old declarations as closed.
### Fixed

- Slide previews move toward the chosen hinge; double-slide leaves move outward.
- Native transform boxes, including orphaned boxes, are hidden during capture and restored with selection afterwards.
### Removed

- The global asset-format selector introduced in 0.9.0, replaced by the export-dialog choice.

## [0.9.0] / 2026-09-27

### Added

- Global Original/PNG/WebP/JPEG door asset format choices with native encoding and transparency caveats.
- UVTT schema 5 image fields, structured source descriptors, byte hashes, filename stems and explicit texture axes for importers.
- Automatic language following Dungeondraft's supported German/English locale while preserving saved explicit language choices.
- A separate commented Foundry geometry correction for object-source artwork, with formulas and documented limits.
### Fixed

- _Lib color-editor startup addresses the actual nested ColorPickerButton rather than the surrounding settings dialog.
- Selected doors show their type-colored outline separately from the blue selection outline.

## [0.8.0] / 2026-09-26

### Added

- Hex color fields, previews and Choose color dialogs with Apply/Cancel, including alpha and persistence in both settings backends.
- Configurable normal-door, secret-door and window outline colors, initially yellow, red and white.
- Explicit animation flags on all native portals and ordinary-portal counts in export completion messages.
### Changed

- German menu wording uses Animierte Türen.
- Selected-door extension edits remain separate from declaration defaults; removing and redeclaring a door uses current defaults, with undo restoring the old assignment.
### Fixed

- Initially preselected UVTT formats show embedding/background options when Export first opens.
- Capture clears/restores native selection on completion, failure or cancellation while respecting deleted objects, level changes and newer selections.

## [0.7.0] / 2026-09-25

### Added

- Nine independent overlay colors including transparency, persisted through _Lib and standalone settings.
- English/German JSON catalogs and a global Language selector for menus, settings and added export controls.
### Changed

- The standalone fallback menu opens with plain right-click for eligible Select-tool selections; compatible Patch menus remain shared.
- Offsets explicitly identify triangle/circle endpoints; extension terminology is Door extension / Türöffnung.
- Guides are drawn before endpoint symbols, double doors always show two axis plus signs, and list selection outlines appear above the overview.

## [0.6.0] / 2026-09-23

### Added

- Normal/secret door/window types; swing, slide, swivel, ascend and descend; double doors; extension 0–180 with a 90 reset; independent hinge offsets.
- Root Toggle Hinge/Toggle Swing commands, type submenus, double-door/amount actions and per-entry ordering/hiding with negative values allowed.
- Configurable movement symbols, arcs and offset guides; scrollable standalone global settings.
### Changed

- UVTT schema 4 adds nested animation/type/filename, numeric direction and 256-map-pixel offsets; component schema 3 migrates existing declarations and retains settings through copy/paste and history.
- Fixture exports cover all five animation types, varied types/extension/double-door settings and nonzero offsets.

## [0.5.0] / 2026-09-21

### Added

- Compact format selection and baking/embedding switches integrated into the native Export window, gated by exact Dungeondraft-version compatibility.
- Native copy/cut/paste carries independent animated-door settings to newly created object/free-portal instances while retaining unrelated clipboard data.
- The supplied transparent door icon.
### Changed

- UVTT defaults to path/hash asset references with optional embedded door PNGs; baking doors into the background writes ordinary UVTT without animation data and disables embedding.
- Panel order groups editing, defaults, selection, preview, overview, filters, list, Apply defaults and diagnostics.
- Active context choices use an `(a)` marker, mixed selections have no single active value, and axis labels are shorter.
### Fixed

- The save dialog retains the last edited/selected filename across directory refreshes and reopening, while permitting deliberate clearing.

## [0.4.0] / 2026-09-21

### Added

- Right-click list gestures for declaration, Shift+right-click hinge toggle and Ctrl+right-click swing toggle, affecting only the clicked row in one undo step.
- Independent ordering of declare/remove/submenu entries in the Patch menu.
- PNG/JPG/WebP raster exports without animated-door artwork, shadows or editor overlays, supporting maps with no declared doors.
- Standalone settings, native undo, layer names and map persistence without requiring _Lib; Show all shortcut rebinding through optional _Lib.
- Reference UVTT exports with source paths, SHA-256 identifiers and rendering recipes instead of embedded door images.
### Changed

- UVTT schema 3 centralizes animation instances; native portals retain only animation flags/links, while sequential instance IDs distinguish repeated artwork.
### Fixed

- Preview swing toggles both ways and synchronizes menu checkboxes and overview arcs.
- Save filenames survive directory navigation and follow the selected extension.

## [0.3.0] / 2026-09-20

### Added

- Unofficial Patch shared-context-menu integration with declare/remove root entries and Animated Doors submenu, while retaining a fallback menu.
- Automatic longer/shorter-side axis detection with a width/height fallback and placed nonuniform scale support.
- A global editing-on-startup preference.
- Single-click list highlights without changing tools, plus Show all animated doors / Shift+D for the current level independent of list filters and editing mode.
### Changed

- The global startup axis preference initializes the selector even for saved maps without changing existing declarations.
- The panel removes permanent instructional labels; operation messages remain visible and instructions move into documentation.

## [0.2.1] / 2026-09-19

### Added

- An editing enable switch, declaration filters for all/declared/undeclared artwork, colored list entries, a taller list and checkbox assignment.
- Double-click selects the native object while polling retains list selection until the editor selection changes.
### Changed

- The fallback door menu uses Shift+right-click; hinge/swing/preview require prior declaration instead of silently assigning artwork.
- Native object shadows are suppressed/restored with declared artwork; light occluders and LOS remain intact.
### Fixed

- Inactive ancestor materials no longer block export; supported native Object/CustomColors materials are recognized and baked while unsupported active effects report a specific error.
### Removed

- The application-wide default-layer setting/button. Existing map layer filters remain list-only.
### Comments

- The date uses the first repository snapshot containing this release; a separate publication date is not recorded.

## [0.2.0] / 2026-09-19

### Added

- Explicit declaration/removal for selected Object-tool assets and freestanding portals, with hinge, swing, axis and preview commands.
- Artwork-derived affine endpoints, object-aware persistence/history and diagnostic information for both source kinds.
### Changed

- Export collects all declared visible assets on the current level, independent of list layer filtering, with useful empty-result counts.
- UVTT schema 2 preserves native portal geometry and adds separate object-door records; existing schema-1 settings migrate without losing choices and future-schema data stays opaque.
### Fixed

- Ordinary object doors and doors outside one exact layer are no longer omitted by collection.
### Comments

- The date follows the archived feedback and first repository snapshot; an independent publication date is not recorded.
