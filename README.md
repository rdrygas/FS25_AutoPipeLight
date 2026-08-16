# FS25 Automatic Pipe Light

A script mod for **Farming Simulator 25** that automates the discharge pipe light.

## How the script works

- When the player-controlled vehicle begins to unfold the pipe **at night**, the mod turns the pipe’s light on once.
- When the pipe begins to fold up, the mod turns the pipe’s light off once.
- If the pipe remains extended until nightfall, the light will also be automatically switched on.
- At dawn, the mod removes only the light it previously switched on itself.
- The mod **does not force the light state on every frame**. After the automatic change, the player can toggle the vehicle’s lights as normal.
- The specialisation is applied globally to all vehicle types that have both `Pipe` and `Lights`.
- This includes compatible combine harvesters, root crop harvesters and auger wagons.
- Multiplayer is disabled in this version; the mod is designed for single-player gameplay.

## Detection of pipe light

The script attempts the following in order:
1. to find a light type used exclusively by lamps located on pipe nodes,
2. to find a custom light type (4 or higher) placed on a pipe,
3. to use `LightType 4` as a fallback if the vehicle has that light type.

The detection takes into account both `Pipe` nodes and nodes participating in the pipe animation. There is also a cautious fallback based on node names (`pipe`, `unload`) for unusually constructed vehicle mods.

## Installation

Copy the file `FS25_AutoPipeLight.zip` to the following directory:

`Documents/My Games/FarmingSimulator2025/mods/`

Then select the mod when starting a new game.

## Diagnostics

If a particular machine is not responding correctly, in the file `scripts/AutoPipeLight.lua`, change:

```lua
AutoPipeLight.DEBUG = false
```

to:

```lua
AutoPipeLight.DEBUG = true
```

Once the game has started, the detected pipe light mask and the detection method will appear in `log.txt`.

If the vehicle has an unusual headlight configuration, you can also change the constant:

```lua
AutoPipeLight.FALLBACK_LIGHT_TYPE = 4
```
