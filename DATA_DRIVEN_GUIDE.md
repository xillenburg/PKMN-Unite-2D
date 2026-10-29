# Data-Driven System Guide

Welcome to the data-driven framework for Pokémon. This architecture is designed with **Minecraft datapack-style flexibility**: you can add, customize, or rebalance Pokémon and moves simply by duplicating, modifying, or creating `.tres` (Godot Resource) and `.cfg` (ConfigFile) text files without editing any core engine code.

---

## Table of Contents
1. [Overview & Directory Structure](#1-overview--directory-structure)
2. [Moves System (`MoveData`)](#2-moves-system-movedata)
   - [Common Move Fields](#common-move-fields)
   - [Move Type: `homing`](#move-type-homing)
   - [Move Type: `shot`](#move-type-shot)
   - [Move Type: `shotgun`](#move-type-shotgun)
   - [Move Type: `melee`](#move-type-melee)
   - [Move Type: `beam`](#move-type-beam)
   - [Ready-to-Use Move `.tres` Templates](#ready-to-use-move-tres-templates)
3. [Pokémon System (`PokemonData`)](#3-pokémon-system-pokemondata)
   - [Base Attributes & Slots](#base-attributes--slots)
   - [24 Directional Sprites & Fallback System](#24-directional-sprites--fallback-system)
   - [Ready-to-Use Pokémon `.tres` Template](#ready-to-use-pokémon-tres-template)
4. [XP Configuration (`xp_manager.cfg`)](#4-xp-configuration-xp_managercfg)
   - [Section Reference](#section-reference)
   - [Adding a New Pokémon's XP Settings](#adding-a-new-pokémons-xp-settings)
5. [Custom Move Mechanics (`custom_move_mechanics/`)](#5-custom-move-mechanics-custom_move_mechanics)

---

## 1. Overview & Directory Structure

All game data is decoupled from game logic into explicit data files:

```
pokemon_game/
├── DATA_DRIVEN_GUIDE.md            <-- You are here
├── data/
│   ├── moves/                      <-- All move .tres data files
│   │   ├── tackle.tres
│   │   ├── razor_leaf.tres
│   │   ├── solar_beam.tres
│   │   ├── ember.tres
│   │   ├── flamethrower.tres
│   │   └── ...
│   ├── pokemon/                    <-- All Pokémon .tres data files
│   │   ├── venusaur.tres
│   │   ├── charizard.tres
│   │   └── blastoise.tres
│   ├── xp_manager.cfg              <-- Global & per-Pokémon XP configuration
│   └── xp_system.gd                <-- Unified XP calculation logic
├── moves/
│   ├── move_data.gd                <-- Universal MoveData Resource definition
│   ├── move_executor.gd            <-- Dispatcher routing moves to mechanics
│   ├── melee_mechanic.gd           <-- Generic melee delivery logic
│   ├── homing_mechanic.gd          <-- Generic homing delivery logic
│   ├── homing_projectile.gd        <-- Curving homing projectile entity
│   ├── shotgun_mechanic.gd         <-- Generic cone shotgun delivery logic
│   ├── shot_mechanic.gd            <-- Generic linear projectile delivery logic
│   ├── linear_projectile.gd        <-- Linear projectile entity
│   ├── beam_mechanic.gd            <-- Generic continuous beam delivery logic
│   ├── beam_effect.gd              <-- 3-stage continuous beam visual effect
│   └── custom_move_mechanics/      <-- Bespoke scripts for one-off move logic
└── pokemon/
    └── pokemon_data.gd             <-- Universal PokemonData Resource definition
```

---

## 2. Moves System (`MoveData`)

All moves are instances of `MoveData` (`moves/move_data.gd`). Any `.tres` file inside `data/moves/` can be created or duplicated.

### Common Move Fields

The following fields are available across **all** move types:

| Field | Type | Default | Description |
|---|---|---|---|
| `display_name` | `String` | `""` | User-facing move name (e.g. `"Razor Leaf"`). |
| `move_category` | `String` | `"physical"` | Category of the move: `"physical"` or `"special"` (case-insensitive string). Used for future damage calculations and type-specific shields. |
| `move_type` | `String` | `"melee"` | Delivery mechanic: `"melee"`, `"homing"`, `"shotgun"`, `"shot"`, `"beam"`. |
| `power` | `float` | `1.0` | Base damage dealt by the move. Supports decimal values. Scaled by caster's `base_damage` multiplier and upgrade points. |
| `cooldown_frames` | `int` | `60` | Cooldown duration in frames (60 frames = 1.0 second). |
| `range` | `float` | `0.0` | Maximum range or tracking distance in pixels (alias: `attack_range`). If set to `0.0`, uses the default range for that `move_type`. |
| `sound_path` | `String` | `""` | Path to the move's `.mp3` audio effect (e.g. `"res://assets/audio/moves/solar_beam.mp3"`). |
| `play_hit_sound` | `bool` | `true` | Whether a hit impact sound plays when this move connects with a target. |
| `xp_gain` | `float` | `1.0` | Flat XP rewarded to the caster each time this move successfully hits an enemy. |

---

### Move Type: `homing`

Fires one or more projectiles that fan out in an initial burst, curve gracefully in mid-air, and home in directly on an enemy's hurtbox circle within range.

#### Syntaxes & Configuration:

```ini
move_category = "special"
move_type = "homing"
power = 2.0
cooldown_frames = 120
range = 110.0
num_entities = 5
homing_range = 110.0
asset_path = "res://assets/moves/razor_leaf.png"
sound_path = "res://assets/audio/moves/razor_leaf.mp3"
xp_gain = 2.0
```

- **`num_entities`** (`int`, default: `5`): Total number of homing projectiles launched in the volley.
- **`homing_range`** (`float`, default: `0.0`): Maximum search distance to lock onto an enemy. If left at `0.0`, uses `range`.
- **`asset_path`** (`String`): Texture path for each homing entity (e.g. `"res://assets/moves/razor_leaf.png"`).
- **Behavior**:
  - Entities launch with a staggered delay (`0.2s` interval between leaves).
  - Trajectory is smoothly steered toward the locked target's hurtbox circle.
  - Spawns poof smoke (`DiagonalSmokeEffect`) when colliding or expiring.

---

### Move Type: `shot`

Fires straight-line skill-shots along the player's aimed direction. Supports **hold-to-aim** (with directional streak & arrow, identical to Dash) and **burst-fire** with configurable shoot intervals.

#### Syntaxes & Configuration:

```ini
move_category = "special"
move_type = "shot"
power = 4.0
cooldown_frames = 60
range = 140.0
num_entities = 3
shoot_interval = 0.12
asset_path = "res://assets/moves/hit_1.png"
sound_path = "res://assets/audio/combat/hit.mp3"
xp_gain = 2.0
```

- **`num_entities`** (`int`, default: `1`): Number of projectiles spawned per use.
- **`shoot_interval`** / **`shot_interval`** (`float`, default: `0.0`):
  - Delay in seconds between successive shots when `num_entities > 1` (burst fire).
  - If set to `0.0`, all projectiles spawn immediately.
  - If set to `0.12`, projectiles fire sequentially every `0.12` seconds.
- **`range`** (`float`, default: `160.0`): Distance the projectile travels before expiring.
- **`asset_path`** (`String`): Texture for the projectile (e.g. `"res://assets/moves/hit_1.png"`).
- **Hold Mechanic**:
  - Holding down the move key or touch button activates the aiming arrow and direction highlight streak.
  - Direction can be steered with movement keys/joystick or by dragging the touch button.
  - Arrow is unscaled retro size (`1.0x`) with a narrow beam (`6.0px` half-width).
  - Releasing the key/button fires the projectile(s) along the aimed vector.

---

### Move Type: `shotgun`

Fires a cone-shaped spread of linear projectiles along the player's facing direction.

#### Syntaxes & Configuration:

```ini
move_category = "special"
move_type = "shotgun"
power = 3.0
cooldown_frames = 90
range = 140.0
num_entities = 4
spread_angle = 45.0
asset_path = "res://assets/moves/hit_1.png"
sound_path = "res://assets/audio/combat/hit.mp3"
xp_gain = 2.0
```

- **`num_entities`** (`int`, default: `3`): Number of projectiles fanned out in the cone.
- **`spread_angle`** (`float`, default: `60.0`): Total width of the cone in degrees. For example, `spread_angle = 45.0` with `num_entities = 3` fires at `-22.5°`, `0°`, and `+22.5°`.
- **`range`** (`float`, default: `140.0`): Maximum travel distance of each projectile.
- **`asset_path`** (`String`): Projectile texture.

---

### Move Type: `melee`

Performs an 8-way directional lunging dash towards a target's hurtbox circle.

#### Syntaxes & Configuration:

```ini
move_category = "physical"
move_type = "melee"
power = 1.0
cooldown_frames = 0
range = 44.0
lunge_speed = 2.0
contact_distance = 20.0
max_frames = 45
hitbox_radius = 7.0
sound_path = "res://assets/audio/moves/tackle.mp3"
xp_gain = 1.0
```

- **`range`** (`float`, default: `44.0`): Maximum distance to lock on and initiate a lunge.
- **`lunge_speed`** (`float`, default: `2.0`): Movement speed multiplier during the lunge.
- **`contact_distance`** (`float`, default: `20.0`): Distance to victim's hurtbox edge required to register impact damage.
- **`max_frames`** (`int`, default: `45`): Maximum frames the lunge can continue before timing out if contact isn't made.
- **`hitbox_radius`** (`float`, default: `7.0`): Radius of the melee hitbox collider.

---

### Move Type: `beam`

Fires a continuous, 3-stage animated beam (Charge -> Beam with Peristaltic Swallow Wave -> Cascading Collapse) starting from the surface of the Pokémon's hitbox collider.

#### Syntaxes & Configuration:

```ini
move_category = "special"
move_type = "beam"
power = 13.0
cooldown_frames = 1200
range = 220.0
tracking = true
asset_path = "res://assets/moves/solar_beam.png"
charge_asset_path = "res://assets/moves/solar_beam_charge.png"
sound_path = "res://assets/audio/moves/solar_beam.mp3"
xp_gain = 8.0
```

- **`tracking`** (`bool`, default: `true` for Solar Beam):
  - When `true`, automatically locks onto an enemy target whose hurtbox circle enters/touches the valid range circle.
  - Automatically breaks lock-on if the target moves outside the valid range circle.
  - When `false`, fires strictly straight in the direction the player is facing.
- **`asset_path`** (`String`): 6-frame vertical sprite sheet (`32x208`) containing:
  - Frames 0 & 1: Energy flare at origin.
  - Frames 2, 3, 4: Body swallowing wave frames.
  - Frame 5: Beam tip (`32x48`).
- **`charge_asset_path`** (`String`): 5-frame vertical sprite sheet (`32x160`) for the charge-up stage.
- **`range`** (`float`, default: `220.0`): Maximum length of the beam.
- **Start Point**: Originates cleanly at the **surface of the Pokémon's hitbox collider** along the aiming direction.
- **Damage**: Ticks damage every `0.25` seconds (`power / 4` per tick).

---

### Ready-to-Use Move `.tres` Templates

#### Template 1: Homing Move (e.g. `leaf_storm.tres`)
```ini
[gd_resource type="Resource" script_class="MoveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://moves/move_data.gd" id="1"]

[resource]
script = ExtResource("1")
display_name = "Leaf Storm"
move_category = "special"
move_type = "homing"
power = 5.0
cooldown_frames = 180
range = 140.0
num_entities = 7
homing_range = 140.0
asset_path = "res://assets/moves/razor_leaf.png"
sound_path = "res://assets/audio/moves/razor_leaf.mp3"
xp_gain = 3.0
```

#### Template 2: Burst Shot Move (e.g. `water_pulse.tres`)
```ini
[gd_resource type="Resource" script_class="MoveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://moves/move_data.gd" id="1"]

[resource]
script = ExtResource("1")
display_name = "Water Pulse"
move_category = "special"
move_type = "shot"
power = 3.0
cooldown_frames = 120
range = 150.0
num_entities = 3
shoot_interval = 0.10
asset_path = "res://assets/moves/hit_1.png"
sound_path = "res://assets/audio/combat/hit.mp3"
xp_gain = 2.0
```

---

## 3. Pokémon System (`PokemonData`)

Pokémon data is defined by `PokemonData` (`pokemon/pokemon_data.gd`). Resource files are placed in `data/pokemon/<pokemon_name>.tres`.

### Base Attributes & Slots

| Field | Type | Description |
|---|---|---|
| `display_name` | `String` | Species name (e.g. `"Charizard"`). |
| `base_damage` | `float` | Base damage multiplier (default `1.0`). Scales all moves executed by this Pokémon: `floor(power * base_damage)`. Supports items, crits, and buff/debuff effects. |
| `attack_1` | `MoveData` | Move assigned to Slot 1 (Unlocked at Lv. 1). |
| `attack_2` | `MoveData` | Move assigned to Slot 2 (Unlocked at Lv. 15). |
| `attack_3` | `MoveData` | Move assigned to Slot 3 (Unlocked at Lv. 25). |
| `special` | `MoveData` | Unite move slot (Unlocked at Lv. 30). Set to `null` if no unite move. |

---

### 24 Directional Sprites & Fallback System

Each Pokémon supports up to **4 Evolution Stages**, with **6 directional sprites per stage** (total 24 sprites):

- **Stage 1 (Base Form)**:
  - `stage1_h1`, `stage1_h2`: Horizontal running/facing frames.
  - `stage1_v1`, `stage1_v2`, `stage1_v3`, `stage1_v4`: Vertical up/down walking frames.
- **Stage 2 (Middle Form)**: `stage2_h1` ... `stage2_v4` (Evolves at Lv. 20).
- **Stage 3 (Final Form)**: `stage3_h1` ... `stage3_v4` (Evolves at Lv. 30).
- **Stage 4 (Mega Form)**: `stage4_h1` ... `stage4_v4`.

#### Robust Fallback Hierarchy
If some sprite files are missing or in-progress, the game **never crashes**:
1. Checks the explicit `stageN_XX` property.
2. Checks the legacy `stages` dictionary.
3. Falls back to the Stage 1 sprite of the identical direction.
4. Falls back to Venusaur baseline sprites.

---

### Ready-to-Use Pokémon `.tres` Template

To create a new Pokémon, duplicate this into `data/pokemon/my_pokemon.tres`:

```ini
[gd_resource type="Resource" script_class="PokemonData" load_steps=5 format=3]

[ext_resource type="Script" path="res://pokemon/pokemon_data.gd" id="1"]
[ext_resource type="Resource" path="res://data/moves/tackle.tres" id="2"]
[ext_resource type="Resource" path="res://data/moves/ember.tres" id="3"]
[ext_resource type="Resource" path="res://data/moves/flamethrower.tres" id="4"]

[resource]
script = ExtResource("1")
display_name = "Charmander"
base_damage = 1.0
sprite_dir = "res://assets/pokemon/charizard/"
sprite_prefix = "chder"
stage1_h1 = "res://assets/pokemon/charizard/chder_h_1.png"
stage1_h2 = "res://assets/pokemon/charizard/chder_h_2.png"
stage1_v1 = "res://assets/pokemon/charizard/chder_v_1.png"
stage1_v2 = "res://assets/pokemon/charizard/chder_v_2.png"
stage1_v3 = "res://assets/pokemon/charizard/chder_v_3.png"
stage1_v4 = "res://assets/pokemon/charizard/chder_v_4.png"
attack_1 = ExtResource("2")
attack_2 = ExtResource("3")
attack_3 = ExtResource("4")
```

---

## 4. XP Configuration (`xp_manager.cfg`)

All experience and leveling rules are driven by `data/xp_manager.cfg`.

### Section Reference

```ini
[kill_xp]
base_kill_xp = 50.0          # Base XP awarded for killing an enemy
level_multiplier = 1.0       # Kill XP multiplier per level of the defeated victim
                             # Formula: base_kill_xp * level_multiplier * victim_level

[damage_xp]
damage_taken_multiplier = 0.5 # XP earned when taking damage: damage * 0.5

[level_progression]
base_level_xp = 20           # XP required from Lv. 1 -> Lv. 2
level_xp_growth = 10         # XP increase per level: 20, 30, 40, 50...

[default]
atk_1 = 1.0                  # Default XP rewarded on hitting Attack 1
atk_2 = 2.0                  # Default XP rewarded on hitting Attack 2
atk_3 = 3.0                  # Default XP rewarded on hitting Attack 3
special = 0.0                # Unite moves ALWAYS yield 0 XP

[venusaur]
atk_1 = 1.0
atk_2 = 2.0
atk_3 = 8.0
special = 0.0

[charizard]
atk_1 = 1.0
atk_2 = 2.0
atk_3 = 4.0
special = 0.0
```

### Adding a New Pokémon's XP Settings
Simply append a new section titled with the Pokémon's lowercase display name (e.g. `[blastoise]`):
```ini
[blastoise]
atk_1 = 1.0
atk_2 = 2.0
atk_3 = 5.0
special = 0.0
```

---

## 5. Custom Move Mechanics (`custom_move_mechanics/`)

If a future move cannot be described using the standard mechanics (`melee`, `homing`, `shotgun`, `shot`, `beam`), you can author a dedicated GDScript file in:

```
moves/custom_move_mechanics/
```

- Standard mechanic files in `moves/` must **never** contain specific Pokémon or move names.
- Bespoke scripts (e.g. a weather-setting move or screen-wrapping move) belong in `moves/custom_move_mechanics/`.
- To call a custom mechanic, dispatch it from `MoveExecutor` or reference it within your custom script.
