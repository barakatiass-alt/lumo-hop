# Lumo Hop

A one-tap arcade game. A firefly circles a glowing sky lantern; tap to let go and catch the next one before the light fades.

- `index.html` is the browser version (single file, no build step). `node serve.mjs` previews it on http://localhost:4173.
- `ios/` is the native iPhone version in Swift and SpriteKit. Generate the Xcode project with `xcodegen generate` inside `ios/`.
- `ios/LumoHop/GameCore.swift` holds the game rules with no UI imports; `ios/CoreTests/main.swift` plays it with a bot.

All rights reserved.
