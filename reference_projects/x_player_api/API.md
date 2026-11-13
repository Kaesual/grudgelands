# x_player_api API Reference

High-performance player animation, locomotion, eating simulation, and 3D wield items API for Luanti.

## Table of Contents

- [Classes & Data Structures](#classes--data-structures)
- [Type Aliases & Callbacks](#type-aliases--callbacks)
- [Core & Model API](#core--model-api)
- [Visual Proxies & Observers API](#visual-proxies--observers-api)
- [Head & Arm Look Tracking API](#head--arm-look-tracking-api)
- [Locomotion & Action Controls API](#locomotion--action-controls-api)
- [Eating & Consumables API](#eating--consumables-api)
- [3D Wield Item API](#3d-wield-item-api)
- [Registries & State Tables](#registries--state-tables)

---

## Classes & Data Structures

### `AnimationDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `collisionbox` | `number[]?` | Custom player collision box {minx, miny, minz, maxx, maxy, maxz} |
| `eye_height` | `number?` | Custom camera eye height during this animation |
| `loop` | `boolean?` | Whether the animation loops indefinitely |
| `override_local` | `boolean?` | Whether local client animation prediction should be overridden |
| `priority` | `number?` | Animation track priority for skeletal blending |
| `speed` | `number?` | Animation playback speed multiplier or FPS |
| `track` | `string?` | Named glTF animation track identifier |
| `x` | `number?` | Starting frame index for legacy single-track models |
| `y` | `number?` | Ending frame index for legacy single-track models |

### `BoneOverrideEntry`

| Field | Type | Description |
| :--- | :--- | :--- |
| `position` | `BoneOverridePayload?` | Translation payload |
| `rotation` | `BoneOverridePayload` | Rotation payload |

### `BoneOverridePayload`

| Field | Type | Description |
| :--- | :--- | :--- |
| `absolute` | `boolean` | Absolute vs relative transformation flag |
| `interpolation` | `number` | Client-side interpolation duration in seconds |
| `vec` | `Vector3` | Transformation vector |

### `CachedBoneState`

| Field | Type | Description |
| :--- | :--- | :--- |
| `b3d_position` | `Vector3` | Compensated local position offset vector for B3D space |
| `b3d_rotation` | `Vector3` | Compensated local rotation vector for B3D space |
| `override_b3d` | `BoneOverrideEntry` | Pre-allocated payload container for B3D proxy |
| `override_glb` | `BoneOverrideEntry` | Pre-allocated payload container for GLB proxy |
| `position` | `Vector3` | Local position offset vector {x, y, z} in GLB space |
| `rotation` | `Vector3` | Local rotation vector in radians {x, y, z} in GLB space |

### `ConsumableDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `action` | `string?` | Action animation name (e.g. "eat", "drink", defaults to "eat") |
| `duration` | `number?` | Action duration in seconds (defaults to 1.2) |
| `particle_type` | `string?` | Particle generator identifier ("crumbs", "liquid_drops", "none") |
| `sound` | `string?` | Sound name to play upon consumption |

### `EmoteDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `description` | `string\|nil` | Chatcommand description |
| `duration` | `number\|nil` | Default duration in seconds (-1 for continuous/infinite) |
| `is_posture` | `boolean\|nil` | Whether this emote is a posture (handled via locomotion layer, cancelled on movement) |
| `msg` | `string\|nil` | Chatcommand response message |

### `EquipSoundDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `gain` | `number?` | Playback gain/volume (default: 0.7) |
| `max_hear_distance` | `number?` | Maximum hearing distance (default: 16) |
| `pitch` | `number?` | Playback pitch multiplier (default: 1.0) |
| `pitch_variance` | `number?` | Pitch randomization variance range +/- (default: 0.06, set 0 to disable) |
| `sound` | `string\|table` | Sound name string or SimpleSoundSpec table |

### `HeadTrackingConfig`

| Field | Type | Description |
| :--- | :--- | :--- |
| `arm_action_weight` | `number` | Pitch weight applied during mining and melee attacks (default: 0.85) |
| `arm_aim_weight` | `number` | Pitch weight applied during bow and ranged aiming (default: 1.0) |
| `arm_idle_weight` | `number` | Subtle pitch weight applied to arms during idle/movement (default: 0.35) |
| `arm_pitch_down_max` | `number` | Maximum downward pitch for arms in radians |
| `arm_pitch_up_max` | `number` | Maximum upward pitch for arms in radians |
| `body_turn_speed` | `number` | Rate at which virtual body catches up to look direction |
| `deadband` | `number` | Minimum angular rotation delta in radians to trigger a network packet |
| `enable` | `boolean` | Global subsystem activation toggle |
| `enable_arm_tracking` | `boolean` | Whether dual-arm pitch tracking is active (default: true) |
| `fly_pitch_down_max` | `number` | Maximum downward pitch in flight in radians (default: 10 deg) |
| `fly_pitch_offset` | `number` | Baseline upward pitch offset when flying in radians (default: -75 deg) |
| `fly_pitch_up_max` | `number` | Maximum upward pitch in flight in radians (default: 85 deg) |
| `interpolation` | `number` | Bone override client interpolation duration in seconds |
| `pitch_down_max` | `number` | Maximum looking down limit in radians |
| `pitch_up_max` | `number` | Maximum looking up limit in radians |
| `settle_threshold` | `number` | Convergence threshold in radians to enter sleep state |
| `smooth_speed` | `number` | Exponential decay rate in 1/seconds for head interpolation |
| `swim_pitch_down_max` | `number` | Maximum downward pitch when swimming in radians (default: 10 deg) |
| `swim_pitch_offset` | `number` | Baseline upward pitch offset when swimming in radians (default: -75 deg) |
| `swim_pitch_up_max` | `number` | Maximum upward pitch when swimming in radians (default: 85 deg) |
| `yaw_limit_attached` | `number` | Clamped horizontal rotation limit when attached in radians |
| `yaw_limit_free` | `number` | Clamped horizontal rotation lead when free in radians |

### `HeadTrackingContext`

| Field | Type | Description |
| :--- | :--- | :--- |
| `attach_parent` | `ObjectRef\|nil` | Parent entity if attached |
| `is_attached` | `boolean` | Whether player is attached to a vehicle or entity |
| `look_horizontal` | `number` | Raw horizontal look yaw in radians |
| `look_vertical` | `number` | Raw vertical look pitch in radians |
| `weight` | `number` | Target posture weight multiplier |

### `HeadTrackingSubsystem`

| Field | Type | Description |
| :--- | :--- | :--- |
| `cleanup` | `function HeadTrackingSubsystem.cleanup(player_name: string)` | Purge tracking state on player disconnect  @*param* `player_name` — Player name |
| `config` | `HeadTrackingConfig` | Global configuration settings |
| `get_arm_rotations` | `function` |  |
| `get_arm_rotations_b3d` | `function` |  |
| `get_head_rotation` | `function` |  |
| `is_enabled` | `function` |  |
| `modifiers` | `table<string, fun(player: ObjectRef\|Vector3)?>` | Registered custom look modifiers |
| `refresh` | `function` |  |
| `register_modifier` | `function` |  |
| `reset` | `function` |  |
| `set_enabled` | `function` |  |
| `states` | `table<string, PlayerHeadState>` | Per-player tracking state mapping |
| `step_player` | `function` |  |
| `unregister_modifier` | `function` |  |

### `ItemActionDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `action` | `string` | Primary attack/action track name (e.g. "attack_slash", "attack_thrust", "mine") |
| `alt_action` | `string?` | Secondary action track name (e.g. "block") |
| `is_bow` | `boolean?` | Whether this item behaves as an aiming bow |
| `is_shield` | `boolean?` | Whether this item behaves as a defensive shield |
| `shoot_action` | `string?` | Bow release/fire track name (e.g. "bow_shoot") |

### `ItemClassification`

| Field | Type | Description |
| :--- | :--- | :--- |
| `action_def` | `ItemActionDefinition\|nil` | Registered item action configuration |
| `is_bow` | `boolean` | Whether item acts as a bow |
| `is_bow_charged` | `boolean` | Whether item is currently in drawn/charged state |
| `is_food` | `boolean` | Whether item is edible or consumable |
| `is_shield` | `boolean` | Whether item acts as a shield |
| `is_tool` | `boolean` | Whether item is a mining or utility tool |
| `is_weapon` | `boolean` | Whether item is a weapon intended for combat |
| `weapon_action` | `string` | Primary action track name |

### `ModelDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `animation_speed` | `number?` | Default animation playback speed |
| `animations` | `table<string, string\|AnimationDefinition>` | Legacy B3D frame ranges |
| `animations_glb` | `table<string, string\|AnimationDefinition>?` | GLB track definitions |
| `base_model` | `string?` | Optional base model name to inherit animations and physical defaults from |
| `collisionbox` | `number[]?` | Base bounding collision box |
| `eye_height` | `number?` | Base camera eye height |
| `is_multitrack` | `boolean?` | Internal flag if it has track layers |
| `mesh` | `string` | Legacy B3D mesh filename |
| `mesh_glb` | `string?` | Modern GLB mesh filename (optional) |
| `override_local` | `boolean?` | Whether local client animation prediction should be overridden |
| `stepheight` | `number?` | Step height for terrain navigation |
| `textures` | `string[]?` | Default texture file list |
| `visual_size` | `Vector2?` | Mesh scale vector |

### `PlayerAnimationData`

| Field | Type | Description |
| :--- | :--- | :--- |
| `animation` | `string\|nil` | Current active locomotion animation name |
| `animation_b3d` | `string\|nil` | Current active B3D single-timeline animation name |
| `animation_loop` | `boolean\|nil` | Whether current animation is looping |
| `animation_speed` | `number\|nil` | Current animation playback speed |
| `model` | `string\|nil` | Active model mesh filename |
| `textures` | `string[]\|nil` | Active applied texture filenames |

### `PlayerControlState`

| Field | Type | Description |
| :--- | :--- | :--- |
| `active_emote` | `string\|nil` | Active gesture or posture emote name |
| `bow_shoot_until` | `number` | Expiration timestamp for bow firing animation |
| `controls` | `table<string, boolean\|number>\|nil` | Last sampled player controls table |
| `double_tap_sprint` | `boolean` | Whether double-tap sprinting is active |
| `eat_action` | `string\|nil` | Active action identifier for eating (e.g. "eat") |
| `eat_item_name` | `string\|nil` | Cached item name being consumed for particle and audio fidelity |
| `eat_particle_type` | `string\|nil` | Cached particle generator type for eating |
| `eat_until` | `number` | Expiration timestamp for eating action |
| `emote_until` | `number` | Expiration timestamp for active emote (-1 for indefinite) |
| `equip_until` | `number\|nil` | Expiration timestamp for weapon equip montage |
| `hurt_until` | `number` | Expiration timestamp for hurt flinch |
| `keys` | `table<string, boolean\|number>` | Raw control key hold state |
| `last_chew_particle_time` | `number` | Timestamp of last chew particle emission |
| `last_press_time` | `table<string, number>` | Timestamps for double-tap detection |
| `lmb_action` | `string\|nil` | Active action identifier triggered by LMB |
| `lmb_action_until` | `number` | Expiration timestamp for LMB action duration window |
| `lmb_cycle_count` | `integer` | Number of action cycles completed |
| `prev_action_state` | `string\|nil` | Previous action state identifier |
| `prev_bow_charged` | `boolean` | Charged bow state from previous step |
| `prev_control_bits` | `integer\|nil` | Last sampled player control bitmask |
| `prev_loco_state` | `string` | Previous locomotion state identifier |
| `prev_wield_idx` | `integer\|nil` | Previous held hotbar slot index |
| `prev_wield_name` | `string\|nil` | Previous held item technical name |
| `semantic_state` | `PlayerSemanticState` | Cached semantic state table |
| `sliding_until` | `number` | Expiration timestamp for power slide |
| `was_on_ground` | `boolean` | Grounded flag from previous step |
| `wield_index` | `integer\|nil` | Current hotbar slot index |

### `PlayerControlsSubsystem`

| Field | Type | Description |
| :--- | :--- | :--- |
| `action_evaluators` | `{ priority: number, func: fun(player: ObjectRef, ctx: StateEvaluationContext):string? }[]` |  |
| `locomotion_evaluators` | `{ priority: number, func: fun(player: ObjectRef, ctx: StateEvaluationContext):string? }[]` |  |
| `player_states` | `table<string, PlayerControlState>` |  |
| `registered_on_hold` | `(fun(player: ObjectRef, key: string, duration: number))[]` |  |
| `registered_on_press` | `(fun(player: ObjectRef, key: string))[]` |  |
| `registered_on_release` | `(fun(player: ObjectRef, key: string, duration: number))[]` |  |
| `registered_on_state_change` | `fun(player: ObjectRef, state: PlayerSemanticState, prev_loco: string, prev_act?: string)[]` |  |
| `registered_on_wield_change` | `fun(player: ObjectRef, item: string, prev: string, stack: ItemStack, idx: int, p_idx: int)[]` |  |

### `PlayerHeadState`

| Field | Type | Description |
| :--- | :--- | :--- |
| `arm_current_l` | `Vector3` | Current smoothed left arm bone rotation vector {x, y, z} in radians |
| `arm_current_l_b3d` | `Vector3` | Current smoothed left arm bone rotation vector in B3D space |
| `arm_current_r` | `Vector3` | Current smoothed right arm bone rotation vector {x, y, z} in radians |
| `arm_last_sent_l` | `Vector3` | Last left arm rotation successfully dispatched over network {x, y, z} |
| `arm_last_sent_l_b3d` | `Vector3` | Last left arm rotation successfully dispatched in B3D space |
| `arm_last_sent_r` | `Vector3` | Last right arm rotation successfully dispatched over network {x, y, z} |
| `arm_target_l` | `Vector3` | Target left arm bone rotation vector {x, y, z} in radians |
| `arm_target_l_b3d` | `Vector3` | Target left arm bone rotation vector in B3D space |
| `arm_target_r` | `Vector3` | Target right arm bone rotation vector {x, y, z} in radians |
| `current` | `Vector3` | Current smoothed head bone rotation vector {x, y, z} in radians |
| `enabled` | `boolean` | Per-player tracking activation flag |
| `last_sent` | `Vector3` | Last head rotation successfully dispatched over network {x, y, z} |
| `sleeping` | `boolean` | Whether orientation is settled in idle quiescence |
| `target` | `Vector3` | Target head bone rotation vector {x, y, z} in radians |
| `virtual_body_yaw` | `number\|nil` | Smoothed body orientation for free-standing turn lead |
| `weight` | `number` | Current blending weight multiplier between 0.0 and 1.0 |

### `PlayerProxies`

| Field | Type | Description |
| :--- | :--- | :--- |
| `b3d` | `ObjectRef\|nil` | Legacy B3D visual proxy entity |
| `glb` | `ObjectRef\|nil` | Modern GLB visual proxy entity |

### `PlayerSemanticState`

| Field | Type | Description |
| :--- | :--- | :--- |
| `acting` | `boolean` | Whether player is actively mining or using item |
| `action` | `string\|nil` | Active upper-body action track or alias |
| `aiming_bow` | `boolean` | Whether player is drawing back a bow |
| `blocking` | `boolean` | Whether player is holding shield block |
| `climbing` | `boolean` | Whether player is on ladder or vine |
| `climbing_active` | `boolean` | Whether player is moving up/down a ladder |
| `crouch_walking` | `boolean` | Whether player is sneaking while moving |
| `crouching` | `boolean` | Whether player is sneaking/crouching |
| `eating` | `boolean` | Whether player is consuming food or beverage |
| `emote` | `string\|nil` | Active gesture or posture emote track or alias |
| `equipping` | `boolean` | Whether player is performing weapon equip animation |
| `falling` | `boolean` | Whether player is descending in free-fall |
| `flying` | `boolean` | Whether player is flying with flight speed |
| `hovering` | `boolean` | Whether player is hovering in air |
| `hurt` | `boolean` | Whether player is reacting to damage |
| `jumping` | `boolean` | Whether player is ascending in jump arc |
| `locomotion` | `string` | Active locomotion animation track or alias |
| `moving` | `boolean` | Whether player has directional horizontal motion |
| `shooting_bow` | `boolean` | Whether player is releasing a bow shot |
| `sliding` | `boolean` | Whether player is power-sliding |
| `sprinting` | `boolean` | Whether player is sprinting |
| `swimming` | `boolean` | Whether player is in water or submerged |

### `StateEvaluationContext`

| Field | Type | Description |
| :--- | :--- | :--- |
| `controls` | `table<string, boolean>` | Raw player control keys |
| `hp` | `number` | Player health points |
| `in_air` | `boolean` | Whether player is airborne |
| `in_water` | `boolean` | Whether player is submerged in liquid |
| `is_attached` | `boolean?` | Whether player is attached to a vehicle, mount, or object |
| `is_equipping` | `boolean` | Whether weapon equip animation is active |
| `is_hurt` | `boolean` | Whether hurt flinch is active |
| `is_moving` | `boolean` | Whether player has directional movement |
| `is_sprinting` | `boolean` | Whether player is sprinting |
| `item_info` | `ItemClassification` | Classification of held item |
| `on_ladder` | `boolean` | Whether player is attached to a climbable node |
| `player` | `ObjectRef` | Target player |
| `pos` | `Vector3` | Player world position |
| `time_now` | `number` | Current server timestamp in seconds |
| `vel` | `Vector3` | Player velocity vector |
| `wield_name` | `string` | Name of currently wielded item |

### `Vector2`

| Field | Type | Description |
| :--- | :--- | :--- |
| `x` | `number` |  |
| `y` | `number` |  |

### `Vector3`

| Field | Type | Description |
| :--- | :--- | :--- |
| `x` | `number` |  |
| `y` | `number` |  |
| `z` | `number` |  |

### `WieldItemCustomDef`

Custom wield properties specified directly inside an item or node definition.
Following Luanti engine conventions (lua_api.md), custom fields must use flat prefixes starting
with an underscore (`_`) to avoid naming collisions with future engine usage.

| Field | Type | Description |
| :--- | :--- | :--- |
| `_wield_glow` | `number?` | Explicit entity glow brightness level (0-14) |
| `_wield_offset` | `Vector3?` | Translation offset relative to base hand attachment |
| `_wield_rotation` | `Vector3?` | Euler rotation in degrees (X, Y, Z) |
| `_wield_scale` | `(number\|Vector3)?` | Visual scale multiplier (scalar number or Vector3) |

### `WieldItemEntityData`

| Field | Type | Description |
| :--- | :--- | :--- |
| `attached_forced` | `boolean?` | Currently attached forced_visible flag (fallback) |
| `attached_forced_b3d` | `boolean?` | Currently attached forced_visible flag on B3D proxy |
| `attached_forced_glb` | `boolean?` | Currently attached forced_visible flag on GLB proxy |
| `attached_pos` | `Vector3?` | Currently attached relative position (fallback) |
| `attached_pos_b3d` | `Vector3?` | Currently attached relative position on B3D proxy |
| `attached_pos_glb` | `Vector3?` | Currently attached relative position on GLB proxy |
| `attached_rot` | `Vector3?` | Currently attached relative rotation (fallback) |
| `attached_rot_b3d` | `Vector3?` | Currently attached relative rotation on B3D proxy |
| `attached_rot_glb` | `Vector3?` | Currently attached relative rotation on GLB proxy |
| `b3d` | `ObjectRef\|nil` | Attached child entity for legacy B3D visual proxy |
| `first_person` | `boolean?` | Per-player 1st person visibility preference |
| `glb` | `ObjectRef\|nil` | Attached child entity for modern GLB visual proxy |
| `item` | `string` | Current cached item key |
| `last_wield_name` | `string?` | Last checked wielded item name |
| `obj` | `ObjectRef\|nil` | Active attached child LuaEntity (glb or b3d for backward compatibility) |
| `visible` | `boolean` | User-controlled visibility flag |

### `WieldOffsetDefinition`

| Field | Type | Description |
| :--- | :--- | :--- |
| `glow` | `number?` | Explicit entity glow override (0-14) |
| `pos` | `Vector3?` | Translation offset relative to base hand attachment |
| `pos_b3d` | `Vector3?` | Format-specific translation offset for B3D models |
| `pos_glb` | `Vector3?` | Format-specific translation offset for GLB models |
| `rot` | `Vector3?` | Euler rotation in degrees (X, Y, Z) |
| `rot_b3d` | `Vector3?` | Format-specific Euler rotation for B3D models |
| `rot_glb` | `Vector3?` | Format-specific Euler rotation for GLB models |
| `scale` | `(number\|Vector3)?` | Scale multipliers for visual_size |

### `WieldOffsetsRegistry`

| Field | Type | Description |
| :--- | :--- | :--- |
| `groups` | `table<string, WieldOffsetDefinition>` |  |
| `items` | `table<string, WieldOffsetDefinition>` |  |
| `types` | `table<string, WieldOffsetDefinition>` |  |

---

## Type Aliases & Callbacks

| Type Alias | Signature / Definition |
| :--- | :--- |
| `HeadTrackingModifier` | `fun(player: ObjectRef\|Vector3)?` |
| `ModelRedirectRule` | `string\|fun(player: ObjectRef\|nil, model: string):string\|nil` |
| `ParticleGeneratorFunc` | `fun(player: ObjectRef, item_name?: string, duration?: number):integer?` |
| `StateChangeCallback` | `fun(player: ObjectRef, state: PlayerSemanticState, prev_loco: string, prev_act?: string)` |
| `StateEvaluatorFunc` | `fun(player: ObjectRef, ctx: StateEvaluationContext):string?` |
| `WieldChangeCallback` | `fun(player: ObjectRef, item: string, prev: string, stack: ItemStack, idx: int, p_idx: int)` |

---

## Core & Model API

Model registration, format switching (GLB multi-track vs. B3D single-track), model redirects, animation tracks, and skin textures.

#### `x_player_api.apply_model_redirects`

Apply model redirects (deprecated no-op hook maintained for legacy backwards compatibility)

```lua
function x_player_api.apply_model_redirects()
```

#### `x_player_api.edit_model_animation`

Edit an existing animation definition on a model

```lua
function x_player_api.edit_model_animation(model_name: string, anim_name: string, def: table)
  -> success: boolean
```

**Parameters:**

* `model_name` (`string`): Registered model name
* `anim_name` (`string`): Animation identifier
* `def` (`table`): Table of animation properties to update

**Returns:**

* `success` (`boolean`): True if animation was found and updated

#### `x_player_api.evaluate_b3d_animation`

Evaluate and resolve the single-timeline animation specifically for B3D models
Pure input/state-driven evaluation for single-timeline models

```lua
function x_player_api.evaluate_b3d_animation(player: ObjectRef, state: PlayerSemanticState, model: table)
  -> chosen_anim: string
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `state` (`PlayerSemanticState`): Semantic player state evaluated by controls module
* `model` (`table`): Active model definition

**Returns:**

* `chosen_anim` (`string`): Evaluated single-timeline animation identifier

#### `x_player_api.get_animation`

Get current animation data for player

```lua
function x_player_api.get_animation(player: ObjectRef)
  -> animation_data: PlayerAnimationData
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `animation_data` (`PlayerAnimationData`): Active animation and model metadata

#### `x_player_api.get_default_model`

Get default player model definition

```lua
function x_player_api.get_default_model()
  -> model_name: string
```

**Returns:**

* `model_name` (`string`): Default resolved model identifier ("character")

#### `x_player_api.get_item_texture`

Determine the texture filename or modifier string for an item

```lua
function x_player_api.get_item_texture(iname: string)
  -> texture: string|nil
```

**Parameters:**

* `iname` (`string`): Item name

**Returns:**

* `texture` (`string|nil`): Texture name or modifier string

#### `x_player_api.get_model`

Get registered model definition

```lua
function x_player_api.get_model(name_or_player: string|ObjectRef)
  -> model: ModelDefinition|nil
```

**Parameters:**

* `name_or_player` (`string|ObjectRef`): Model name or player object

**Returns:**

* `model` (`ModelDefinition|nil`): Registered model definition or nil if not registered

#### `x_player_api.get_model_format`

Get active global model format preferred by the server

```lua
function x_player_api.get_model_format()
  -> format: "b3d"|"glb"
```

**Returns:**

* `format` (`"b3d"|"glb"`): Preferred model format ("glb" or "b3d")

#### `x_player_api.get_model_name`

Get current model name assigned to player

```lua
function x_player_api.get_model_name(player: ObjectRef)
  -> model_name: string
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `model_name` (`string`)

#### `x_player_api.get_textures`

Get current textures assigned to player

```lua
function x_player_api.get_textures(player: ObjectRef)
  -> textures: string[]
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `textures` (`string[]`): List of applied texture filenames

#### `x_player_api.recompute_model_metadata`

Recompute internal metadata for a model definition

```lua
function x_player_api.recompute_model_metadata(def: ModelDefinition)
```

**Parameters:**

* `def` (`ModelDefinition`): Model parameters and animation table

#### `x_player_api.register_animation_alias`

Register an animation alias

```lua
function x_player_api.register_animation_alias(alias: string, target: string)
```

**Parameters:**

* `alias` (`string`): Semantic alias
* `target` (`string`): Canonical animation track identifier

#### `x_player_api.register_model`

Register a player 3D model with animation definitions and physical properties

```lua
function x_player_api.register_model(name: string, def: ModelDefinition)
```

**Parameters:**

* `name` (`string`): Model registry name (e.g. "character")
* `def` (`ModelDefinition`): Model parameters, animations, and physical properties

#### `x_player_api.register_model_animation`

Register a new animation to an existing model

```lua
function x_player_api.register_model_animation(model_name: string, anim_name: string, def: string|AnimationDefinition)
  -> success: boolean
```

**Parameters:**

* `model_name` (`string`): Target model identifier
* `anim_name` (`string`): Animation track or action identifier
* `def` (`string|AnimationDefinition`): Animation configuration or track string

**Returns:**

* `success` (`boolean`): Whether the animation was successfully registered

#### `x_player_api.register_model_redirect`

Register a model redirect or dynamic transformer

```lua
function x_player_api.register_model_redirect(source_model: string, target_model_or_fn: string|fun(player: ObjectRef|nil, model: string):string|nil)
```

**Parameters:**

* `source_model` (`string`): Source model name to intercept
* `target_model_or_fn` (`string|fun(player: ObjectRef|nil, model: string):string|nil`): Target model name or callback

#### `x_player_api.register_wield_texture_transform`

Register a texture transform modifier for a wielded item or group

```lua
function x_player_api.register_wield_texture_transform(identifier: string, transform: string)
```

**Parameters:**

* `identifier` (`string`): Item name ("screwdriver:screwdriver") or group ("group:screwdriver")
* `transform` (`string`): Transform modifier string without the "^[transform" prefix (e.g. "R90", "R270", "FX")

#### `x_player_api.remove_model_animation`

Remove an animation definition from a model

```lua
function x_player_api.remove_model_animation(model_name: string, anim_name: string)
  -> success: boolean
```

**Parameters:**

* `model_name` (`string`): Registered model name
* `anim_name` (`string`): Animation identifier to remove

**Returns:**

* `success` (`boolean`): True if animation was removed

#### `x_player_api.resolve_model`

Resolve model redirect rules (supports multi-hop chained redirects)

```lua
function x_player_api.resolve_model(player?: ObjectRef, model_name: string)
  -> resolved_model: string
```

**Parameters:**

* `player` (`ObjectRef?`): Optional player context
* `model_name` (`string`): Requested model name

**Returns:**

* `resolved_model` (`string`): Resolved model name

#### `x_player_api.scan_and_wiggle_b3d_model`

Scan and wiggle a specific B3D model, registering dynamic media and redirection if needed

```lua
function x_player_api.scan_and_wiggle_b3d_model(mesh_name: string, full_path?: string)
  -> resolved_name: string
```

**Parameters:**

* `mesh_name` (`string`): The original mesh filename (e.g. "character.b3d")
* `full_path` (`string?`): Optional absolute path to the mesh file

**Returns:**

* `resolved_name` (`string`): The model name to use (original or redirected)

#### `x_player_api.scan_and_wiggle_registered_b3d_models`

Scan all registered B3D models and apply dynamic wiggling to any unpatched models

```lua
function x_player_api.scan_and_wiggle_registered_b3d_models()
```

#### `x_player_api.set_animation`

Set active animation for player
Set animation on player ObjectRef, synchronizing visual proxies

```lua
function x_player_api.set_animation(player: ObjectRef, anim_name: string, speed?: number, loop_or_blend?: boolean|number, override_local?: boolean, anim_name_b3d?: boolean|string)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `anim_name` (`string`): Animation identifier for GLB proxy (locomotion layer in multitrack)
* `speed` (`number?`): Playback speed (defaults to model's animation_speed)
* `loop_or_blend` (`(boolean|number)?`): Whether to loop playback (boolean) or transition blend time in seconds (number)
* `override_local` (`boolean?`): Whether local client animation prediction should be overridden
* `anim_name_b3d` (`(boolean|string)?`): Optional animation ID for B3D proxy, or false to skip B3D

#### `x_player_api.set_model`

Update player model and reset appearance/animations

```lua
function x_player_api.set_model(player: ObjectRef, model_name: string)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `model_name` (`string`): Target model filename

#### `x_player_api.set_model_format`

Set active global model format preferred by the server

```lua
function x_player_api.set_model_format(format: "b3d"|"glb")
  -> success: boolean
  2. error_or_format: string?
```

**Parameters:**

* `format` (`"b3d"|"glb"`): Preferred model format

**Returns:**

* `success` (`boolean`): Whether format was accepted
* `error_or_format` (`string?`): Error message on failure, or confirmed format on success

#### `x_player_api.set_texture`

Set a single texture layer by index

```lua
function x_player_api.set_texture(player: ObjectRef, index: integer, texture: string)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `index` (`integer`): 1-based texture slot index
* `texture` (`string`): Texture filename or modifier string

#### `x_player_api.set_textures`

Set textures for player

```lua
function x_player_api.set_textures(player: ObjectRef, textures: string[])
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `textures` (`string[]`): List of texture filenames

#### `x_player_api.step_b3d_animation`

Step and resolve single-timeline animations specifically for B3D models
Directly drives B3D visual proxy and native player skeletal bones concurrently for all observers

```lua
function x_player_api.step_b3d_animation(player: ObjectRef, state: PlayerSemanticState, model: table, animation_speed_mod: number)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `state` (`PlayerSemanticState`): Semantic player state evaluated by controls module
* `model` (`table`): Active model definition
* `animation_speed_mod` (`number`): Calculated animation playback speed

---

## Visual Proxies & Observers API

Dual-model visual proxy entities (`x_player_api:visual_glb`, `x_player_api:visual_b3d`), observer cohort management (`set_observers`) for Luanti 5.17.0+ modern vs legacy clients, and bone override dispatching with network throttling.

#### `x_player_api.cleanup_orphaned_proxies`

Clean up all orphaned or disconnected player visual proxies across the server

```lua
function x_player_api.cleanup_orphaned_proxies()
  -> count: number
```

**Returns:**

* `count` (`number`): Number of cleaned up proxy entities

#### `x_player_api.cleanup_player_proxies`

```lua
function
```

#### `x_player_api.ensure_player_cohort`

Ensure a player's client protocol cohort has been classified

```lua
function x_player_api.ensure_player_cohort(player_name: string, force?: boolean)
  -> resolved: boolean
```

**Parameters:**

* `player_name` (`string`): Connected player username
* `force` (`boolean?`): Force re-evaluation even if already classified

**Returns:**

* `resolved` (`boolean`): True if cohort was successfully resolved from player info

#### `x_player_api.get_bone_override`

Get the active bone override state for a player

```lua
function x_player_api.get_bone_override(player: ObjectRef, bone: string)
  -> override: CachedBoneState|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `bone` (`string`): Target bone name

**Returns:**

* `override` (`CachedBoneState|nil`): Cached bone state or nil

#### `x_player_api.get_legacy_observers`

Get the observer cohort set of legacy clients

```lua
function x_player_api.get_legacy_observers()
  -> observers: table<string, boolean>
```

**Returns:**

* `observers` (`table<string, boolean>`): Map of player name to true

#### `x_player_api.get_modern_observers`

Get the observer cohort set of modern clients

```lua
function x_player_api.get_modern_observers()
  -> observers: table<string, boolean>
```

**Returns:**

* `observers` (`table<string, boolean>`): Map of player name to true

#### `x_player_api.get_visual_proxies`

Get the active visual proxy entities for a player, auto-healing any invalid ObjectRefs

```lua
function x_player_api.get_visual_proxies(player: ObjectRef)
  -> proxies: PlayerProxies|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `proxies` (`PlayerProxies|nil`): Visual proxy entity container

#### `x_player_api.is_modern_client`

Check if a connected player is using a modern client supporting glTF multi-track animations

```lua
function x_player_api.is_modern_client(player_name: string)
  -> is_modern: boolean
```

**Parameters:**

* `player_name` (`string`): Connected player username

**Returns:**

* `is_modern` (`boolean`): True if client uses Luanti 5.17.0+ protocol

#### `x_player_api.refresh_observers`

Refresh observer visibility sets on all active visual proxy entities and wield items across connected players

```lua
function x_player_api.refresh_observers()
```

#### `x_player_api.set_bone_override`

Set a bone position and rotation override with network throttling and dual-format parity
Applies pitch, yaw, and roll rotation to visual proxy entities.
Automatically compensates for Blitz3D exporter bone coordinate inversions (negated rotation axes
and reflected X/Z position) so GLB and B3D visual proxies maintain identical orientation in-game.
Optionally accepts an explicit B3D rotation payload for bones with complex dual-rig kinematics
(e.g. Arm_Left bow aim).
Throttles Head and Arm bone updates below 0.08 radians (~4.5 degrees) to optimize multiplayer bandwidth.

```lua
function x_player_api.set_bone_override(player: ObjectRef, bone: string, position: Vector3|nil, rotation: Vector3, force?: boolean, interpolation?: number, absolute?: boolean, b3d_rotation?: Vector3)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `bone` (`string`): Target bone name (e.g. "Head", "Arm_Right", "Arm_Left")
* `position` (`Vector3|nil`): Local bone translation offset (omitted if nil to preserve bone rest position)
* `rotation` (`Vector3`): Local bone rotation in radians
* `force` (`boolean?`): Optional flag to bypass angular delta throttling
* `interpolation` (`number?`): Optional interpolation duration in seconds (default: 0.1)
* `absolute` (`boolean?`): Optional flag indicating whether rotation/position is absolute (default: true)
* `b3d_rotation` (`Vector3?`): Optional explicit B3D rotation override vector in radians

---

## Head & Arm Look Tracking API

Natural head bone look tracking and synchronized dual-arm pitch aiming with biomechanical clamping, exponential temporal smoothing, attached yaw tracking, body turn lag, extensible modifier callbacks, and bandwidth-optimized quiescence sleep states.

#### `x_player_api.get_arm_rotations`

Get the current smoothed arm rotation vectors for a player (alias)

```lua
function x_player_api.get_arm_rotations(player: ObjectRef)
  -> right_arm: Vector3?
  2. left_arm: Vector3?
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `right_arm` (`Vector3?`): Smoothed rotation vector for Arm_Right in radians
* `left_arm` (`Vector3?`): Smoothed rotation vector for Arm_Left in radians

#### `x_player_api.get_head_rotation`

Get the current smoothed head rotation vector for a player

```lua
function x_player_api.get_head_rotation(player: ObjectRef)
  -> rotation: Vector3?
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `rotation` (`Vector3?`): Smoothed head rotation vector {x, y, z} in radians, or nil if player invalid

#### `x_player_api.get_head_tracking_arm_rotations`

Get the current smoothed arm rotation vectors for a player

```lua
function x_player_api.get_head_tracking_arm_rotations(player: ObjectRef)
  -> right_arm: Vector3?
  2. left_arm: Vector3?
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `right_arm` (`Vector3?`): Smoothed rotation vector for Arm_Right in radians
* `left_arm` (`Vector3?`): Smoothed rotation vector for Arm_Left in radians

#### `x_player_api.get_head_tracking_arm_rotations_b3d`

Get the current smoothed arm rotation vectors for B3D space

```lua
function x_player_api.get_head_tracking_arm_rotations_b3d(player: ObjectRef)
  -> right_arm: Vector3?
  2. left_arm: Vector3?
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `right_arm` (`Vector3?`): Smoothed rotation vector for Arm_Right in B3D space
* `left_arm` (`Vector3?`): Smoothed rotation vector for Arm_Left in B3D space

#### `x_player_api.is_head_tracking_enabled`

Check whether head and arm tracking is active for a player

```lua
function x_player_api.is_head_tracking_enabled(player: ObjectRef)
  -> enabled: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `enabled` (`boolean`): Whether tracking is currently active for this player

#### `x_player_api.refresh_head_tracking`

Immediately re-sends current smoothed head and arm bone overrides to all proxies (e.g. on model/format toggle)

```lua
function x_player_api.refresh_head_tracking(player: ObjectRef)
```

**Parameters:**

* `player` (`ObjectRef`): Target player

#### `x_player_api.register_head_tracking_modifier`

Register a custom head tracking modifier callback (Open/Closed Principle)
Allows external mods to dynamically adjust target rotation angles and posture weight.

```lua
function x_player_api.register_head_tracking_modifier(name: string, func?: fun(player: ObjectRef|Vector3))
```

**Parameters:**

* `name` (`string`): Unique modifier identifier
* `func` (`fun(player: ObjectRef|Vector3)?`): Callback function receiving (player, semantic_state, ctx)

#### `x_player_api.reset_head_tracking`

Reset head and arm rotations to bind pose (0, 0, 0) and sleep state
Dispatches immediate bone overrides to restore the default animation bind pose.

```lua
function x_player_api.reset_head_tracking(player: ObjectRef)
```

**Parameters:**

* `player` (`ObjectRef`): Target player

#### `x_player_api.set_head_tracking_enabled`

Enable or disable head and arm tracking for a specific player
Resets bones to bind pose immediately if disabled.

```lua
function x_player_api.set_head_tracking_enabled(player: ObjectRef, enabled: boolean)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `enabled` (`boolean`): Activation flag

#### `x_player_api.step_head_tracking`

Step head tracking simulation and network dispatch for a player
Evaluates camera look pitch and yaw, applies posture weights and anatomical limits,
smooths rotations with exponential decay, and dispatches throttled bone overrides.

```lua
function x_player_api.step_head_tracking(player: ObjectRef, dtime: number, semantic_state?: PlayerSemanticState)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `dtime` (`number`): Delta time in seconds since last server step
* `semantic_state` (`PlayerSemanticState?`): Active player semantic state

#### `x_player_api.unregister_head_tracking_modifier`

Unregister a custom head tracking modifier

```lua
function x_player_api.unregister_head_tracking_modifier(name: string)
```

**Parameters:**

* `name` (`string`): Modifier identifier to remove

---

## Locomotion & Action Controls API

Input control handlers, high-level semantic locomotion/action state evaluation, custom evaluators, social emotes, and reaction triggers.

#### `x_player_api.clear_equip_sound_cache`

Clear internal equip sound resolution cache

```lua
function x_player_api.clear_equip_sound_cache()
```

#### `x_player_api.clear_item_cache`

Clear internal item classification cache

```lua
function x_player_api.clear_item_cache()
```

#### `x_player_api.get_equip_sound`

Get registered or inferred equip sound definition for an item
Resolution precedence:
  - Direct item match in registry
  - Item definition `_equip_sound` field
  - Group matches in registry (`group:...`)

```lua
function x_player_api.get_equip_sound(item_name: string)
  -> equip_sound: EquipSoundDefinition|nil
```

**Parameters:**

* `item_name` (`string`): Item technical name

**Returns:**

* `equip_sound` (`EquipSoundDefinition|nil`): Registered sound definition, or nil if none/suppressed

#### `x_player_api.get_item_action`

Get registered action configuration for an item name

```lua
function x_player_api.get_item_action(item_name: string)
  -> action_def: ItemActionDefinition|nil
```

**Parameters:**

* `item_name` (`string`): Item name

**Returns:**

* `action_def` (`ItemActionDefinition|nil`): Registered configuration or nil

#### `x_player_api.get_player_control_bits`

Get integer control bitmask from active player controls

```lua
function x_player_api.get_player_control_bits(controls: table<string, boolean>)
  -> bitmask: integer
```

**Parameters:**

* `controls` (`table<string, boolean>`)

**Returns:**

* `bitmask` (`integer`): 9-bit packed integer mask

#### `x_player_api.get_player_state`

Evaluate high-level locomotion and action state for a player

```lua
function x_player_api.get_player_state(player: ObjectRef, time_now?: number)
  -> state: PlayerSemanticState
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `time_now` (`number?`): Optional timestamp in seconds to avoid redundant system calls

**Returns:**

* `state` (`PlayerSemanticState`): High-level locomotion, action, and movement flags

#### `x_player_api.globalstep`

Check each player and apply animations

```lua
function x_player_api.globalstep(dtime: number)
```

**Parameters:**

* `dtime` (`number`): Delta time in seconds since last server step

#### `x_player_api.play_action`

Play an action animation directly on a player

```lua
function x_player_api.play_action(player: ObjectRef, action?: string, force?: boolean, skip_b3d?: boolean)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `action` (`string?`): Action animation track name or nil to stop active action
* `force` (`boolean?`): Force replay even if the action is already active
* `skip_b3d` (`boolean?`): When true, skip updating B3D proxy and player entity (used in globalstep)

#### `x_player_api.play_emote`

Play a gesture or posture emote

```lua
function x_player_api.play_emote(player: ObjectRef, emote_name: string, duration: number|nil)
```

**Parameters:**

* `player` (`ObjectRef`)
* `emote_name` (`string`)
* `duration` (`number|nil`)

#### `x_player_api.play_equip_sound`

Play the equip sound for an item if configured

```lua
function x_player_api.play_equip_sound(player: ObjectRef, item_name: string)
  -> success: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `item_name` (`string`): Item technical name

**Returns:**

* `success` (`boolean`): Whether a sound was played

#### `x_player_api.register_action_evaluator`

Register a custom action state evaluator

```lua
function x_player_api.register_action_evaluator(priority: number, evaluator: fun(player: ObjectRef, ctx: StateEvaluationContext):string?)
```

**Parameters:**

* `priority` (`number`): Higher numbers evaluate first
* `evaluator` (`fun(player: ObjectRef, ctx: StateEvaluationContext):string?`): Return state name string or nil to fall through

#### `x_player_api.register_emote`

Register a player emote

```lua
function x_player_api.register_emote(name: string, def: EmoteDefinition)
```

**Parameters:**

* `name` (`string`): Emote animation / command name
* `def` (`EmoteDefinition`): Emote definition

#### `x_player_api.register_equip_sound`

Register or override an equip sound for an item name or group

```lua
function x_player_api.register_equip_sound(item_or_group: string, def: boolean|string|EquipSoundDefinition)
```

**Parameters:**

* `item_or_group` (`string`): Item name or group filter (e.g. "group:sword", "default:sword_steel")
* `def` (`boolean|string|EquipSoundDefinition`): Sound name, definition table, or false to suppress sound

#### `x_player_api.register_item_action`

Register an action definition for an item name or group

```lua
function x_player_api.register_item_action(item_or_group: string, def: string|ItemActionDefinition)
```

**Parameters:**

* `item_or_group` (`string`): Item name or group filter (e.g. "group:sword", "default:sword_steel")
* `def` (`string|ItemActionDefinition`): Action name string or definition table

#### `x_player_api.register_locomotion_evaluator`

Register a custom locomotion state evaluator

```lua
function x_player_api.register_locomotion_evaluator(priority: number, evaluator: fun(player: ObjectRef, ctx: StateEvaluationContext):string?)
```

**Parameters:**

* `priority` (`number`): Higher numbers evaluate first
* `evaluator` (`fun(player: ObjectRef, ctx: StateEvaluationContext):string?`): Return state name string or nil to fall through

#### `x_player_api.register_on_state_change`

Register a callback invoked whenever high-level player state changes

```lua
function x_player_api.register_on_state_change(callback: fun(player: ObjectRef, state: PlayerSemanticState, prev_loco: string, prev_act?: string))
```

**Parameters:**

* `callback` (`fun(player: ObjectRef, state: PlayerSemanticState, prev_loco: string, prev_act?: string)`)

#### `x_player_api.register_weapon_category`

Register or override a weapon category mapping

```lua
function x_player_api.register_weapon_category(category: string, action: string)
```

**Parameters:**

* `category` (`string`): Group filter (e.g. "group:spear") or exact item name
* `action` (`string`): Primary action track name (e.g. "attack_thrust")

#### `x_player_api.reset_transient_controls_state`

```lua
function
```

#### `x_player_api.stop_emote`

Stop any active gesture or posture emote

```lua
function x_player_api.stop_emote(player: ObjectRef)
```

**Parameters:**

* `player` (`ObjectRef`)

#### `x_player_api.trigger_b3d_action`

Safe trigger forwarder for backwards compatibility

```lua
function x_player_api.trigger_b3d_action(player: any, action: any, duration: any)
```

**Parameters:**

* `player` (`any`)
* `action` (`any`)
* `duration` (`any`)

#### `x_player_api.trigger_bow_shoot`

Trigger bow shoot animation externally

```lua
function x_player_api.trigger_bow_shoot(player: ObjectRef, duration?: number)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `duration` (`number?`): Duration in seconds (defaults to 0.35s)

#### `x_player_api.trigger_equip`

Trigger the weapon equip montage on a player if the active model supports it, and play equip sound

```lua
function x_player_api.trigger_equip(player: ObjectRef, item_name?: string)
  -> success: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `item_name` (`string?`): Item name being equipped (optional, resolved from wield item if omitted)

**Returns:**

* `success` (`boolean`): Whether equip animation was started

#### `x_player_api.trigger_hurt`

Trigger hurt reaction animation externally

```lua
function x_player_api.trigger_hurt(player: ObjectRef, duration?: number)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `duration` (`number?`): Duration in seconds (defaults to 0.35s)

#### `x_player_api.trigger_player_action`

Trigger an explicit action duration window on a player (for combat hits, mining, swings)

```lua
function x_player_api.trigger_player_action(player: ObjectRef, action?: string, duration?: number)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `action` (`string?`): Optional explicit action name (e.g. "mine", "attack_slash")
* `duration` (`number?`): Optional duration in seconds (defaults to ACTION_DURATION)

#### `x_player_api.update_player_controls`

Update raw keys and detect presses, holds, releases, double-taps

```lua
function x_player_api.update_player_controls(player: ObjectRef, _dtime: number, time_now?: number)
```

**Parameters:**

* `player` (`ObjectRef`)
* `_dtime` (`number`)
* `time_now` (`number?`): Optional timestamp in seconds to avoid redundant system calls

---

## Eating & Consumables API

Consumable items registry, particle generators, authentic crumb/liquid particle spawning, and eating animation triggers.

#### `x_player_api.cancel_eat`

Cancel active eating animation, clear state, and stop particle emitters

```lua
function x_player_api.cancel_eat(player: ObjectRef)
  -> was_eating: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `was_eating` (`boolean`): Whether player was actively eating

#### `x_player_api.clear_consumable_cache`

Clear internal consumable definition cache

```lua
function x_player_api.clear_consumable_cache()
```

#### `x_player_api.get_consumable_definition`

Resolve consumable definition for an item name from explicit registrations or item groups

```lua
function x_player_api.get_consumable_definition(item_name?: string)
  -> def: ConsumableDefinition
```

**Parameters:**

* `item_name` (`string?`): Target item technical name

**Returns:**

* `def` (`ConsumableDefinition`): Resolved consumable definition

#### `x_player_api.get_synchronized_particle_velocity`

Calculate player-local velocity for attached particle spawners with Galilean relativity
Projects player 3D world velocity (including mount/vehicle motion) into the player's local reference frame
and offsets it with base ejection scatter.

```lua
function x_player_api.get_synchronized_particle_velocity(player: ObjectRef, base_minvel: Vector3, base_maxvel: Vector3)
  -> minvel: Vector3
  2. maxvel: Vector3
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `base_minvel` (`Vector3`): Base local ejection min velocity (forward +Z, scatter +-X, drop -Y)
* `base_maxvel` (`Vector3`): Base local ejection max velocity

**Returns:**

* `minvel` (`Vector3`): Local synchronized minimum velocity
* `maxvel` (`Vector3`): Local synchronized maximum velocity

#### `x_player_api.is_consumable`

Check if an item name represents an edible or consumable item

```lua
function x_player_api.is_consumable(item_name?: string)
  -> is_consumable: boolean
```

**Parameters:**

* `item_name` (`string?`): Target item technical name

**Returns:**

* `is_consumable` (`boolean`): True if item is explicitly or heuristically consumable

#### `x_player_api.register_consumable`

Register an item or group as a consumable with specific action, sound, and particle effects

```lua
function x_player_api.register_consumable(item_or_group: string, def: ConsumableDefinition)
```

**Parameters:**

* `item_or_group` (`string`): e.g. "x_farming:bread", "group:food", "potions:healing"
* `def` (`ConsumableDefinition`): Consumable configuration definition

#### `x_player_api.register_particle_generator`

Register a custom particle generator for consumables or action triggers

```lua
function x_player_api.register_particle_generator(type_name: string, generator: fun(player: ObjectRef, item_name?: string, duration?: number):integer?)
```

**Parameters:**

* `type_name` (`string`): Identifier (e.g. "crumbs", "liquid_drops", "none")
* `generator` (`fun(player: ObjectRef, item_name?: string, duration?: number):integer?`): Generator function returning particle spawner ID

#### `x_player_api.set_eating_enabled`

Set whether eating animations, sounds, and particle simulations are enabled

```lua
function x_player_api.set_eating_enabled(enabled: boolean)
```

**Parameters:**

* `enabled` (`boolean`): Whether eating simulation should be active

#### `x_player_api.spawn_eat_particles`

Spawn eating crumbs or liquid particlespawner with modern definition fields and micro-burst synchronization

```lua
function x_player_api.spawn_eat_particles(player: ObjectRef, item_name?: string, duration?: number, particle_type?: string)
  -> spawner_id: integer|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `item_name` (`string?`): Consumed item name
* `duration` (`number?`): Particle effect duration in seconds
* `particle_type` (`string?`): Optional generator type override

**Returns:**

* `spawner_id` (`integer|nil`): Particle spawner identifier of initial burst

#### `x_player_api.trigger_eat`

Trigger eating or drinking animation externally

```lua
function x_player_api.trigger_eat(player: ObjectRef, duration?: number, item_name?: string)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `duration` (`number?`): Action duration in seconds
* `item_name` (`string?`): Consumed item name

---

## 3D Wield Item API

Native 3D wielded item rendering via ephemeral Arm_Right child LuaEntity, attachment positioning, rotation offsets, and visibility control.

#### `x_player_api.attach_left_wield_item`

Attach or configure a 3D wield item on the player's left hand (Arm_Left) following SOLID principles.
Optionally visible in 1st person view via options.first_person.

```lua
function x_player_api.attach_left_wield_item(player: ObjectRef, item_or_stack: string|ItemStack, options?: table)
  -> entity: ObjectRef|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `item_or_stack` (`string|ItemStack`): Held item name or ItemStack
* `options` (`table?`): Optional params: first_person, pos, rot, scale, glow, bone

**Returns:**

* `entity` (`ObjectRef|nil`): Attached entity reference or nil

#### `x_player_api.attach_wield_item`

Attach or re-attach the ephemeral wield item entity to player's Arm_Right bone

```lua
function x_player_api.attach_wield_item(player: ObjectRef, force?: boolean)
  -> entity: ObjectRef|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `force` (`boolean?`): Force recreation of existing entity

**Returns:**

* `entity` (`ObjectRef|nil`): Attached entity reference or nil

#### `x_player_api.attach_wield_item_to_entity`

Attach or spawn a 3D wield item entity to an arbitrary entity bone (corpses, mobs, visual proxies)

```lua
function x_player_api.attach_wield_item_to_entity(parent: ObjectRef, item_or_stack: string|ItemStack, format_override?: string, bone?: string, entity_name?: string, forced_visible?: boolean, options?: table)
  -> wield_ent: ObjectRef|nil
```

**Parameters:**

* `parent` (`ObjectRef`): Target parent object to attach to
* `item_or_stack` (`string|ItemStack`): Held item name or ItemStack
* `format_override` (`string?`): Model format ("glb" or "b3d", defaults to active format or "b3d")
* `bone` (`string?`): Target bone name (defaults to "Arm_Right")
* `entity_name` (`string?`): Registered entity name (defaults to "x_player_api:wield_item")
* `forced_visible` (`boolean?`): Visibility override (true for standalone entities, false for player proxies)
* `options` (`table?`): Optional visual/mesh/transform options

**Returns:**

* `wield_ent` (`ObjectRef|nil`): The spawned and attached entity or nil

#### `x_player_api.clear_wield_params_cache`

Clear internal wield attachment parameter cache

```lua
function x_player_api.clear_wield_params_cache()
```

#### `x_player_api.get_left_wield_attachment_params`

Calculates visual size, position offset, rotation, glow, and color for a left-hand wielded item.
Mirrors the canonical right-hand offsets onto Arm_Left coordinates.

```lua
function x_player_api.get_left_wield_attachment_params(wield_stack: string|ItemStack, format_override?: string)
  -> visual_size: Vector3
  2. pos: Vector3
  3. rot: Vector3
  4. glow: number
  5. item_color: string?
```

**Parameters:**

* `wield_stack` (`string|ItemStack`): Held item name or ItemStack
* `format_override` (`string?`): Target mesh format ("glb" or "b3d")

**Returns:**

* `visual_size` (`Vector3`): Scaled entity visual_size
* `pos` (`Vector3`): Relative translation vector on Arm_Left
* `rot` (`Vector3`): Euler rotation in degrees on Arm_Left
* `glow` (`number`): Glow brightness (0-14)
* `item_color` (`string?`): Optional color tint

#### `x_player_api.get_left_wield_entity`

Returns the active left-hand wield entity reference for a player.

```lua
function x_player_api.get_left_wield_entity(player: ObjectRef)
  -> entity: ObjectRef|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `entity` (`ObjectRef|nil`)

#### `x_player_api.get_left_wield_first_person`

Get whether 3D left-hand wield item is visible in 1st person view for a player

```lua
function x_player_api.get_left_wield_first_person(player: ObjectRef)
  -> visible: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `visible` (`boolean`)

#### `x_player_api.get_left_wield_item`

Returns the currently attached left-hand item name for a player.

```lua
function x_player_api.get_left_wield_item(player: string|ObjectRef)
  -> item_name: string
```

**Parameters:**

* `player` (`string|ObjectRef`): Target player or player name

**Returns:**

* `item_name` (`string`)

#### `x_player_api.get_wield_attachment_params`

Calculate visual_size, attachment position, rotation, glow, and color for a wielded item.
Automatically adjusts attachment position coordinates and Euler rotation angles for B3D models
to compensate for Blitz3D exporter axis inversions and align tool handles squarely in the palm.

```lua
function x_player_api.get_wield_attachment_params(item_or_stack: string|ItemStack, format_override?: string)
  -> visual_size: Vector3
  2. position: Vector3
  3. rotation: Vector3
  4. glow: number
  5. item_color: string|nil
```

**Parameters:**

* `item_or_stack` (`string|ItemStack`): ItemStack object or item name string
* `format_override` (`string?`): Optional model format override ("glb" or "b3d")

**Returns:**

* `visual_size` (`Vector3`): Normalised 3D scale vector
* `position` (`Vector3`): Local attachment position offset
* `rotation` (`Vector3`): Local Euler rotation angles
* `glow` (`number`): Entity glow brightness level (0-14)
* `item_color` (`string|nil`): Extracted color string if specified

#### `x_player_api.get_wield_entity`

Get the active wield item entity ObjectRef for a player

```lua
function x_player_api.get_wield_entity(player: ObjectRef)
  -> entity: ObjectRef|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `entity` (`ObjectRef|nil`): Active wield item entity or nil

#### `x_player_api.get_wield_item_visibility`

Get visibility preference of the wield item entity for a player

```lua
function x_player_api.get_wield_item_visibility(player: ObjectRef)
  -> visible: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `visible` (`boolean`): Whether wield item entity is configured to be visible

#### `x_player_api.register_on_wield_change`

Register a callback invoked whenever a player switches their held wield item or hotbar slot

```lua
function x_player_api.register_on_wield_change(callback: fun(player: ObjectRef, item: string, prev: string, stack: ItemStack, idx: int, p_idx: int))
```

**Parameters:**

* `callback` (`fun(player: ObjectRef, item: string, prev: string, stack: ItemStack, idx: int, p_idx: int)`)

#### `x_player_api.register_wield_item_offset`

Register a custom wield offset, rotation, or scale adjustment

```lua
function x_player_api.register_wield_item_offset(identifier: string, def: WieldOffsetDefinition)
```

**Parameters:**

* `identifier` (`string`): Item name ("default:sword_steel"), group ("group:sword"), or type ("type:node")
* `def` (`WieldOffsetDefinition`): Table containing pos, rot, scale, and/or glow overrides

#### `x_player_api.remove_left_wield_item`

Removes the left hand wield item entity from a player.

```lua
function x_player_api.remove_left_wield_item(player: string|ObjectRef)
```

**Parameters:**

* `player` (`string|ObjectRef`): Target player or player name

#### `x_player_api.remove_wield_item`

Remove the wield item entity for a player

```lua
function x_player_api.remove_wield_item(player: string|ObjectRef)
```

**Parameters:**

* `player` (`string|ObjectRef`): Target player or player name

#### `x_player_api.set_global_left_wield_first_person`

Set whether 3D left-hand wielded items should be visible in 1st person view globally

```lua
function x_player_api.set_global_left_wield_first_person(enabled: boolean)
```

**Parameters:**

* `enabled` (`boolean`): Whether 1st person left-hand wield items should be visible

#### `x_player_api.set_left_wield_first_person`

Set whether 3D left-hand wield item should be visible in 1st person view for a specific player

```lua
function x_player_api.set_left_wield_first_person(player: ObjectRef, visible: boolean|nil)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `visible` (`boolean|nil`): Visibility in first person (nil resets to global default)

#### `x_player_api.set_wield_item_enabled`

Set whether 3D wielded item rendering is enabled

```lua
function x_player_api.set_wield_item_enabled(enabled: boolean)
```

**Parameters:**

* `enabled` (`boolean`): Whether 3D wield items should be active

#### `x_player_api.set_wield_item_visibility`

Set visibility of the wield item entity for a player

```lua
function x_player_api.set_wield_item_visibility(player: ObjectRef, visible: boolean)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `visible` (`boolean`): Whether held item should be rendered

#### `x_player_api.step_player_wield`

Step wield item for an individual player (called during unified globalstep)

```lua
function x_player_api.step_player_wield(player: ObjectRef, is_throttled_tick: boolean)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `is_throttled_tick` (`boolean`): Whether periodic throttle interval has elapsed

#### `x_player_api.update_left_wield_attachment_visibility`

Updates forced_visible attachment state on left-hand wield entities

```lua
function x_player_api.update_left_wield_attachment_visibility(player: ObjectRef)
```

**Parameters:**

* `player` (`ObjectRef`): Target player

#### `x_player_api.update_left_wield_item`

Updates or modifies the left-hand wield item on a player.

```lua
function x_player_api.update_left_wield_item(player: ObjectRef, item_or_stack?: string|ItemStack, options?: table)
  -> entity: ObjectRef|nil
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `item_or_stack` (`(string|ItemStack)?`): Held item name or ItemStack
* `options` (`table?`): Optional params: first_person, pos, rot, scale, glow

**Returns:**

* `entity` (`ObjectRef|nil`): Attached entity reference or nil

#### `x_player_api.update_wield_item`

Update held wield item on the child entity (throttled delta check)

```lua
function x_player_api.update_wield_item(player: ObjectRef, force?: boolean, wield_stack?: ItemStack)
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `force` (`boolean?`): Force entity property updates even if held item unchanged
* `wield_stack` (`ItemStack?`): Optional cached wield ItemStack to avoid redundant get_wielded_item call

---

## Miscellaneous Functions

#### `x_player_api.collisionbox_equals`

```lua
function
```

#### `x_player_api.detect_environment`

Perform unified environmental spatial probing for water, ladder, ground, and air

```lua
function x_player_api.detect_environment(pos: Vector3, vel: Vector3, pstate?: PlayerControlState)
  -> in_water: boolean
  2. on_ladder: boolean
  3. is_on_ground: boolean
  4. in_air: boolean
```

**Parameters:**

* `pos` (`Vector3`): Player world position
* `vel` (`Vector3`): Player velocity vector
* `pstate` (`PlayerControlState?`): Player internal control state

**Returns:**

* `in_water` (`boolean`): Whether player is in water
* `on_ladder` (`boolean`): Whether player is on ladder or vine
* `is_on_ground` (`boolean`): Whether player is supported by ground
* `in_air` (`boolean`): Whether player is airborne

#### `x_player_api.evaluate_can_block`

Evaluate whether player is capable of blocking (via held item, offhand shield, or registered predicates)

```lua
function x_player_api.evaluate_can_block(player: ObjectRef, wield_name?: string, item_info?: ItemClassification, pstate?: table, time_now?: number)
  -> can_block: boolean
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `wield_name` (`string?`): Held item name (optional, defaults to player's wielded item)
* `item_info` (`ItemClassification?`): Classification of held item (optional, auto-classified if omitted)
* `pstate` (`table?`): Optional internal player state for caching and fast controls
* `time_now` (`number?`): Optional timestamp for per-tick cache deduplication

**Returns:**

* `can_block` (`boolean`)

#### `x_player_api.get_mouth_position`

Calculate mouth 3D position projected forward along player gaze

```lua
function x_player_api.get_mouth_position(player: ObjectRef)
  -> center: Vector3|nil
  2. dir_x: number
  3. dir_z: number
```

**Parameters:**

* `player` (`ObjectRef`): Target player

**Returns:**

* `center` (`Vector3|nil`): Mouth center coordinates
* `dir_x` (`number`): Normalized look direction X
* `dir_z` (`number`): Normalized look direction Z

#### `x_player_api.get_player_data`

```lua
function
```

#### `x_player_api.is_ground_near`

Check if solid ground is within a vertical distance below player with center-first short-circuiting

```lua
function x_player_api.is_ground_near(pos: Vector3|nil, dist: number, pstate?: PlayerControlState)
  -> ground_near: boolean
```

**Parameters:**

* `pos` (`Vector3|nil`): Player world position
* `dist` (`number`): Probe distance downward in nodes
* `pstate` (`PlayerControlState?`): Per-player control state for maintaining ground continuity in unloaded chunks

**Returns:**

* `ground_near` (`boolean`): True if solid walkable node is found within distance

#### `x_player_api.is_player_in_liquid`

Check if player is in liquid (head or waist) with vertical probe short-circuiting

```lua
function x_player_api.is_player_in_liquid(pos: Vector3|nil)
  -> in_liquid: boolean
```

**Parameters:**

* `pos` (`Vector3|nil`): Player world position

**Returns:**

* `in_liquid` (`boolean`): True if player intersects a liquid node

#### `x_player_api.is_player_on_ladder`

Check if player is on ladder or climbable node with vertical probe short-circuiting

```lua
function x_player_api.is_player_on_ladder(pos: Vector3|nil)
  -> on_ladder: boolean
```

**Parameters:**

* `pos` (`Vector3|nil`): Player world position

**Returns:**

* `on_ladder` (`boolean`): True if player intersects a climbable node

#### `x_player_api.is_pure_native_b3d_active`

Check whether pure native B3D mode is currently active for a player/session

```lua
function x_player_api.is_pure_native_b3d_active(player?: ObjectRef, target_model_name?: string)
  -> is_active: boolean
```

**Parameters:**

* `player` (`ObjectRef?`): Target player (optional)
* `target_model_name` (`string?`): Optional specific model name being resolved

**Returns:**

* `is_active` (`boolean`)

#### `x_player_api.register_blocking_predicate`

Register a predicate function to determine whether a player is capable of blocking

```lua
function x_player_api.register_blocking_predicate(predicate: fun(player: ObjectRef, wield_name: string, item_info: ItemClassification):boolean)
```

**Parameters:**

* `predicate` (`fun(player: ObjectRef, wield_name: string, item_info: ItemClassification):boolean`)

#### `x_player_api.register_on_hold`

Register a callback invoked continuously each tick while a control key is held

```lua
function x_player_api.register_on_hold(callback: fun(player: ObjectRef, key: string, duration: number))
```

**Parameters:**

* `callback` (`fun(player: ObjectRef, key: string, duration: number)`)

#### `x_player_api.register_on_press`

Register a callback invoked immediately when a control key transition to pressed

```lua
function x_player_api.register_on_press(callback: fun(player: ObjectRef, key: string))
```

**Parameters:**

* `callback` (`fun(player: ObjectRef, key: string)`)

#### `x_player_api.register_on_release`

Register a callback invoked immediately when a control key transitions to released

```lua
function x_player_api.register_on_release(callback: fun(player: ObjectRef, key: string, duration: number))
```

**Parameters:**

* `callback` (`fun(player: ObjectRef, key: string, duration: number)`)

#### `x_player_api.set_aux1_sprint_enabled`

Set whether holding the AUX1 key triggers sprint locomotion

```lua
function x_player_api.set_aux1_sprint_enabled(enabled: boolean)
```

**Parameters:**

* `enabled` (`boolean`)

#### `x_player_api.set_double_tap_sprint_enabled`

Set whether double-tapping the forward movement key triggers sprint locomotion

```lua
function x_player_api.set_double_tap_sprint_enabled(enabled: boolean)
```

**Parameters:**

* `enabled` (`boolean`)

#### `x_player_api.set_pure_native_b3d`

Set pure native B3D mode

```lua
function x_player_api.set_pure_native_b3d(enable: boolean)
```

**Parameters:**

* `enable` (`boolean`): Whether to enable pure native B3D mode

#### `x_player_api.start_anim_test`

Start an animation showcase or single animation test for player

```lua
function x_player_api.start_anim_test(player: ObjectRef, duration?: number, specific_anim?: string)
  -> success: boolean
  2. error_message: string?
```

**Parameters:**

* `player` (`ObjectRef`): Target player
* `duration` (`number?`): Duration per animation in seconds (default: 4.0)
* `specific_anim` (`string?`): Optional specific animation identifier to test

**Returns:**

* `success` (`boolean`): Whether test was started
* `error_message` (`string?`): Error message on failure

#### `x_player_api.stop_anim_test`

Stop any active animation test showcase and restore player animations

```lua
function x_player_api.stop_anim_test(name: string, quiet?: boolean)
```

**Parameters:**

* `name` (`string`): Player name
* `quiet` (`boolean?`): Suppress user chat notification

#### `x_player_api.wiggle_b3d_data`

Process raw B3D binary data and wiggle all perfect NODE and KEYS rotation quaternions

```lua
function x_player_api.wiggle_b3d_data(data: string)
  -> patched_data: string
  2. nodes_wiggled: integer
  3. keys_wiggled: integer
```

**Parameters:**

* `data` (`string`): Binary B3D file contents

**Returns:**

* `patched_data` (`string`)
* `nodes_wiggled` (`integer`)
* `keys_wiggled` (`integer`)

#### `x_player_api.wrap_player_metatable`

Wrap Player metatable to enforce hidden native player properties while visual proxies are active,
and forward bone overrides to visual proxy entities.

```lua
function x_player_api.wrap_player_metatable(player: ObjectRef)
```

**Parameters:**

* `player` (`ObjectRef`): Target player

---

## Registries & State Tables

| Registry / Table | Type | Description |
| :--- | :--- | :--- |
| `x_player_api.BASE_LEFT_BONE` | `string` |  |
| `x_player_api.BASE_LEFT_POS_B3D` | `table` |  |
| `x_player_api.BASE_LEFT_POS_GLB` | `table` |  |
| `x_player_api.BASE_LEFT_ROT_B3D` | `table` |  |
| `x_player_api.BASE_LEFT_ROT_GLB` | `table` |  |
| `x_player_api.BASE_POS` | `table` |  |
| `x_player_api.BASE_POS_B3D` | `table` |  |
| `x_player_api.BASE_POS_GLB` | `table` |  |
| `x_player_api.BASE_ROT` | `table` |  |
| `x_player_api.BASE_ROT_B3D` | `table` |  |
| `x_player_api.BASE_ROT_GLB` | `table` |  |
| `x_player_api.PROXY_LIGHTING_BOX` | `number[]` | Safe lighting collisionbox for visual proxies to sample ambient light within the player's core volume. Prevents clipping into solid nodes or subterranean floors in GenericCAO::getLightPosition. |
| `x_player_api.WIELD_UPDATE_INTERVAL` | `number` |  |
| `x_player_api.active_proxies` | `table` | Active visual proxy entity instances by player name |
| `x_player_api.animation_aliases` | `table<string, string>` | Semantic animation alias dictionary |
| `x_player_api.blocking_predicates` | `(fun(player: ObjectRef, wield_name: string, item_info: ItemClassification):boolean)[]` |  |
| `x_player_api.bone_caches` | `table` | Cached bone transformations for network throttling and dual-format routing |
| `x_player_api.connected_players` | `ObjectRef[]` | Locally maintained array of connected players for zero-allocation tick iteration |
| `x_player_api.controls` | `PlayerControlsSubsystem` |  |
| `x_player_api.enable_aux1_sprint` | `unknown` | Whether holding the AUX1 (Special) key to sprint is enabled |
| `x_player_api.enable_double_tap_sprint` | `unknown` | Whether double-tapping the forward key to sprint is enabled |
| `x_player_api.enable_eating` | `unknown` | Whether eating animations, sounds, and particle simulations are enabled |
| `x_player_api.enable_equip_sound` | `unknown` | Whether declarative item equip sound effects are enabled |
| `x_player_api.enable_left_wield_first_person` | `unknown` | Whether 3D wielded item in the left hand is visible in 1st person view by default |
| `x_player_api.enable_wield_item` | `unknown` | Whether 3D wielded item rendering attached to the player hand is enabled |
| `x_player_api.head_tracking` | `HeadTrackingSubsystem` |  |
| `x_player_api.left_wield_entities` | `table<string, LeftWieldEntityData>` |  |
| `x_player_api.legacy_cohort` | `table` | Map of player names with legacy client protocol |
| `x_player_api.model_format` | `string\|"b3d"\|"glb"` |  |
| `x_player_api.model_redirects` | `table<string, string\|fun(player: ObjectRef\|nil, model: string):string\|nil>` | Model redirection rules |
| `x_player_api.modern_cohort` | `table` | Map of player names with Luanti 5.17.0+ modern client protocol |
| `x_player_api.player_attached` | `table<string, boolean>` | Map of player attachment states |
| `x_player_api.pure_native_b3d` | `unknown` | Whether pure native B3D rendering is enabled (bypassing visual proxies in B3D mode) |
| `x_player_api.registered_consumables` | `table<string, ConsumableDefinition>` |  |
| `x_player_api.registered_emotes` | `table<string, EmoteDefinition>` |  |
| `x_player_api.registered_equip_sounds` | `table<string, boolean\|string\|EquipSoundDefinition>` |  |
| `x_player_api.registered_item_actions` | `table` |  |
| `x_player_api.registered_models` | `table<string, ModelDefinition>` | Registry of model definitions by name |
| `x_player_api.registered_particle_generators` | `table<string, fun(player: ObjectRef, item_name?: string, duration?: number):integer?>` |  |
| `x_player_api.registered_weapon_categories` | `table<string, string>` |  |
| `x_player_api.wield_entities` | `table<string, WieldItemEntityData>` |  |
| `x_player_api.wield_item_offsets` | `WieldOffsetsRegistry` |  Offset and rotation customization registry |
| `x_player_api.wield_texture_transforms` | `table` | Wielded item texture transformation registry Maps item names or group identifiers ("group:screwdriver") to texture transform modifier strings (e.g. "R90") Provides an agnostic mechanism for aligning items whose 2D artwork is drawn with non-standard rotations |
