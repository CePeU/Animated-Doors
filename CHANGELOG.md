# Animated Doors 0.15.8

Declare selected **objects or freestanding portals** as animated doors, choose
their hinge and swing, then export their artwork and animation settings inside a
`.dd2vtt` file. Uses GDScript compatible with **Godot 3.4**, targeting Dungeondraft
**1.2.0.1 Opulent Kirin**. **_Lib 1.2.2** and **Unofficial Patch** are optional.

0.15.8 prefixes every separate-level filename with the save dialog's filename
stem: `Test_.dd2vtt` produces `Test_Ground.dd2vtt` and `Test_Dach.dd2vtt`.
The combined filename is sanitized and made unique. See [changes](docs/changes-0.15.8.md).

0.15.7 removes the redundant separate-level export button. Multi-file exports
finish with a list of every saved path and ask before overwriting existing level
files. Global Export defaults can enable overwriting without asking.
See [changes](docs/changes-0.15.7.md).

0.15.6 ships the level batch exporter and export defaults. **Multi file** appears
directly below the export-format dropdown and before **Include map image**.
Animated Doors export controls support English/German, including automatic
Dungeondraft language detection and the additional defaults dialog.
See [changes](docs/changes-0.15.6.md).

0.15.5 fits the export dialog background to its full content, including added
mod controls and larger UI fonts. See [changes](docs/changes-0.15.5.md).

0.15.4 exports levels from bottom to top, adds a saved per-level export toggle,
and shows drag insertion markers between complete level groups. See [changes](docs/changes-0.15.4.md).

0.15.3 fixes elevation inputs covering the Levels expand button after folding.
Bottom/Top captions now use down/up layer icons. See [changes](docs/changes-0.15.3.md).

0.15.2 hides the native hover drag handle on the Bottom/Top line. Level headers remain draggable.

0.15.1 places Bottom/Top on a second line below each level header, preserving
space for its name and other mods' switch/enable buttons. Drag either level
header as usual; both lines stay together. See [changes](docs/changes-0.15.1.md).

0.15.0 adds per-level Bottom/Top inputs in Level Settings and exports each
level's name and elevation bounds. Completion messages again report animated
and ordinary portal counts, summed across exported levels. Schema 10 separates
Foundry texture stems, hashed names and extensions; see [changes](docs/changes-0.15.0.md).

0.14.1 fixes an export-window crash when the Select tool has not been used yet.
Dungeondraft creates its transform widget lazily; export now skips the native
hide call until that widget exists.

In 0.14.0, UVTT exports support PNG/JPG/WebP backgrounds, optional map images,
and all map levels in their Level Settings order. Export defaults and ON/OFF
switches work in both compact and fallback dialogs. Slide guides use a triangle
and circle; opened door previews default to white. See [0.14.0 changes](docs/changes-0.14.0.md).

In 0.13.0, UVTT schema 9 stores only required finished PNG/WebP artwork with
grouped source origins, canonical filenames and ready-to-use Foundry targets.
Unchanged source PNG/WebP bytes are preserved when eligible. The new panel
button/Ctrl+Shift+D animates selected artwork in Dungeondraft, opens and returns,
and restores the native selection and artwork. Preview duration is saved with
the map; component schema 6 migrates previous saved maps.

The right-click setting chooses the capable live Unofficial Patch menu or the
automatic fallback. Export-dialog compatibility initializes the current DD
version only when the saved preference is absent; explicit empty remains an
opt-out. Shift+D overview remains independent of menu enablement.

See [changes](docs/changes-0.15.0.md), [schema 10](docs/export-contract.md) and
[pending editor acceptance](docs/host-smoke-test.md). The separate existing
Foundry importer targets schema 8 and requires a later update for schema 10.

## Install or update

The export dialog now offers **Export each level to a separate file** for UVTT
and PNG/JPG/WebP. Enabled levels are written bottom-to-top into the selected
directory using the chosen filename stem followed by the level name, sanitized
and made unique. Separate UVTT files contain only
their own map; `Levels` holds `multi_file`, `map_name`, and a shared UTC
`export_timestamp`. Combined level exports carry the same metadata with
`multi_file: false`. Existing level destinations prompt for confirmation before
rendering. **Overwrite existing level files without asking** in global Export
defaults bypasses this prompt; it is OFF by default. Cancelling writes no files.
After a successful multi-file export, the completion report lists every saved
file with its full destination path, without door counts.

Under **Global settings > Export defaults**, configure Animated Doors defaults
and use **Additional export defaults** for the currently available native and
module export controls. Missing module preferences remain saved; format choices
are restored by name when available again. Defaults apply when opening Export.
Earlier successfully written files remain if a later level fails or is cancelled.

1. Close the map. Optionally enable `_Lib` 1.2.2 (ID `CreepyCre._Lib`).
2. Extract the ZIP's `AnimatedDoors` folder into your mods directory, replacing
   the old mod files. The path must be `mods/AnimatedDoors/mod.ddmod`.
3. Enable Animated Doors, then reopen a copied test map. It also runs without _Lib
   and without Unofficial Patch.

No Godot editor is required. HideLayers and ManageLayers are optional, not
dependencies. The package contains no commercial artwork or reference-mod code.

## Declare and edit a door

1. Place an Object-tool asset or freestanding Portal-tool asset.
2. Open **Settings > Animated Doors** and turn on **Enable animated door editing**.
   Its initial state comes from the mod's global Settings (on for fresh installations).
3. Use Dungeondraft's **Select tool** and select the asset. With Unofficial Patch's
   right-click API active, **right-click near the selection** and choose **Declare
   Animated Door** in its main menu. **Remove Animated Door assignment** is also
   in the main menu; hinge/swing/axis/preview are in the **Animated Doors** submenu.
   Without that API, **right-click** opens the fallback menu.
   Hinge/swing/axis commands unlock only after all selected eligible assets are
   declared. Multiple doors can be edited together.
   Active hinge/swing/axis choices and preview carry **(a)**; mixed property
   selections have no active marker. Context-menu axis labels use **Axis: image
   width/height**.
4. Choose **Hinge A/B**, **Swing left/right**, and **Door axis: image width/height**.
   Width uses the left/right edge midpoints of the source image; height uses its
   top/bottom edge midpoints. A uses a triangle, B a circle; both are blue by default.
   The endpoints follow the artwork when moved, rotated, scaled or mirrored.
5. A simple selection of a declared door shows its hinge and configured animation guide while
   editing is enabled. **Preview swing** toggles the arc. **Remove Animated Door assignment**
   returns the asset to ordinary export behavior. Edits support undo/redo.
6. Save the map normally. Declarations and settings are stored with it, both with
   and without _Lib. Native undo/redo is supported in either mode.

Wall-attached portals and nonsprite shapes are not supported. Enable **Double door** for Foundry's two-leaf animation. Fixed frames should remain separate assets.
Transparent padding affects the image-edge hinge positions.

## Animation settings

Choose **Door / Secret door / Window**, animation type **swing / slide / swivel /
ascend / descend**, and **Double door** in the panel. Defaults initialize newly
declared doors; selected-door controls change only the selection. **Door extension**
is an integer 0-180 (default 90); its **90** button resets it. Instance edits never change declaration defaults;
changing defaults never changes existing doors. Removal clears the instance's
animation settings; redeclaring it copies the current defaults. Undo restores the
previous declaration. Map saving retains defaults separately. Foundry derives animation strength;
90 means normal strength, not a rotation angle for every animation type.

**Hinge A (triangle) offset** and **Hinge B (circle) offset** are nonnegative
map pixels at 256 pixels/grid. Fractions are supported, including distances above
the old 253 limit. X cuts left/right, Y cuts top/bottom of the unrotated image.
The exporter converts to source pixels using the placed scale and rounds both
boundaries inward. Outside content is discarded; the remaining resolution and
cross-axis padding stay unchanged. No resampling to 256. Overlapping/empty crops
are rejected. The preview shows the same effective rounded endpoints.

Valid offset edits remember the last source-pixel crop per asset and axis in
`user://animated_doors_crop_templates.json`. New declarations resolve their axis
first, then load that template; a deliberate axis change loads the other one.
Different placed sizes reuse the same image content. Selection and map reload
preserve each instance. **Reset crop template** removes the reusable default for
the selected asset/axis and leaves current instances intact. Undo restores instance
settings; it does not undo the last-used template library. Regions/frames have
separate contexts; procedural images without paths have no reusable template.
Unreadable/future template files and changed source dimensions produce a status
message and fall back to normal defaults. Both _Lib and standalone use this store.

Swing shows the selected blue triangle/circle and the configured arc. Swivel
shows inward triangles and an orange central pivot. Slide has an outward triangle at A and a circle at B;
ascend adds a blue central square; descend points its triangles inward. A red
point marks the selected endpoint on the two-triangle symbols. Guides are
schematic: the actual artwork stays still, and vertical animations are symbolic.
Markers are drawn after preview lines. Every double door has two plus signs along
its axis, including when preview is off.

## Door list, layers and defaults

Open **Settings > Animated Doors** for the 400-pixel-high list. Choose **Declared
doors**, **All objects and portals**, or **Undeclared objects and portals**.
Declared entries are yellow; unassigned entries are blue and have a text label.
Map overview outlines indicate normal doors (yellow), secret doors (red), or
windows (white). All three colors are configurable. IDs distinguish overlapping instances. A single list click highlights the matching
artwork on the map without changing tools; multiple selected rows highlight all
their matching objects with a blue outline above the overview. This also works for undeclared objects and with editing off.
Use **Declared animated door** to assign/remove while editing is enabled. Double-click an
entry to switch to the native Select tool and select that object on the map.
The controls also follow eligible native selections. Mixed values are explicit.
While editing is enabled, right-click a list row to toggle its declaration.
Shift + right-click toggles A/B, and Ctrl + right-click toggles left/right.
Hinge/swing gestures require an existing declaration. Only the clicked row changes,
even in a multiple selection; each change is one undo step. Combined modifiers and
clicks in empty list space do nothing.

The layer selector **only filters this list**. It never assigns all assets on a
layer and never excludes a declared door from export. **All layers** is the initial
filter for new maps; saved maps keep their own browser filter. The application
default-layer setting and save-default button have been removed. A missing filter
layer displays as missing without blocking exports from other layers.

The panel order is editing, defaults, selected-door settings, preview, show-all,
layer and declaration filters, object list, Apply defaults, then diagnostics.
Map defaults supply hinge, swing and axis when declaring an asset. The button
**Apply defaults to selected doors** sits below the object list. It changes
selected declared doors in one undo step and is enabled when editing is on and
the selection consists of declared doors. Native copy/paste and cut/paste retain
declarations, hinge, swing and axis while assigning fresh native object IDs.
Changing a pasted door does not change its source. Newly placed assets start
unassigned; prefab declarations are not guaranteed by the clipboard integration.
Previously enabled 0.1.0
portal components remain assigned on upgrade, with width-axis hinges. Legacy
source-layer settings no longer restrict export. No user map is migrated on disk
until it is saved normally.

### Startup settings and automatic axes

With _Lib, use its global mod Settings. Without _Lib, use **Global settings** in
the Animated Doors panel and confirm with OK. The global settings offer five
default-axis choices:

- **Image width** or **image height**: use that source-image axis.
- **The longer side** or **the shorter side**: compare the artwork bounding
  rectangle's side lengths, including nonuniform scaling. Rotation and mirroring
  do not change which local image axis a side represents.
- **Visible artwork**: analyse nontransparent pixels in the selected frame or region.
  Resolve once at declaration; keep the saved choice afterwards. Visible side lengths
  within 5% are ambiguous. Transparent margins do not change exported image dimensions.
- **Axis fallback: image width/height**: choose the axis for square, near-square,
  missing or indeterminate dimensions. Near-square tolerance is 0.001% of the
  larger dimension; ambiguous full dimensions first try visible artwork. Invalid export geometry is still rejected during export.

The global axis choice initializes **Default axis** every time a map opens,
including existing maps. Change the panel dropdown for the current session.
Declaration and **Apply defaults** resolve automatic choices separately for each
asset and save width or height on that door. Existing declarations never change
merely because startup settings change; later resizing does not silently switch axes.

**Enable animated door editing on startup** determines the panel checkbox's
initial state. Toggling the panel checkbox affects the current session only.

### Language and overlay colors

Global Settings now offers **Language: Dungeondraft (automatic) / English / Deutsch** (automatic by default).
Automatic follows German or English host locales, with English fallback. Previously
saved explicit choices remain overrides until changed to automatic.
Save the settings to update the panel, context menus, global settings and added
export controls. **Door extension** is **Türöffnung** in German.

Choose separate colors for triangles, circles, squares, the door axis, swing
preview, hinge offset lines, hinge markers, the central pivot and list selection.
Normal-door, secret-door and window outlines have three additional color settings.
Enter `#RRGGBB` or `#AARRGGBB` in the text field, or click **Choose color...** and
**Apply**. Cancel discards the picker change. Save global settings to retain the
chosen colors. Colors include transparency and persist with or without _Lib. They affect
editor overlays only. See [language and color settings](docs/localization.md) for
JSON catalogs and translation scope.

### Door state, multiple selection and grouped settings

Choose **Closed**, **Open**, or **Locked** for defaults or selected doors. Locked
also means closed. The context menu offers the same choices under **Door State**,
with configurable ordering and hiding. Previous declarations default to Closed.
State edits support multi-selection and undo/redo; differing values show Mixed.
They do not rotate the original map artwork into an open pose.

Selected doors show their hinges, type outlines and movement guides together,
independently of Show-all. Slide guides move toward the selected hinge regardless
of left/right swing. Double slide leaves move outward. Locked motion guides use
**Locked door preview color**, red by default; ascend/descend have separate
direction arrows so the configurable center marker remains visible.

Global Settings has foldouts for **General settings**, **Panel defaults**,
**Overlay colors**, and **Menu order**, the last with submenu groups. Existing
flat preference keys remain compatible with both backends. The full panel
defaults (including offsets) are available globally. Changing them updates the
current map defaults and seeds new maps, without changing existing doors.
Saving unrelated settings preserves map-specific defaults. Saved maps retain
their defaults on reload, with the pre-existing startup axis preference exception.

### Play artwork animation

Use **Play animation** beside the movement-guide checkbox, or **Ctrl+Shift+D**.
With _Lib, remap/unbind **Play animated door preview** in its shortcut settings.
The action plays selected declared visible doors once, opening and returning,
without changing their saved state. Locked doors can be inspected too.

Swing rotates around the effective cropped hinge; swivel around the centre;
slide retracts towards the hinge by amount/90 of effective length. Ascend fades
artwork into a dark shadow; descend fades shadow into artwork. Double preview
renders two mirrored whole-image copies at half length and full thickness.

**Preview duration (ms)** sets one operation's base duration (default 750), saved
with this map and undoable. Ascend/descend use base*180/amount, with zero treated
as 180 for timing only: 0/180=>base, 90=>2*base, 45=>4*base. Other modes use base.
There is no repeat/hold. Escape, selection/level changes, moved artwork, save,
export and shutdown cancel and restore. Preview adds no UVTT timing or images.

### Door asset format

The UVTT dialog offers **Original format** (default), **PNG** and **WebP**.
Unsupported originals, including JPEG, use PNG; source metadata remains intact.
The selected format applies only to required finished door images. Crop,
material/tint and image-axis normalization precede final encoding; no source or
intermediate image is embedded merely for processing.

For unchanged full artwork in a matching format, actual original file bytes
are verified and copied. Otherwise the final pixels are encoded. WebP uses
quality 1.0; the installed native codec produces lossy VP8, so PNG is the
lossless pixel alternative. Unchanged WebP bytes remain exact originals.
Raster/background JPEG remains available.

This choice is independent of background format, appears in compact and legacy
Animated Doors UVTT export, and is disabled for baked UVTT/hidden for raster.
Reference exports keep the same final descriptors/hashes and omit only payloads.

### Show all doors

Toggle **Show all animated doors** or press **Shift+D** by default to display
outlines, hinge markers and swing arcs for every declared visible object/free
portal on the current map and level. Hidden layers, hidden objects and fully
transparent artwork are excluded. The browser's filters do not restrict this view.
It follows transforms and level/layer visibility changes during periodic refresh.

With _Lib, change or remove the binding in the mod Settings shortcuts entry
**Show all animated doors**. Without its InputMapApi, Shift+D remains available.
This view works independently of editing mode and leaves native selection unchanged.
Turning it off removes the overview; the normal selected-door preview can remain.
The shortcut ignores key repeats, text fields, export windows and blocking mod
dialogs. All mod overlays are hidden for export. Instructional text lives here
instead of occupying permanent space in the panel.

### Unofficial Patch compatibility

Optional mod ID: **Moulk.BugFixes**. The running handler is checked by a nested
menu normalization probe; old and hotfixed hosts can advertise the same API
version. **Enable Animated Doors right-click menu** chooses a usable shared
Patch menu or automatically uses the AD fallback for eligible selections.
There is no extra consent dialog. Off disables AD integration/fallback while
independent shortcuts and other menus remain available.

Five independent root entries provide declaration, removal, Toggle Hinge,
Toggle Swing and Animated Doors. Swing Type, Door Type and Door State are nested
inside Animated Doors; fallback exposes those categories directly. Double door
and Door extension work in both menus; crop offsets remain panel controls.
Registered providers/blockers are cleaned up when inactive or unloaded.

Every entry, including submenu parents and leaves, has a global **Menu order**
setting. Lower integers appear first within their fixed parent; **0 hides the
entry** (and a submenu parent's children). The three existing placement keys are
retained. Root values are API priorities relative to patch blocks (10, 20, ...60),
not absolute row numbers. Negative values are allowed. Changes apply immediately.
Toggle Hinge/Swing invert each selected declared instance in one undo step.

## Export

### Compact native dialog

**Export dialog compatibility** initializes the current Dungeondraft version
when the saved preference is absent. Saved values remain unchanged. An exact
match enables compact controls inside the native Export window; a deliberately
empty, different or unreadable version selects the legacy entries below.
This is the Dungeondraft product version, not the Godot engine version.

Choose **PNG**, **JPEG**, **WEBP**, or **Universal VTT** in the compact format
selector. Baking and asset embedding start **OFF**:

| Include animated doors in map image | Embed door assets in UVTT (Base64) | Result |
| --- | --- | --- |
| Off | Off | UVTT animation records with asset paths/hashes; doors absent from background |
| Off | On | UVTT animation records with embedded door images; doors absent from background |
| On | Disabled | Normal UVTT with doors in the background, no animation extension or asset payloads |

For raster formats, the first switch controls whether doors and their shadows
appear in the image; UVTT-only controls are hidden. UVTT offers a separate
**PNG/JPG/WebP background** choice and shows quality controls where relevant.
Formats from other mods remain available and use their own export handling.
The seven legacy Animated Doors entries are hidden while this integration is active.

With **Export levels OFF**, select the current source level. Use no overlay or
level comparison, and full-map or
rectangular-crop output at 1–300 PPI. Click **Export** and choose a filename.
Fixed 1080p output remains unsupported. Zero declared doors are allowed in this
mode. The name survives directory navigation, including after edits and saves.

**Include map image** defaults **ON**. OFF writes `image: ""`, retaining native
geometry and separate door assets. Baking is disabled while the map image is
omitted. **Door asset format** has its label to the left of its dropdown.

**Export levels** defaults **OFF**. ON exports the lowest included level in Level Settings
at the UVTT root and then the included levels above it under `Levels["1"]` through `Levels["n"]`,
in bottom-to-top display order. Excluded levels leave no gaps in the numbering.
Each entry is a complete regular UVTT export,
with its own image, resolution, lighting, LOS, portals and door metadata. Image,
baking, embedding and asset-format choices apply to every level. The original
editor/export source is restored; the destination is replaced only after every
level succeeds. Cancellation discards the whole batch.

**Settings > Export defaults** stores these choices, including background and
asset formats, with or without _Lib. The fallback exposes the same switches and
format choices; the shared controls determine the resulting UVTT contents.

### Level names and elevation bounds

Level Settings shows two integer inputs on a second line below each level:
**Bottom** (down-layer icon) then **Top** (up-layer icon). A separate checkbox
button in the first line includes or excludes that level when **Export levels**
is ON. New and existing levels default to included. This selection supports
undo/redo and is saved with the map, with or without _Lib; it follows the level
when renamed or rearranged. Exporting just the current level ignores the flag.
Excluding every level produces an error before exporting. The SoftShadows
enable/disable button controls shadows independently.

Dragging a header moves its inputs with it. Insertion markers appear between
complete level groups; dropping over the second line places a level after that
whole group. The two inputs have room for at least four digits and
accept signed 32-bit integers. Both start at 0; a trailing `[bottom,top]` in an
existing level name initializes them on first use. No start/step fallback is
needed. Edits support undo/redo, stay with their level through rearranging and
renaming, and save in the map with or without _Lib. Deleted levels are omitted
from saved components; undo retains their values during the session.

Each UVTT envelope, including the root and every `Levels` entry, includes
`level_name`, `bottom`, and `top`. A numeric trailing bracket suffix is omitted
from the exported name; explicitly edited fields determine the elevations.
Bottom must be at most Top before UVTT export; the two inputs may be edited in
either order. Export disables the fields until the operation finishes.

The completion message reports animated doors (including assigned objects) and
ordinary native portals. Multi-level exports report the total across all levels.

### Legacy fallback

1. Open the native Export window. Select the current level as Source Level,
   None as Overlay Level, and disable level comparison.
2. Choose an export format:

   | Format | Result |
   | --- | --- |
   | Universal VTT (Animated Doors), including JPG/WebP/reference variants | UVTT using the shared image, embedding, baking and level controls |
   | PNG / JPG / WebP (without Animated Doors) | Raster output; the shared baking switch controls door artwork and shadows |

3. Choose a full map or rectangular crop and a PPI from 1 to 300. Fixed 1080p
   output is unsupported. Click **Export Animated Doors** and choose a filename.
   The file extension follows the format, and directory navigation preserves the name.
4. Wait for the saved-file confirmation. During capture, **Discard result when
   rendering finishes** cancels the output after native rendering completes.

Every declared visible object/free portal on the source level is considered,
regardless of the list filter. Editor artwork is restored after capture, including
cancellation/failure. Native selection is temporarily cleared before capture and
restored afterwards, including failure or cancellation, provided the same level
and objects still exist. UVTT and raster exports also work with zero declared doors.

UVTT with animation data uses [extension schema 10](docs/export-contract.md). Native portals
carry `animated: true` and `animated_door_id`; all animation records, including
object doors, live in `animated_doors.instances`. IDs identify instances, while
asset hashes deduplicate artwork. All other native portals carry `animated: false`
and no instance link, including baked UVTT. Unassigned object artwork is not a
native portal.
Native portal geometry and LOS remain unchanged.
Reference mode embeds the normal background but no door images. Resolve the
required finished image by hash; its original source may differ after processing.
Assets group source-file identity and applied operations under source_origin;
canonical filenames prefer the highest package ID. Targets copy final image
descriptors/names, hinge/order/shape facts, state/ds and length/thickness in grid
units. Perpendicular scaling is texture_height*scene_grid/texture_grid_size.
Shear keeps the export valid and marks its target as problematic_import.

The separate commented importer was not changed in this iteration and still
targets schema 8. It needs a separately authorized update before schema-10 import.

## Limits, diagnostics and recovery

Ordinary textures, integer Sprite regions/frames, offsets, flips, rotation,
nonuniform scale and simple tint/opacity are supported. The verified native Object
shader is supported, and native CustomColors are baked into embedded images.
Inactive ancestor materials do not block export. Other active shader/material
effects, normal maps, AtlasTexture margins, and fractional/repeated regions are rejected
for animated UVTT. Raster-only exports can suppress these visuals without
encoding them; baking doors into the background uses normal native rendering.
Remove the affected asset's assignment to retain it in ordinary native output.
Declared objects' separate native shadow sprites are suppressed/restored with the
artwork. No animated shadow is exported. Baked lighting and occlusion remain static;
object assignment does not create native walls.

Defensive caps: 16,777,216 source pixels; 16,384 pixels per side; 64 MiB per encoded
door image; 256 MiB total door Base64; 512 MiB encoded background. Peak memory on large
maps remains unmeasured. Exports contain the current source level unless **Export levels** is ON.

**Write diagnostic report** records engine/API, selected IDs, asset kind,
visibility, settings and geometry to `user://animated_doors_diagnostics.json` and
shows its full path. It contains no embedded images. Check it before sharing.

The writer validates a temporary sibling file before replacement. Replacing an
existing file uses a backup and two renames, not one atomic operation. A crash can
leave `<destination>.animated-doors-<transaction>.tmp.backup`. Close Dungeondraft,
preserve any current destination, and restore the backup to the original filename.
Failed rollback reports both recovery paths. Old transactions' files are not deleted.

## Development

From the source workspace:

```powershell
& '<Godot-3.4 executable>' --no-window --path 'AnimatedDoors/tests' --script res://run_tests.gd
```

Tests use the supplied _Lib source in `Plan/_Lib`, which is not bundled in the ZIP.
`tests/generate_fixtures.gd` regenerates the examples using the same Godot command.
`tools/verify_fixtures.py` independently checks them; `tools/package.py` builds the ZIP.
See [test results](docs/test-results.md) for what has and has not been exercised.

Fresh-install defaults: automatic Dungeondraft language, editing enabled, visible
artwork axis detection, height fallback, red hinge marker. Main menu order values:
Remove 3, Declare 4, Animated Doors 5, Toggle Hinge 6, Toggle Swing 7.
Already stored preferences keep their values.
