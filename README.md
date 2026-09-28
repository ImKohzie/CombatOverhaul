# APEX CITY (working title)

A sandbox superhero / villain game for Roblox. Twelve original characters
fight across **New Harbor**, a generated Manhattan-style city ringed by
forest. The city has fully destructible buildings, a day/night cycle and
weather.

All code is strict Luau in a Rojo project. Everything installs into
`ApexCity` folders, so it never overwrites existing content in a place.

| Repo folder   | Goes into Studio at                            |
|---------------|------------------------------------------------|
| `src/shared`  | `ReplicatedStorage.ApexCity`                   |
| `src/server`  | `ServerScriptService.ApexCity`                 |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.ApexCity`  |

## Installing (no tools needed)

Download the three files in `release/`, then in Roblox Studio:

1. Delete any older `ApexCity` folders in the three places below.
2. Move any **old scripts from earlier attempts** out of the way, for example
   into a folder in `ServerStorage`, where scripts don't run. Candidates are
   `Bootstrap` / `Services` in ServerScriptService, `ClientBootstrap` /
   `Controllers` in StarterPlayerScripts, and `Characters` / `Shared` /
   `AssetRegistry` in ReplicatedStorage.
3. Right-click **ReplicatedStorage**, choose **Insert → Import Roblox Model…**, then `ApexCity_shared.rbxm`.
4. Right-click **ServerScriptService**, choose **Insert → Import Roblox Model…**, then `ApexCity_server.rbxm`.
5. Expand **StarterPlayer**, right-click **StarterPlayerScripts**, choose **Insert → Import Roblox Model…**, then `ApexCity_client.rbxm`.
6. Change two settings that scripts can't change:
   - **Workspace → StreamingEnabled = true**
   - **Lighting → Technology = Future**
7. Press **Play**. The first start builds the map, which takes a few seconds (see "Baking the map").

## Baking the map (recommended)

The server generates New Harbor on start if the place has no `NewHarbor`
model. To build it once and save it into the place, run this in the Studio
**command bar** in edit mode, then save:

```lua
require(game.ServerScriptService.ApexCity.World.WorldBuilder).build()
```

## Controls

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Move / jump / ascend | WASD / Space | Left stick / A | Thumbstick / Jump |
| Sprint / boost | Shift | L3 | Run |
| Signature movement (every character, see below). Flyers: F = launch / burst, double-tap F = drop | F | B | Move |
| Block | X | D-pad left | Block |
| Take off (flyers) | Double-jump or F | A, A | Jump, Jump |
| Descend (flight) | Left Ctrl | R3 | Down |
| Dash (glider: trick-spin dodge) | C | D-pad right | Dash |
| Attack: tap = combo, hold = heavy (air: aerial / dive slam) | Left mouse | R2 | Hit |
| Aim (shoulder camera, crosshair) | Right mouse | L2 | Aim |
| Abilities 1–3 | Q / E / R | X / Y / R1 | Q / E / R |
| Ultimate (meter full) | G | L1 | ULT |
| Character select | Tab | Select | Characters button |
| Emote | V | D-pad down | — |

## Characters

| Character | Role | HP | Movement |
|---|---|---|---|
| Bastion | Tank | 1800 | Ground |
| Voltline | Agile | 950 | Ground (Momentum speed tiers) |
| Old Guard | Bruiser | 1400 | Ground |
| Sovereign | Bruiser | 1400 | Flight (best boost) |
| Rampage | Tank | 1800 | Ground (Rage) |
| Nightwing Goblin | Balanced | 1150 | Glider |
| Argent | Balanced | 1150 | Board |
| Graven | Balanced | 1150 | Ground |
| Rime | Agile | 950 | Ground + ice roads |
| Swarm | Balanced | 1150 | Ground |
| Echo | Agile | 950 | Ground |
| Umbra | Agile | 950 | Ground + shadow steps |

## Tuning

- **Gameplay numbers:** every one is in `src/shared/Config/BalanceConfig.luau`.
  - The server prints a **time-to-kill matrix** and rule checks on start.
  - Run `python3 tools/run_balance.py <luau binary>` to print the same report outside Roblox.
- **Map layout:** `src/shared/Config/MapConfig.luau`.
- **Networking, anti-cheat, debris caps, day/night and weather:** `src/shared/Config/GameConfig.luau`.
- **Asset IDs:** every one is in `src/shared/AssetRegistry.luau`. The status field says what's a placeholder.

## Architecture

- **Server-authoritative.**
  - Clients send intents only.
  - Every remote is rate-limited and schema-validated, with distance, aim, speed and cooldown checks.
  - Repeated invalid requests get the player kicked.
- **Server services:**
  - State, status effects, movement, reactions and ragdoll
  - Damage (block, parry, posture) and combat (M1, heavy, aerial, dive)
  - Beams (10Hz damage casts), abilities, passives, costumes and NPC dummies
  - World generation, destruction, environment and performance
- **Abilities:** `src/server/Abilities/<Character>/<Ability>.luau`, each with a
  `Begin` / `End` pair, running on the shared AbilityService and AbilityKit.
- **Client controllers:**
  - Input (PC, gamepad, mobile), camera (aim, FOV, shake, rumble, cinematics) and poses (procedural animation, hit-stop)
  - Flight, movement, combat, beams and effects
  - Environment (lights, rain, mist), ambience audio, border and HUD
- **Destruction:**
  - Chunk health comes from the material.
  - A structural graph collapses unsupported sections.
  - Loose debris is capped at 1200, owned by the nearest player, fades after 20–40s, and buildings rebuild after about 120s.

## Placeholders / needs your input

- **Animations:** combat, ability, flight and landing poses are procedural
  keyframes (`PoseLibrary`).
  - Add per-character animation IDs to `AssetRegistry`.
  - Set each attack's `WindUp` in `BalanceConfig.Melee` to its animation's "Hit" marker time.
- **Audio:** hit, beam, whoosh, ultimate-sting and several ambience entries fall
  back to built-in Roblox character sounds, re-pitched.
  - Birdsong, crickets and owls, crowds, pigeons, horns and sirens are silent until you add licensed asset IDs.
- **Models and textures:**
  - Characters use procedural costumes built from parts, not meshes or SurfaceAppearance.
  - Buildings use Roblox's built-in PBR materials.
  - MaterialVariants need texture uploads.
- **Studio-only settings:** StreamingEnabled and Lighting.Technology (see Installing).
- **Test character:** "Recruit (Test)" is hidden from character select and can be deleted.
