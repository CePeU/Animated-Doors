# Animated Doors

Animated Doors is a Dungeondraft mod for marking objects and portals as animated doors, configuring their movement, and previewing them. It exports door artwork and animation settings in Universal VTT (`.dd2vtt`) files for use with a compatible importer. See the [user guide](https://cepeu.github.io/Animated-Doors/) for details and export options.

To install, download `AnimatedDoors.zip` from the [latest release](https://github.com/CePeU/Animated-Doors/releases/latest) and extract its folder into your Dungeondraft mods directory. You can rename the extracted folder to `AnimatedDoors`; the manifest should be directly inside it, for example `mods/AnimatedDoors/mod.ddmod`. Enable the mod in Dungeondraft and reopen your map.

For the best experience, also install the Dungeondraft mods [_Lib](https://github.com/CreepyCre/_Lib) and [Unofficial Patch](https://github.com/Moulkator/UnofficialPatch). Both are optional, but recommended for their interface integration.

To import animated doors into Foundry VTT, use the [v14 importer](https://github.com/CePeU/FVTT-UVTT-Animated-Doors-importer-v14) for Foundry v14 or the [v13 importer](https://github.com/CePeU/FVTT-UVTT-Animated-Doors-importer-v13) for Foundry v13. Install only the version matching your Foundry installation. You do not need either module just to use the mod in Dungeondraft or export ordinary map images.

The Foundry modules require manual installation. Download the matching module from its GitHub repository, using its release ZIP if available or **Code > Download ZIP**. With Foundry stopped, extract the module folder into your Foundry user data directory under `Data/modules/`. Ensure that `module.json` is directly inside the module folder, as in `Data/modules/<module-folder>/module.json`, without an extra nested folder. Restart Foundry, open your world, and enable the importer under **Manage Modules**. Foundry's [module installation guide](https://foundryvtt.com/article/modules/) explains the folder layout.

Importer support must match the exported data. The current user guide notes that multi-level exports still require an importer update, so check the importer documentation before using that workflow.

This mod was coded using AI. This is version 1.0.0 of the mod, and although it has been tested diligently, only one person has tested it so far. It may still need further testing, and feedback from other users is welcome.

If you find a bug or need help, [open an issue](https://github.com/CePeU/Animated-Doors/issues) or contact me in the [Dungeondraft Discord](https://discord.com/invite/6Ak9sZQ) as **CePeU (`cepeu1`)**.
