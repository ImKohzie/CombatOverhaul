# APEX CITY (working title)

Sandbox superhero/villain game for Roblox. All code is strict Luau, organised as a
Rojo project. Everything lives in `ApexCity` folders so it never overwrites
existing content in the place.

| Repo folder   | Goes into Studio at                            |
|---------------|------------------------------------------------|
| `src/shared`  | `ReplicatedStorage.ApexCity`                   |
| `src/server`  | `ServerScriptService.ApexCity`                 |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.ApexCity`  |

## Installing into your place (no tools needed)

Download the three files in `release/`, then in Roblox Studio:

1. If an older `ApexCity` folder exists in any of the three places below, delete it first.
2. Explorer → right-click **ReplicatedStorage** → *Insert from File…* → `ApexCity_shared.rbxm`
3. Right-click **ServerScriptService** → *Insert from File…* → `ApexCity_server.rbxm`
4. Expand **StarterPlayer**, right-click **StarterPlayerScripts** → *Insert from File…* → `ApexCity_client.rbxm`
5. Press **Play**.

## Live sync (optional, for developers)

Install Rojo 7.4+ and the Rojo Studio plugin, then run `rojo serve` in this repo
and click *Connect* in the plugin.

## Controls

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Move / jump / ascend | WASD / Space | Left stick / A | Thumbstick / Jump |
| Sprint / boost | Shift | L3 | Run |
| Flight / block | F | B | Fly/Blk |
| Descend (flight) | Left Ctrl | R3 | Down |
| Dash | C | D-pad right | Dash |
| Attack | Left mouse | R2 | Hit |
| Aim | Right mouse | L2 | Aim |
| Abilities 1–3 | Q / E / R | X / Y / R1 | Q / E / R |
| Ultimate | G | L1 | ULT |
| Character select | Tab | Select | Chars button |
| Emote | V | D-pad down | — |

## Tuning

Every gameplay number is in `src/shared/Config/BalanceConfig.luau`.
Network limits and anti-cheat settings are in `src/shared/Config/GameConfig.luau`.
Every asset ID is listed in `src/shared/AssetRegistry.luau`.

## Adding a character

1. `src/shared/Characters/<Id>/Config.luau`: name, role, abilities, palette.
2. `BalanceConfig.Abilities.<Id>`: numbers for each slot.
3. `src/server/Abilities/<Id>/<AbilityId>.luau`: server logic (`Begin` / `End`).

The shared AbilityService checks cooldowns, stamina, the ultimate meter and aim
before any ability module runs. On start, CharacterRegistry warns in the output
about any config that doesn't match BalanceConfig.
