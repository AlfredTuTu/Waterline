# Waterline application identity

The production icon uses two unequal cyan water-ripple strokes, offset horizontally,
on a dark rounded tile. This selected design replaces the earlier three-wave mark.
The artwork was generated with the built-in image-generation tool and adopted on
2026-09-07. The source PNG is `AppIcon.png` in this directory.

SHA-256: `b0b63e288d6fd5cb01aafe59e63a5d6b841f3815ea8ec2ff44736f44bc575b1e`.

`tools/build-icon.sh` derives the standard 16–1024 pixel macOS ICNS representations
from this PNG. `app/Sources/WaterlineApp/WaterlineMark.swift` draws the matching monochrome
menu-bar mark natively; it does not downsample the icon tile.

Earlier alternatives, exploratory previews and CLI consultation records are local
working materials under ignored `design-previews/`. They are not distribution assets.
Provider logos are separate licensed resources with their own provenance in
`app/Resources/ProviderLogos/`.
