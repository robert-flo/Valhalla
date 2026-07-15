# RaVN-owned resources

This tree contains only resources owned by the independent RaVN installer.
Its layout mirrors the user's home directory and is consumed by the category
manifests under `Scripts/`.

- `.config/waybar` is the RaVN configuration overlay.
- `.local/share/waybar` contains RaVN-owned Waybar resources.
- `.local/share/applications/icons` contains reusable RaVN launcher icons.
- `.local/bin` contains explicitly declared RaVN user binaries.

`Configs/` remains the upstream configuration tree. Do not add RaVN resources
there; update the appropriate RaVN manifest when adding a managed resource.
