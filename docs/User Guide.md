# Animated Doors: User Guide

Animated Doors lets you mark Dungeondraft objects and freestanding portals as animated doors, configure their movement, preview them, and export their artwork and settings in a Universal VTT (`.dd2vtt`) file.

This guide covers version **0.15.8**. Control names below use the English interface; the mod also supports German. `_Lib` and Unofficial Patch are optional. Without them, Animated Doors provides its own settings and right-click menu.

To install, extract the `AnimatedDoors` folder into your Dungeondraft mods directory, enable the mod, and reopen your map. The resulting path should be `mods/AnimatedDoors/mod.ddmod`. Save your map normally to retain door assignments and map-specific settings.

**Foundry compatibility:** exporting data does not guarantee that the installed Foundry importer understands it. The current exporter uses a newer format than the existing separate importer. In particular, the level-export workflow described in section 4 is **not yet functional in Foundry** and requires an importer update.

## 1. Export functionality and options

### Choose the output

Open Dungeondraft's **Export** window. With the compact export integration enabled, choose one of these formats:

| Format | Use it for |
| --- | --- |
| PNG | A lossless map image. |
| JPEG | A compressed map image, with quality controls. |
| WEBP | A compressed map image in WebP format. |
| Universal VTT | A `.dd2vtt` file containing map data and, when enabled, the map image and separate animated-door data. Requires a compatible importer for use in a VTT. |

Raster exports produce an image, not interactive doors. Universal VTT is the option for transferring door settings and separate artwork to a compatible importer.

### Animated Doors export controls

| Control | What it does |
| --- | --- |
| **Multi file / Mehrere Dateien** | Directly below the output-format dropdown. ON writes each enabled level as a separate UVTT/PNG/JPG/WebP file, using the chosen filename prefix and sanitized level names in the chosen directory. UVTT files share `multi_file`, `map_name`, and `export_timestamp` under `Levels` and contain only their own map. |
| **Include map image** | Universal VTT only. ON includes the background image. OFF omits the image while retaining map geometry, lighting data and separate animated-door data. Defaults to ON. |
| **Export mode** | Selects the Universal VTT background format: PNG, JPG or WebP. This is independent of the separate door-image format. Disabled when the map image is omitted. |
| **Include animated doors in map image** | ON bakes declared door artwork into the map image. OFF removes declared door artwork and its separate shadow sprites from that image so it can be supplied separately. Defaults to OFF. In raster exports, this decides whether the declared doors appear in the image. |
| **Embed door assets in UVTT (Base64)** | With baking OFF, ON includes the required door-image files inside the `.dd2vtt` file. OFF writes asset references and hashes instead; the receiving application must obtain the matching images separately. Defaults to OFF. |
| **Door asset format** | Chooses Original format, PNG or WebP for separate door images. Does not change the map background format. Disabled for baked UVTT and hidden for raster exports. |
| **Export levels** | Includes the selected levels in one UVTT file. Defaults to OFF. See section 4 for ordering, selection and the pending Foundry importer support. |

The chosen save filename is a prefix: `Test_.dd2vtt` with levels `Ground` and
`Dach` writes `Test_Ground.dd2vtt` and `Test_Dach.dd2vtt` to that directory.
No separator is inserted automatically; include an underscore, space or dash
in your chosen prefix when desired. The full name is sanitized and collisions
receive numeric suffixes. This also applies to PNG/JPG/WebP batches.

Set the mod's **Language** to English, Deutsch, or Dungeondraft (automatic) in
global settings. **Export defaults / Exportvorgaben** is a separate settings
section; **Additional export defaults / Weitere Export-Standardeinstellungen**
opens defaults for currently available host/module controls, even with Export
closed. Missing module defaults remain saved and can be used after reloading.

Use the regular **Export** button with the separate-file switch enabled; the
redundant second export button has been removed. If any level files already
exist, a confirmation dialog lists them before rendering begins. Cancel leaves
existing files intact. To always overwrite, enable **Overwrite existing level
files without asking** in global Export defaults (OFF by default). After exporting
multiple files, the completion report lists every saved file and full path.

**Baking changes the result:** when **Include animated doors in map image** is ON, UVTT contains the doors as part of the background and does not contain separate animation records or door assets. Asset embedding is therefore disabled. Baking is also disabled when **Include map image** is OFF.

Typical UVTT choices are:

| Intended result | Include map image | Include animated doors in map image | Embed door assets |
| --- | --- | --- | --- |
| Background plus separately embedded animated doors | ON | OFF | ON |
| Background plus door references for an external asset workflow | ON | OFF | OFF |
| Background with doors permanently painted into it | ON | ON | Disabled |
| Map data and embedded doors, without a background image | OFF | Disabled | ON |

For **Door asset format**, Original format keeps eligible PNG/WebP originals when no image changes are needed. Cropping and other image changes may require re-encoding. Unsupported original formats, including JPEG, use PNG for the separate door image. Choose PNG for lossless output; re-encoded WebP can be lossy.

### Prepare and run an export

1. Save the map and open **Export**.
2. For a single-level export, select the level currently being edited as **Source Level**. Set **Overlay Level** to None and turn off level comparison.
3. Choose the format and Animated Doors options above.
4. Choose a full-map export or a rectangular crop. Use a resolution of **1–300 pixels per grid**; fixed 1080p output is unsupported by this export workflow.
5. Click **Export**, choose a destination, and wait for the saved-file confirmation.

The native grid, lighting, camera-filter, crop and resolution controls still determine the map image. Additional controls supplied by other mods retain their own functions.

All declared, visible supported doors on the source level are considered, regardless of the Animated Doors list filter. Turning editing or the overview off does not exclude doors from export. Hidden artwork is not exported as a visible animated door. Maps without declared doors can also be exported.

During export, editing overlays are hidden and the artwork is temporarily prepared for capture. The mod restores the artwork and selection afterwards. To cancel an active capture, choose **Discard result when rendering finishes** and allow native rendering to finish. A failed or cancelled batch does not replace the destination with a partial result.

### If the compact export controls are unavailable

The fallback adds formats such as **Universal VTT (Animated Doors)**, its JPG/WebP and asset-reference variants, and **PNG / JPG / WebP (without Animated Doors)** to the native format list. Use the shared switches to set the desired image, baking, embedding and level options, then click **Export Animated Doors**.

The raster format names describe their default purpose; the baking switch determines whether declared door artwork is included. Formats added by other mods keep their own export handling.

You can store preferred starting choices under **Global settings > Export defaults**, described in section 3.

## 2. Working with animated doors and the right-click menu

### Create your first animated door

1. Place an asset using the **Object tool** or place a **freestanding portal**. Wall-attached portals and nonsprite shapes are not supported.
2. Open **Settings > Animated Doors** and enable **Enable animated door editing**.
3. Select the asset with Dungeondraft's **Select tool**.
4. Right-click near the selection and choose **Declare Animated Door**. Alternatively, use **Declared animated door** in the Animated Doors panel.
5. Choose the hinge, movement direction, axis, animation type and other properties below.
6. Use the guides or **Play animation** to check the result, then save the map.

Keep fixed frames or surrounding trim as separate assets. Transparent padding in an image affects its image-edge hinge positions; use offsets to crop unwanted padding when needed.

### Selected-door options

These controls edit the selected doors. They do not change the defaults used for future declarations.

| Option | How to use it |
| --- | --- |
| **Declared animated door** | Assign or remove Animated Doors behavior. Removing the assignment returns the asset to ordinary export behavior. Redeclaring it uses the current declaration defaults. |
| **Hinge A / Hinge B** | Choose the effective hinge endpoint. A is shown as a triangle and B as a circle. For the width axis, A starts at the left edge and B at the right; for the height axis, A starts at the top and B at the bottom of the unrotated image. |
| **Swing left / Swing right** | Set the movement direction. Check the guide or artwork preview after changing the hinge, rotation or mirroring. |
| **Door axis: image width / image height** | Choose which image axis defines the door's length and endpoints. The axis follows the placed artwork when moved, rotated, scaled or mirrored. |
| **Door / Secret door / Window** | Set the exported door type. The right-click menu calls the secret-door choice **Hidden door**. |
| **Animation type** | Choose swing, slide, swivel, ascend or descend. See the movement descriptions below. |
| **Closed / Open / Locked** | Set the exported starting state. Locked also means closed. This does not permanently move the original map artwork into an open pose. |
| **Double door** | Mark the asset for two-leaf animation. Use the preview to inspect the split. |
| **Door extension** | Set movement strength from **0 to 180**; **90** is normal strength. Its meaning depends on the animation type, so it is not always a rotation angle. The **90** button resets it. |
| **Hinge A offset / Hinge B offset** | Crop inward from the two ends to adjust the effective door artwork and hinge positions. Values are map pixels at 256 pixels per grid; fractions are allowed. Use small changes and inspect the preview. A crop that removes all image content cannot be exported. |

Movement choices:

| Type | Preview behavior |
| --- | --- |
| **swing** | Rotates the artwork around the selected hinge. |
| **slide** | Retracts toward the selected hinge; double-door leaves move outward. |
| **swivel** | Rotates around the centre. |
| **ascend** | Previews vertical movement by fading the artwork into a dark shadow. |
| **descend** | Previews the reverse vertical movement, fading from shadow into artwork. |

The editor preview helps configure the exported motion. Its vertical effects are symbolic, and final VTT behavior depends on importer and animation support.

Offset changes remember the last valid crop for that asset and axis for future declarations. **Reset crop template** removes that reusable crop default without changing existing doors. Undo restores instance edits, but does not undo the reusable crop-template library.

### Use the right-click menu

With editing enabled, select one or more eligible assets and right-click near them. If a compatible Unofficial Patch menu is available, Animated Doors adds its commands there. Otherwise, it opens its own fallback menu.

| Command | Action |
| --- | --- |
| **Declare Animated Door** | Assign the selected eligible assets as animated doors using the current defaults. |
| **Remove Animated Door assignment** | Remove their assignments. |
| **Toggle Hinge** | Swap A and B on each selected declared door. |
| **Toggle Swing** | Swap left and right on each selected declared door. |
| **Animated Doors** | Access explicit hinge, direction and axis choices, animation type, door type, door state, double-door mode, extension and the movement-guide toggle. |

The submenu includes **Swing Type**, **Door Type** and **Door State** groups. The fallback arranges some groups directly in its menu. Hinge, direction and axis commands require the selected eligible assets to be declared first. Crop offsets are edited in the panel.

An **(a)** marker identifies an active menu choice. Mixed selections may show no active marker. Multi-selection lets you edit several doors together; normal undo/redo is supported.

If commands are missing, check that editing and the global right-click-menu setting are enabled, the Select tool has an eligible selection, and the entry's **Menu order** has not been set to 0.

### Door list and selection

The panel can show **Declared doors**, **All objects and portals**, or **Undeclared objects and portals**. Declared list entries are yellow; unassigned entries are blue. Choose a layer to narrow the list.

**The layer selector only filters the list.** It does not declare an entire layer, restrict the overview, or exclude declared doors from export.

| List action | Result |
| --- | --- |
| Single-click, or select several rows | Highlight the corresponding artwork without switching tools. |
| Double-click | Switch to the native Select tool and select that asset. |
| Right-click a row | Toggle its declaration while editing is enabled. |
| Shift + right-click a row | Toggle its hinge A/B; requires a declared door. |
| Ctrl + right-click a row | Toggle its swing direction; requires a declared door. |

Right-click list gestures affect only the clicked row, even when several rows are selected. Use **Apply defaults to selected doors** to deliberately replace selected declared doors' settings with the current defaults in one undo step.

### Guides, overview and artwork preview

| Control or shortcut | Purpose |
| --- | --- |
| **Preview swing** | Show or hide movement guides for the selection. This does not itself animate the artwork. |
| **Play animation** or **Ctrl+Shift+D** | Play selected visible declared doors once, opening and returning without changing their saved state. Locked doors can also be previewed. |
| **Preview duration (ms)** | Set the artwork preview's base duration, saved with the map. The initial value is 750 ms. Ascend/descend scale their duration with the extension value. This is not an exported VTT animation-duration setting. |
| **Show all animated doors** or **Shift+D** | Show outlines and guides for declared visible doors on the current level, independently of the list filters and editing mode. |

The artwork preview stops and restores the map on Escape, selection or level changes, saving, export, or changes to the artwork. It does not loop. With `_Lib`, the two shortcuts can be changed or unbound in shortcut settings.

## 3. Animated Doors settings

### Where settings apply

| Scope | Where to change it | Effect |
| --- | --- | --- |
| **Global settings** | `_Lib`'s mod settings, or **Global settings** in the Animated Doors panel when `_Lib` is unavailable | Language, startup behavior, export defaults, colors, menu order and declaration defaults. Save/confirm the settings to retain changes. |
| **Defaults when declaring a door** | The defaults foldout in the Animated Doors panel | Values copied to newly declared doors on this map. Existing doors change only if you explicitly apply the defaults. |
| **Selected-door settings** | The selection controls or right-click menu | Change the selected declared doors, with undo/redo. |

Save the map to retain its door assignments, door properties, declaration defaults, preview duration and level settings. Both `_Lib` and standalone operation support this. Changing a declaration default does not silently rewrite existing doors.

### General settings

| Setting | What it is used for |
| --- | --- |
| **Language** | Choose Dungeondraft (automatic), English or Deutsch. Automatic follows supported host languages, with English fallback. |
| **Enable animated door editing on startup** | Set the initial editing-checkbox state when a map opens. Toggling the panel checkbox changes the current session. Disabling editing does not remove assignments or disable export. |
| **Enable Animated Doors right-click menu** | Enable the shared-menu integration or automatic fallback. OFF removes Animated Doors menu commands; the panel and independent shortcuts remain available. |
| **Export dialog compatibility** | Enter the exact Dungeondraft product version to use the compact native export integration. An empty or different value uses the fallback export entries. This is the Dungeondraft version, not the Godot engine version. |
| **Shortcuts**, when available through `_Lib` | Change or unbind Show all animated doors and Play animated door preview. |

### Export defaults

This group stores the initial choices for **Include map image**, **Include animated doors in map image**, **Embed door assets in UVTT (Base64)**, **Export levels**, the UVTT background format, and the separate door-asset format. Their effects are described in section 1. You can adjust the choices in the export dialog for the export you are preparing.

### Panel defaults and automatic axes

**Panel defaults** provides the same hinge, swing, type, state, double-door, extension and offset options described in section 2, plus automatic axis choices. Changing these global defaults updates the current map's declaration defaults and supplies starting values for new maps. It does not change existing declared doors.

| Default axis choice | How it is chosen |
| --- | --- |
| **Image width** | Always use the image's local width axis. |
| **Image height** | Always use its local height axis. |
| **The longer side** | Use the longer placed image dimension, taking nonuniform scaling into account. |
| **The shorter side** | Use the shorter placed image dimension. |
| **Visible artwork** | Examine nontransparent artwork to choose the axis, useful for images with transparent padding. |
| **Axis fallback: image width / image height** | Choose the fallback when automatic detection cannot determine an unambiguous axis. |

Automatic choices are resolved for each asset when it is declared or when defaults are applied. The result is saved as width or height; later resizing does not automatically switch an existing door's axis.

The global default-axis preference initializes the panel's Default axis each time a map opens, including an existing map. You can then choose another declaration axis for the current session. Other saved map defaults are retained on reload.

### Overlay colors

These settings change editor guides and highlights, not the exported door artwork:

| Color settings | What they identify |
| --- | --- |
| **Triangle color**, **Circle color**, **Square color** | Endpoint and motion symbols. |
| **Door axis line color** | The door's selected image axis. |
| **Swing graphics color** | Movement guides. |
| **Locked door preview color**, **Open door preview color** | State-specific guides; initially red for Locked and white for Open. |
| **Hinge offset line color**, **Hinge marker color** | Crop/offset guides and effective hinges. |
| **Central pivot color** | The swivel pivot. |
| **Selected door highlight color** | Artwork highlighted from the door list. |
| **Door outline color**, **Secret door outline color**, **Window outline color** | Type-specific outlines in the overview. |

Enter a color as `#RRGGBB` or `#AARRGGBB`, or use **Choose color...** and **Apply**. Save the global settings to retain it. Transparency is supported.

### Menu order

The **Menu order** group controls individual commands and submenu groups. Lower numbers appear earlier within the same menu; **0 hides an entry**. Hiding a submenu also hides its children. Negative values are allowed. These settings change ordering within the command's existing menu group; they do not move it to a different submenu.

### Diagnostics

Use **Write diagnostic report** in the panel when reporting an issue. It writes a report and displays its location. The report contains settings, selected asset IDs and geometry information, but no embedded images. Review it before sharing it.

## 4. Level export — NOT YET FUNCTIONAL IN FOUNDRY

**Status: the Dungeondraft export is implemented, but the Foundry importer still needs to be adjusted. This is not yet an end-to-end functional level workflow in Foundry.** The options below describe how to prepare and export level data; do not expect the existing importer to create or configure these levels correctly yet.

### Select which levels to export

Open Dungeondraft's **Level Settings** panel. Each level has two lines:

- The **first line** contains the level name and buttons, including an Animated Doors **export checkbox**. Checked means included in a multi-level UVTT export; unchecked means skipped. New and existing levels initially default to included.
- The **second line** contains the lower elevation beside the **down-layer icon** and upper elevation beside the **up-layer icon**.

The export checkbox is separate from **Switch to this level**, which changes the level you are editing. SoftShadows' **Enable/Disable** button controls shadows, not export inclusion.

Then open **Export**, choose **Universal VTT**, and turn **Export levels** ON. The mod exports only checked levels. Turning **Export levels** OFF exports just the current source level, regardless of that level's checkbox.

Export-checkbox changes support undo/redo and save with the map. They remain attached to the level when it is renamed or rearranged. If every level is excluded, the exporter asks you to include at least one and does not write an export.

### Export order and skipped levels

Levels are exported **from the bottom of the displayed list upward**. The lowest included level becomes the main UVTT document, outside the `Levels` section. Higher included levels follow with consecutive numbers starting at 1.

| Dungeondraft display, top to bottom | Export location when all are included |
| --- | --- |
| Level 3 | `Levels/2` |
| Level 2 | `Levels/1` |
| Level 1 | Main document, outside `Levels` |

If Level 2 is excluded, Level 1 remains the main document and Level 3 becomes `Levels/1`. Excluded levels leave no gaps. If Level 1 is also excluded, Level 3 becomes the main document.

Drag a level header to reorder it. Its elevation line moves with it, and insertion markers appear between complete two-line level groups. Changing the display order also changes the next multi-level export order.

### Names and elevation bounds

| Field | Meaning |
| --- | --- |
| **Level name** | The name exported for that level. |
| **Bottom**, down-layer icon | The lower elevation value; defaults to 0. |
| **Top**, up-layer icon | The upper elevation value; defaults to 0. |

Bottom and Top accept signed integers. Bottom must be less than or equal to Top before exporting. Use the elevation units expected by your receiving workflow; the controls do not select a unit or automatically calculate the next level's height.

An existing level name ending in a numeric pair, such as `Upper floor [30,40]`, can initialize Bottom to 30 and Top to 40 when its settings are first created. The exported name is then `Upper floor`; the editor name is not rewritten. Explicitly editing the fields takes precedence over that initial suffix.

Elevation values support undo/redo, follow their level through renaming/reordering, and save with the map. Export temporarily locks the level controls.

Each included level exports its own name, bounds, geometry, lighting and door data, plus its image if requested. The export dialog's image, baking, embedding and door-format choices apply to all included levels. After export, the original editor/source level is restored. The combined destination is written only after every included level succeeds.

For the technical file structure, see the [export contract](export-contract.md). Foundry importer changes are still required before these multi-level exports can be used there as intended.
