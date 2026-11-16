# X Player API [x_player_api]

[![ContentDB](https://content.luanti.org/packages/SaKeL/x_player_api/shields/title/)](https://content.luanti.org/packages/SaKeL/x_player_api/)
[![ContentDB Downloads](https://content.luanti.org/packages/SaKeL/x_player_api/shields/downloads/)](https://content.luanti.org/packages/SaKeL/x_player_api/)
![Luanti](https://img.shields.io/badge/Luanti-5.10%2B-5599ff.svg)
[![Luacheck](https://img.shields.io/github/actions/workflow/status/sakel-hub/x_player_api/luacheck.yml?label=Luacheck&logo=lua)](https://github.com/sakel-hub/x_player_api/actions)
[![License: LGPL 2.1](https://img.shields.io/badge/License-LGPL_v2.1-blue.svg)](license.txt)
[![Media License: CC-BY 4.0](https://img.shields.io/badge/Media-CC_BY_4.0-lightgrey.svg)](license.txt)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/sakel-hub/x_player_api/pulls)
![AI-Assisted](https://img.shields.io/badge/AI--assisted-gray)

Provides a high-performance, next-generation Player API for Luanti, featuring full support for **glTF multi-track animations** (Luanti 5.17+), dual-model visual proxies with observer network filtering (`observers.lua`, `proxies.lua`), bone override throttling (`bone_overrides.lua`), smooth head bone look tracking (`head_tracking.lua`), realistic biomechanical locomotion, kinematic action layers, eating animation and crumb simulation (`eating.lua`), and 3D wield items (`wield.lua`).

![x_player_api Rig Animation Showcase](screenshot.png)

Seamlessly serves modern `.glb` models to Luanti 5.17.0+ clients while providing zero-overhead fallback to legacy `.b3d` models for older clients on the same multiplayer server, maintaining 100% backward compatibility for canonical 6-bone skins and single-track models.

> [!IMPORTANT]
> **Pure API Integration — Decoupled 3rd-Party Mod Architecture**  
> `x_player_api` is strictly a **pure API integration**. It does not support, bundle, or directly integrate any 3rd-party mods.  
> 
> Third-party mods (such as armor, skins, cosmetics, shields, or wield items) can use this API to integrate seamlessly with the new player model. For practical integration examples and a showcase reference implementation of 3rd-party mod integration, see the companion [**`x_player_bridge`**](https://github.com/sakel-hub/x_player_bridge) mod.

---

## Cutting-Edge Design & Supported Versions

`x_player_api` is engineered as a **cutting-edge** player animation engine for Luanti. It pushes the boundaries of the engine with glTF 2.0 multi-track animation priority layers, zero-bandwidth observer culling, and synchronized visual proxies.

### Recommended Version Matrix

| Component | Minimum Version | Recommended Version | Experience & Capabilities |
| :--- | :---: | :---: | :--- |
| **Server** | **Luanti 5.10.0+** | **Luanti 5.17.0+** | Network observer culling (`set_observers`), dual visual proxy routing, zero-overhead lifecycle cleanup, high-precision timer. |
| **Client** | **Luanti 5.10.0** | **Luanti 5.17.0+** | **Optimal Experience:** Multi-track glTF animations, bone-masked locomotion & action blending, synchronized 3rd-person attachment interpolation, zero input latency. |

### Limitations of Older Clients (Luanti 5.10.x – 5.11.x)

While `x_player_api` provides automatic backward compatibility so older clients do not crash and can join multiplayer worlds alongside modern clients, **older client engines have intrinsic engine limitations**:

1. **Attachment Camera Jitter in 3rd Person (F5)**:
   - In older clients (e.g. Luanti 5.10), child entities attached to the local player (`ClientActiveObject` via `set_attach`) do not interpolate smoothly with the local camera. The local player and camera update at client display refresh rates (60–144 Hz), while older clients update attached child transforms only on server packet ticks, producing noticeable camera-relative micro-vibration.
   - **Luanti 5.17+** completely eliminates this through modernized, camera-synchronized attachment interpolation.
2. **Client-Side Animation Prediction Contention**:
   - Luanti 5.10 has hardcoded client-side animation prediction in C++ (`LocalPlayer`). Because `x_player_api` suppresses client prediction (`set_local_animation(0)`) to drive custom action layers from the server without desync, older clients continuously fight against server packets during held inputs (like mining or walking), causing perceived "lost frames" or micro-resets.
   - **Luanti 5.17+** cleanly decouples server-driven animation layers and respects local override flags.
3. **Single-Track Fallback**:
   - Older clients cannot render `.glb` multi-track models and are automatically served the single-timeline `.b3d` fallback. While keyframe boundaries in `character.b3d` are mathematically calibrated to seamless loop points, older Irrlicht animation tickers lack the modern quaternion SLERP and high-precision delta-time interpolation introduced in Luanti 5.12–5.17.

> [!TIP]
> **Recommendation**: For server operators and players who want the intended fluid visual experience, running **Luanti 5.17.0 or newer** on both client and server is strongly recommended.

---

## Architecture: Dual-Model Visual Proxies & Observer Cohorts

In multiplayer environments, servers frequently host a mix of modern Luanti 5.17.0+ clients (which support glTF 2.0 multi-track skeletal animation layers) and older clients (which only support single-timeline `.b3d` models). Attempting to send a glTF mesh to an older client causes missing models or engine errors, while forcing modern clients onto `.b3d` disables simultaneous multi-track blending.

`x_player_api` solves this through a **dual-proxy entity architecture with engine observer culling**:

```
                               ┌─────────────────────────────┐
                               │       Player SAO Root       │
                               │  (visual_size = {x=0, y=0}) │
                               │   Hitbox / Physics Intact   │
                               └──────────────┬──────────────┘
                                              │ set_attach
                     ┌────────────────────────┴────────────────────────┐
                     ▼                                                 ▼
      ┌─────────────────────────────┐                   ┌─────────────────────────────┐
      │  x_player_api:visual_glb    │                   │   x_player_api:visual_b3d   │
      │   Modern glTF Multi-Track   │                   │    Legacy B3D Single-Track  │
      └──────────────┬──────────────┘                   └──────────────┬──────────────┘
                     │ set_observers                                   │ set_observers
                     ▼                                                 ▼
      ┌─────────────────────────────┐                   ┌─────────────────────────────┐
      │     modern_cohort Users     │                   │     legacy_cohort Users     │
      │    (Protocol >= 5.17.0)     │                   │      (Protocol < 5.17.0)    │
      └─────────────────────────────┘                   └─────────────────────────────┘
```

### How the Dual-Proxy Architecture Operates

1. **Native Player Visual Decoupling**: Upon player join, the native player object's visual properties are minimized (`visual_size = {x=0, y=0}`, `textures = {"blank.png"}`). The player's physics, raycasts, hitboxes, collision boxes, and camera positions remain untouched.
2. **Dual Visual Proxy Entities**: Two non-physical child entities are spawned at the player's position and attached to the player root (`{x=0, y=0, z=0}`):
   - `x_player_api:visual_glb`: Hosts `character.glb` with multi-track animation support.
   - `x_player_api:visual_b3d`: Hosts `character.b3d` with single-timeline animation support.
3. **Protocol Cohort Classification (`observers.lua`)**: When a player joins, their network protocol version is queried via `core.get_player_information(name).protocol_version`. If $\ge$ `core.protocol_versions["5.17.0"]`, the username is added to `x_player_api.modern_cohort`; otherwise, to `x_player_api.legacy_cohort`.
4. **Zero-Bandwidth Engine Observer Filtering (`set_observers`)**: Luanti engine's `ObjectRef:set_observers` filters entity packet transmission directly at the network serialization layer:
   - Modern clients only receive entity updates and animation packets for `visual_glb`.
   - Legacy clients only receive entity updates and animation packets for `visual_b3d`.
   - Neither client receives duplicate packets or unsupported mesh formats.
5. **Dual Dispatching (`api.lua`)**: All high-level API methods (`set_model`, `set_animation`, `set_textures`) simultaneously dispatch to both proxies:
   - **Modern clients** receive independent priority-blended glTF tracks (locomotion on priority 0, actions on priority 1).
   - **Legacy clients** receive dynamically computed single-timeline frame ranges (`walk`, `walk_mine`, `walk_eat`, `walk_bow_aim`, etc.).
6. **Bone Override Throttling (`bone_overrides.lua`)**: Head gaze and look-pitch orientation overrides are passed through an angular threshold filter:
   - If the rotational delta across pitch, yaw, and roll is less than $0.08$ radians ($\approx 4.5^\circ$), packet transmission is skipped.
   - Saves substantial server network bandwidth during rapid client mouse look without any perceptible loss of visual fidelity.
7. **Natural Head & Dual-Arm Look Tracking (`head_tracking.lua`)**: Naturally and smoothly rotates the character's `Head` and arm bones (`Arm_Right`, `Arm_Left`) to match player camera gaze (pitch, yaw, and lateral neck roll):
   - **Continuous Exponential Smoothing & Client Interpolation**: Continuous exponential decay damping ($\lambda = 14.0\text{ s}^{-1}$) coupled with Luanti hardware interpolation (`0.1`s in `set_bone_override`) eliminates stepping and delivers fluid 60–144 Hz motion.
   - **Horizontal Gaze Leading & Body Turn Lag**: When free-standing, the head anticipates horizontal camera rotations up to $\pm 35^\circ$ with subtle lateral neck roll ($-Y \times 0.08$) while the torso smoothly catches up over $\approx 0.2$s. When attached to vehicles or seats, full horizontal gaze tracking operates within $\pm 75^\circ$.
   - **Biomechanical Pitch Clamping & Prone Posture Compensation**: Anatomically clamped pitch ($-75^\circ$ zenith to $+70^\circ$ nadir) for upright postures. During horizontal locomotion (`fly` and `swim`), automatically offsets baseline head pitch by $-75^\circ$ with scaled gaze tracking ($0.75\times$) so the character naturally gazes forward along their flight or swim path rather than facing downward.
   - **Bind Pose Preservation**: Omits bone position overrides when nil, ensuring bones remain anchored to their model rest height without collapsing into the torso.
   - **Dual-Arm Synchronized Pitch**: Naturally tilts both arms (-X elevation when looking up, +X depression when looking down) using relative bone overrides (`absolute = false`), allowing keyframed animations (walk, swing, pull) to compose seamlessly with look pitch:
     - *Bow Aiming (`aiming_bow`, `bow_aim`)*: Full dual-arm pitch synchronization with kinematic compensation on `Arm_Left` ($Y$ and $Z$ axes), ensuring both hands remain firmly on the bow grip across all vertical pitch angles rather than dropping to the flank.
     - *Mining & Melee (`mine`, `attack_slash`, `attack_thrust`)*: Dominant right arm receives 85% action weight while the left arm maintains subtle posture stability (17.5%).
     - *Shield Blocking (`block`)*: Left arm raises/pitches at 85% action weight while right arm provides subtle stability.
     - *Idle & Locomotion*: Subtle 35% natural pitch response giving lifelike upper-body presence.
   - **Posture Awareness**: Smoothly suppresses tracking during prone postures (e.g. `lay` in bed or `freeze`) and balances weight during damage flinch (`hurt`).
   - **Idle Quiescence (Sleep State)**: Zero socket packets are transmitted across the server network when gaze is stationary.

---

## Architecture: Multi-Track Animations

`x_player_api` leverages Luanti's glTF multi-track animation capabilities to decouple whole-body locomotion from upper-body interactions using bone-masked priority layers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Action Layer (Priority 1)                       │
│    Bones: Arm_Right, Arm_Left, Head (Zero influence on Pelvis/Legs)    │
│    Tracks: mine, attack_slash, attack_thrust, block, eat, bow, emotes  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Blended simultaneously
┌───────────────────────────────────▼────────────────────────────────────┐
│                      Locomotion Layer (Priority 0)                     │
│    Bones: Pelvis, Spine, Torso, Hips, Thighs, Calves, Feet             │
│    Tracks: stand, walk, sprint, crouch, crouch_walk, slide, jump, etc. │
└────────────────────────────────────────────────────────────────────────┘
```

### Why Bone Masking Matters
In traditional single-track models (`.b3d`), actions performed while walking (such as digging, eating, or holding a drawn bow) require separately baked hybrid animations (`walk_mine`, `walk_eat`, `walk_bow_aim`). If you sprint while digging, the engine either cancels sprinting or slides the feet unnaturally.

With glTF multi-track:
- **Zero Foot-Sliding**: Locomotion tracks drive the pelvis and legs according to actual physics and velocity.
- **Simultaneous Action**: Action tracks animate the arms and head without overwriting leg keyframes.
- **Natural Gaze & Breathing**: Idle breathing and walking gait sway continue uninterrupted while swinging tools or raising shields.

---

## Controls & Animation States

### Locomotion Layer

| State | Controls / Trigger | Collisionbox (x1, y1, z1, x2, y2, z2) | Eye Height | Description |
| :--- | :--- | :--- | :--- | :--- |
| **`stand`** | Stationary on solid ground | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Grounded idle stance with contrapposto weight balance and thoracic breathing. |
| **`walk`** | Move keys (`W`, `A`, `S`, `D`) or Auto-forward (`F` key) | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Athletic 4-phase walking gait with pelvic twist and gaze stabilization. Seamlessly triggered by the `F` auto-forward key, analog sticks, or velocity. |
| **`sprint`** | Hold `aux1` (`E`) or double-tap `W` while moving forward | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | High-knee forward sprint stride with dynamic forward torso lean. |
| **`crouch`** | Hold `sneak` (`Shift`) while stationary | `{-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}` | 1.25 m | Low stealth crouch with bent knees; lowered hitbox and eye height. |
| **`crouch_walk`** | Hold `sneak` (`Shift`) + move | `{-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}` | 1.25 m | Cautious stealth stride; lets you sneak through 1.5m high spaces. |
| **`slide`** | Tap `sneak` (`Shift`) while sprinting | `{-0.3, 0.0, -0.3, 0.3, 1.1, 0.3}` | 0.90 m | Knee ground-slide with forward impulse; reduced hitbox height (1.1m) lets you slide under low overhangs, tree limbs, and obstacles. |
| **`jump`** | Airborne ascending (`velocity.y > 0.5`) or takeoff impulse | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Dynamic leap with mid-air knee tuck and apex stretch. Automatically plays during upward motion in jumps or flight ascent. |
| **`fall`** | Airborne descending (`velocity.y < -0.5`) | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Aerodynamic downward fall with arms stabilized outward. Plays during downward jump descents, cliff drops, and flight descent. |
| **`swim`** | Submerged in water / liquid | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Horizontal breaststroke swimming cycle with scissor leg kicks. |
| **`climb`** | On ladder or vines | `{-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}` | 1.47 m | Hand-over-hand ladder climbing while ascending (`Space`/`W`) or descending (`Shift`/`S`). When stationary on a ladder, automatically holds rungs with animation speed paused at 0. |
| **`fly`** | Airborne high-speed movement ($\ge 6.5$ m/s or 3D flight sprint) | `{-0.3, 0.0, -0.3, 0.3, 1.2, 0.3}` | 1.25 m | Dynamic superhero horizontal flight glide with streamlined arms, head looking ahead, and trailing legs. Seamlessly engages at high directional speed or during airborne sprint. |
| **`hover`** | Airborne stationary or low-velocity float ($|\text{velocity}.y| \le 0.5$ m/s) | `{-0.3, 0.0, -0.3, 0.3, 1.6, 0.3}` | 1.35 m | Gentle levitating hover with upright posture, rhythmic vertical buoyancy, stabilizing arms, and relaxed dangling legs. Automatically engages when stopped or drifting vertically in the air without glitching to stand. |
| **`sit`** | Chat command `/sit` or sitting node | `{-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}` | 0.80 m | Relaxed seated posture with legs locked flat on the ground and subtle upper body breathing; automatically cancels when moving. |
| **`lay`** | Chat command `/lay` or zero HP (death) | `{-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}` | 0.30 m | Flat resting posture on back facing skyward, flush to the ground with gentle 80-frame sleeping breathing cycle; automatically cancels when moving. |

### Action & Interaction Layer (Simultaneous with Any Locomotion)

| State | Controls / Trigger | Description |
| :--- | :--- | :--- |
| **`mine`** | Click / hold `LMB` (`dig`) with tools or bare hands | Kinetic downward tool swing with anticipation wind-up and elastic recoil snap. |
| **`attack_slash`** | Click / hold `LMB` while wielding a sword, blade, or saber | Clean high-to-low diagonal sword cleave across the torso with 0 awkward arm roll. |
| **`attack_thrust`** | Click / hold `LMB` while wielding a spear, pike, or javelin | Explosive forward thrust/jab. |
| **`block`** | Hold `RMB` / `place` while holding a shield or guard item | Raises shield into active defensive guard stance. |
| **`eat`** | Click `LMB` (`dig` / `on_use`) while holding food | Brings consumable directly to the mouth with rhythmic chewing motion. |
| **`bow_aim`** | Hold `RMB` / `place` to charge bow, or wield a charged bow (`x_bows`) | Both arms angled inward in front of the chest with hands held closely together along the centerline. |
| **`bow_shoot`** | Release drawn string or click `LMB` with charged bow | Dynamic string release snap and right arm recoil follow-through. |
| **`hurt`** | Damaged / HP decrease (`on_player_hpchange`), or `player_api.trigger_hurt` | Defensive impact flinch snapping the head back and drawing arms inward protectively (~0.33s). |
| **`equip`** | Switch wielded weapon/item in hotbar, or `player_api.trigger_equip` | Unreal Engine Mannequin-style quick equip montage: rapid dip towards hip/belt holster followed by a crisp draw and raise with an elastic overshoot (~0.33s). Auto-cancels with zero latency if attacking or mining. |

### Social Gestures & Emotes

| Command | Gesture | Description |
| :--- | :--- | :--- |
| `/wave` | **Wave** | Raises right arm high above the right shoulder clear of the face, waving left and right. |
| `/point` | **Point** | Extends right arm forward, pointing in target direction. |
| `/cheer` | **Cheer** | Pumps both arms overhead in a wide celebratory V-shape with hands held wide from the head. |
| `/bow` | **Bow** | Single graceful courtly bow: right hand over heart/chest, left arm swept back, bowing respectfully with a smooth hold and recovery. The glTF model locks pelvis root translation to `(0, 0, 0)` and counter-rotates leg bones so both feet remain firmly anchored to the ground without sliding or hovering. Cancels automatically on movement. |
| `/sit` | **Sit** | Sits down on the spot; move in any direction to stand back up. |
| `/lay` | **Lay** | Lies down flat on the spot facing skyward; move in any direction to stand back up. |
| `/hurt` | **Hurt** | Triggers the hurt flinch animation immediately (for testing & inspection). |

### Animation Testing & Debug Showcase (Admin Command)

| Command | Privs | Description |
| :--- | :--- | :--- |
| `/test_anim` | `server` | Runs a continuous slideshow showcasing all 28 registered animations for 4.0s each. Each animation is announced in private chat with track and looping details. |
| `/test_anim <seconds>` | `server` | Runs the full slideshow with custom duration per animation (e.g. `/test_anim 2` or `/test_anim 5`). |
| `/test_anim <anim_name> [sec]` | `server` | Previews a single specific animation on your character (e.g. `/test_anim hurt 3` or `/test_anim bow_aim 6`). |
| `/test_anim stop` | `server` | Instantly cancels any active animation slideshow or single-anim preview, restoring normal gameplay animations. |
| `/test_anim list` | `server` | Prints a sorted list of all available animations registered on the current player model. |

> [!TIP]
> While `/test_anim` is active, you can switch camera views (`F7`) or rotate around your character to inspect bone orientations, limb movements, and ground alignment from any angle. When moving, gestures and actions seamlessly play on the upper body while your legs continue walking or running!

---

## Developer Guide & Key Examples

> [!NOTE]
> For the complete, exhaustive API reference including all class definitions, type aliases, method signatures, parameter tables, and return types, please consult **[`API.md`](API.md)**.

`x_player_api` is designed around decoupled modules, zero external game dependencies, and extensible registries. Below are practical examples showcasing the most important and commonly used methods for extending player animations, weapons, consumables, and reactive events.

---

### Custom Animations & Model Tweaks

External mods can register custom animation tracks on character models or adjust playback parameters on existing tracks.

```lua
-- Register a custom action track on character.glb (glTF multi-track)
player_api.register_model_animation("character.glb", "cast_spell", {
    track = "cast_spell",
    fps = 30,
    loop = false,
    blend = 0.15,
})

-- Register single-track frame boundaries on classic character.b3d
player_api.register_model_animation("character.b3d", "cast_spell", {
    x = 240,
    y = 265,
    fps = 30,
    loop = false,
    blend = 0.15,
})

-- Fine-tune playback speed on an existing animation track
player_api.edit_model_animation("character.glb", "walk", {
    fps = 36,
})
```

*See [Core & Model API in API.md](API.md#core--model-api) for all model methods and [AnimationDefinition](API.md#animationdefinition).*

---

### Visual Proxies & Observer Cohort API

`x_player_api` provides dedicated methods to inspect client cohorts, retrieve active visual proxy entities, and apply throttled bone transforms:

```lua
-- Check if a player connected with a modern client (protocol >= 5.17.0)
local is_modern = x_player_api.is_modern_client("PlayerName")

-- Inspect current observer cohorts
local modern_set = x_player_api.get_modern_observers() -- table<string, boolean>
local legacy_set = x_player_api.get_legacy_observers() -- table<string, boolean>

-- Retrieve the visual proxy entities for a player
local proxies = x_player_api.get_visual_proxies(player)
if proxies then
    local glb_entity = proxies.glb -- ObjectRef (x_player_api:visual_glb)
    local b3d_entity = proxies.b3d -- ObjectRef (x_player_api:visual_b3d)
end

-- Apply network-throttled bone transformation (e.g. Head gaze / pitch look)
-- Skips network packet transmission if rotation delta on "Head" is < 0.08 radians (~4.5°)
x_player_api.set_bone_override(player, "Head", {x = 0, y = 6.35, z = 0}, {x = pitch, y = 0, z = 0})

-- Force refresh observer visibility sets across all connected players
x_player_api.refresh_observers()
```

*See [Visual Proxies & Observers API in API.md](API.md#visual-proxies--observers-api) for full method specifications, [PlayerProxies](API.md#playerproxies), and [BoneOverride](API.md#boneoverride).*

---

### Bridge Mod Pattern & 3rd-Party Integration (e.g. 3d_armor)

Because `x_player_api` is a pure API that intentionally avoids bundling third-party mod logic directly, third-party mods that modify character models or attachment layers (such as `3d_armor`, `skinsdb`, or `wieldview`) can seamlessly integrate with the dual-model visual proxy architecture via a companion "bridge" mod (such as `x_player_bridge`).

#### 1. Registering a Dual-Model Definition with Base Model Inheritance

Instead of manually duplicating 70+ lines of animation frame ranges and tracks, leverage `base_model = "character.b3d"` to automatically inherit all 30 canonical animations (`animations` and `animations_glb`), hitboxes (`collisionbox`), eye height, step height, and playback speeds:

```lua
x_player_api.register_model("3d_armor_character.b3d", {
    base_model = "character.b3d",          -- Inherits all 30 B3D + GLB animations and physics
    mesh = "3d_armor_character.b3d",       -- Served to legacy clients
    mesh_glb = "3d_armor_character.glb",   -- Served to modern 5.17.0+ clients
    textures = {
        "character.png",
        "3d_armor_trans.png",
        "3d_armor_trans.png",
    },
})
```

#### 2. Intercepting Visual Updates

Hook into the mod's visual update routines to route textures and models to the dual visual proxies:

```lua
if core.get_modpath("3d_armor") then
    local old_update_player_visuals = armor.update_player_visuals
    function armor.update_player_visuals(self, player)
        -- Call original logic to generate composited armor textures
        old_update_player_visuals(self, player)

        -- Ensure model resolves to the dual-model definition
        x_player_api.set_model(player, "3d_armor_character.b3d")
    end
end
```

#### 3. Automatic Model Redirection

Mods can register transparent redirects to map legacy model requests directly to dual models:

```lua
-- Redirect any legacy 3d_armor request to the registered dual model
x_player_api.register_model_redirect("3d_armor_character.b3d", "3d_armor_character.b3d")
```

---

### Weapons & Combat Action Mapping

The item action classifier automatically routes client click and hold inputs to upper-body action tracks (`attack_slash`, `attack_thrust`, `block`, `bow_aim`, `bow_shoot`). Mods can map actions by exact item name or item group:

```lua
-- Bind an entire item group to a combat animation
player_api.register_item_action("group:halberd", "attack_slash")

-- Register advanced weapon behaviors (e.g. primary slash and secondary defensive guard)
player_api.register_item_action("my_rpg:dual_daggers", {
    action = "attack_slash",
    alt_action = "block",
})

-- Register a custom bow with aim and release actions
player_api.register_item_action("my_mod:crystal_bow", {
    is_bow = true,
    action = "bow_shoot",
})

-- Register custom weapon categories declaratively
player_api.register_weapon_category("group:polearm", "attack_thrust")

-- Register custom gestures and full-body posture emotes
player_api.register_emote("salute", {
    is_posture = false,
    duration = 1.5,
    description = "Perform a military salute",
    msg = "Saluting Commander",
})
player_api.register_emote("kneel", {
    is_posture = true, -- Handled via locomotion layer; cancels automatically on player movement
    duration = -1,     -- Continuous posture until movement
    description = "Kneel down (move to stand up)",
    msg = "Kneeling down",
})
```

*See [player_api.register_item_action](API.md#player_apiregister_item_action), [player_api.register_weapon_category](API.md#player_apiregister_weapon_category), [player_api.register_emote](API.md#player_apiregister_emote), and [ItemActionDefinition](API.md#itemactiondefinition) in API.md.*

---

### Consumables & Custom Particle Effects

The eating system (`eating.lua`) decouples eating animations, sound triggers, and visual particle feedback. Mods can register custom particle spawners and attach them to items or groups:

```lua
-- Register a custom particle generator (e.g. magical sparkles)
player_api.register_particle_generator("magic_sparkles", function(player, item_name, duration, def)
    local ppos = player:get_pos()
    ppos.y = ppos.y + 1.5
    core.add_particlespawner({
        amount = 15,
        time = duration or 0.8,
        minpos = vector.add(ppos, {x = -0.2, y = -0.1, z = -0.2}),
        maxpos = vector.add(ppos, {x = 0.2, y = 0.2, z = 0.2}),
        minvel = {x = -0.5, y = 0.5, z = -0.5},
        maxvel = {x = 0.5, y = 1.5, z = 0.5},
        texture = "magic_sparkle_particle.png",
        glow = 12,
    })
end)

-- Register potion items with liquid droplets and custom drink sounds
player_api.register_consumable("group:potion", {
    particle_type = "liquid_drops",
    sound = "potion_drink",
    duration = 1.0,
})

-- Register a magical elixir with custom sparkles
player_api.register_consumable("my_magic:elixir_of_life", {
    particle_type = "magic_sparkles",
    sound = "magic_chime",
    duration = 1.2,
})
```

#### Configuration & Runtime Toggling
Eating simulation, sounds, and particle emission can be toggled via settings (`luanti.conf` or the in-game Settings menu under **Mods -> x_player_api**):
```ini
# Enable eating animation, sounds, and crumb / droplet particle effects (default: true)
x_player_api.enable_eating = true
```
Or dynamically in Lua via `player_api.set_eating_enabled(boolean)`.

*See [Eating & Consumables API in API.md](API.md#eating--consumables-api) for generator types and [ConsumableDefinition](API.md#consumabledefinition).*

---

### Reactive State Observers (Zero-Polling)

Instead of polling player state in a server `globalstep`, external mods can register reactive callbacks to listen for locomotion and action transitions:

```lua
-- Listen reactively for state changes (e.g. sound effects, footsteps, weapon swooshes)
player_api.register_on_state_change(function(player, state, prev_loco, prev_action)
    local name = player:get_player_name()

    -- Trigger custom sounds on locomotion state transition
    if state.locomotion ~= prev_loco then
        if state.locomotion == "slide" then
            core.sound_play("player_slide_whoosh", {to_player = name, gain = 0.8})
        elseif prev_loco == "fall" and state.locomotion == "stand" then
            core.sound_play("player_land_thud", {pos = player:get_pos(), gain = 1.0})
        end
    end

    -- Trigger weapon swing whoosh on action change
    if state.action ~= prev_action and state.action == "attack_slash" then
        core.sound_play("sword_swing", {pos = player:get_pos(), gain = 0.5})
    end
end)

-- Query player state at any time
local state = player_api.get_player_state(player)
if state.sprinting and state.moving then
    -- Player is actively sprinting
end
```

*See [player_api.register_on_state_change](API.md#player_apiregister_on_state_change) and the complete [PlayerSemanticState](API.md#playersemanticstate) field specification in API.md.*

---

### Programmatic Action & Impact Triggers

Mods can trigger action animations manually to simulate environmental reactions, combat impacts, or abilities:

```lua
-- Trigger hurt impact flinch (e.g. from poison, spells, or environmental hazards)
player_api.trigger_hurt(player, 0.35)

-- Trigger bow string release snap
player_api.trigger_bow_shoot(player, 0.35)

-- Trigger eating animation and particle simulation programmatically
player_api.trigger_eat(player, 1.2, "default:apple")

-- Trigger weapon equip montage and play registered equip sound
player_api.trigger_equip(player, "default:sword_steel")

-- Directly play or stop any action track (force=true restarts if already active)
player_api.play_action(player, "hurt", true)
player_api.play_action(player, nil) -- Stops active action track
```

*See [Locomotion & Action Controls API in API.md](API.md#locomotion--action-controls-api).*

---

### Declarative Equip Sound Registry (S.O.L.I.D. OCP)

When switching items in the hotbar or calling `player_api.trigger_equip`, `x_player_api` plays high-fidelity positional draw sound effects (blades, bows, tools) with zero garbage collection overhead via an Open/Closed Principle (OCP) compliant registry:

```lua
-- Register a custom item or weapon sound override
player_api.register_equip_sound("epic_weapons:excalibur", {
    sound = "epic_holy_sword_draw",
    gain = 0.85,
    pitch = 1.0,
    max_hear_distance = 24,
})

-- Or declare directly on the item definition:
core.register_tool("magic_mod:crystal_blade", {
    description = "Crystal Blade",
    inventory_image = "crystal_blade.png",
    _equip_sound = "magic_crystal_draw", -- or {sound = "...", gain = 0.8}
    groups = {sword = 1, weapon = 1},
})

-- Suppress sound on stealth/silent items:
player_api.register_equip_sound("stealth:dagger", false)
-- or in definition: _equip_sound = false

-- Query or manually play equip audio:
local sound_def = player_api.get_equip_sound("default:sword_steel")
player_api.play_equip_sound(player, "default:sword_steel")
```

**Resolution Precedence**:
1. Exact item match in `player_api.registered_equip_sounds`
2. Item definition field `_equip_sound`
3. Group match in `player_api.registered_equip_sounds` (`group:sword`, `group:blade`, `group:saber`, `group:bow`, `group:tool`, `group:pickaxe`, `group:axe`, `group:shovel`)
4. Explicit suppression (`false` or `""`)

**Configuration**:
* `player_api.enable_equip_sound = true` (or `x_player_api.enable_equip_sound = false` in `luanti.conf`).

---

### Model Redirection & Armor / Skin Mods

Instead of monkey-patching `player_api.set_model` (which causes fragile load-order bugs), mods register clean redirection rules:

```lua
if core.get_modpath("x_player_api") then
    -- Direct alias redirection (e.g. 3d_armor or equipment meshes)
    player_api.register_model_redirect("character.glb", "3d_armor_character.glb")
    player_api.register_model_redirect("character.b3d", "3d_armor_character.b3d")

    -- Dynamic pattern redirection (matches any skin model request)
    player_api.register_model_redirect("*", function(player, model_name)
        if model_name:find("^custom_skin_") then
            return "custom_mesh.glb"
        end
    end)
end
```

*See [player_api.register_model_redirect](API.md#player_apiregister_model_redirect) in API.md.*

---

### Custom Locomotion & Action Evaluators

Mods can inject custom movement logic into the priority evaluator pipeline with zero garbage collection overhead:

```lua
-- Custom locomotion evaluator (priority 50 executes ahead of default walk/stand logic)
player_api.register_locomotion_evaluator(50, function(player, ctx)
    -- If player is wearing a glider or flight harness, trigger flight animation
    if ctx.in_air and player:get_meta():get_string("has_glider") == "true" then
        return "fly"
    end
    -- Return nil to fall through to standard movement evaluation
    return nil
end)
```

*See [StateEvaluationContext](API.md#stateevaluationcontext) in API.md for all pre-allocated context fields.*

---

### Client Input & Control Events

Intercept raw client inputs without polling:

```lua
-- Key Press
player_api.register_on_control_press(function(player, key)
    if key == "aux1" then
        -- Handle ability activation
    end
end)

-- Key Hold (fired every frame key remains depressed)
player_api.register_on_control_hold(function(player, key, duration)
    if key == "sneak" and duration > 3.0 then
        -- Charged stealth mechanic
    end
end)

-- Key Release
player_api.register_on_control_release(function(player, key, duration)
    -- duration in seconds
end)
```

*See [Type Aliases & Callbacks in API.md](API.md#type-aliases--callbacks).*

---

## Performance & Server Scalability Architecture

`x_player_api` is engineered for 60 FPS client responsiveness and high-population dedicated servers ($N = 50+$):

* **Zero-GC Hot Loop**: All per-player semantic states are pre-allocated on join and mutated in-place. The globalstep produces **0 temporary table allocations** per frame.
* **$O(1)$ Memoized Item Classification**: Wielded item groups (`food`, `shield`, `bow`, `eatable`) and weapon action substrings (`sword`, `blade`, `spear`) are evaluated once on first encounter and stored in `ITEM_CACHE`.
* **Center-First Short-Circuiting**: Ground collision checks probe `{x = 0, z = 0}` first. Because ground terrain is solid over 95% of the time, the outer 4 corner probes are skipped, eliminating ~80% of `core.get_node_or_nil` queries.
* **Attached Entity Fast-Path**: Players riding carts, boats, mounts, or airships immediately exit terrain checks, avoiding redundant raycasts.

---

## Debugging & Administration Commands

* `/controls_debug`: Display current player control and semantic locomotion state in real time.
* `/model_format [glb|b3d|toggle|status]`: Query or instantly switch the active player model format between modern GLB (multi-track) and classic B3D (single-track) on the fly.
* `/toggle_model`: Quick shortcut to toggle between GLB and B3D formats without restarting the server.
* `/test_anim [anim_name|duration|list|stop]`: Run an in-game animated slideshow or test a specific animation.

---

## Model Format Selection (GLB vs. B3D)

`x_player_api` provides full dual-format support for both **GLB (glTF 2.0 binary)** and **B3D (Blitz3D)** player character models.

#### Automatic Format Resolution & Observer Cohorts

In multiplayer environments, `x_player_api` automatically resolves and delivers the compatible model per client without requiring manual server configuration:
- **Modern Luanti 5.17.0+ clients** (`modern_cohort`): Render the GLB mesh with multi-track animation blending.
- **Legacy clients** (`legacy_cohort`): Render the Blitz3D (`.b3d`) mesh with the unified single-track animation timeline.

Both cohorts observe each other in the same world simultaneously via dual visual proxies without duplicate packets or unsupported mesh crashes.

> [!NOTE]
> For details on why older clients (< 5.12, e.g. Luanti 5.10) experience camera-relative attachment vibration or prediction conflicts compared to modern 5.17+ clients, see [Limitations of Older Clients](#limitations-of-older-clients-luanti-510x--511x).

#### Runtime Switching & Testing (Lua API)

For debugging, development, or forced format overrides, the active format can be queried and switched dynamically:

```lua
-- Query the active format ("glb" or "b3d")
local current_format = player_api.get_model_format()

-- Switch active format and re-apply mesh to all connected players (or a specific player)
player_api.set_model_format("b3d") -- Switches to character.b3d / 3d_armor_character.b3d
player_api.set_model_format("glb") -- Switches to character.glb / 3d_armor_character.glb
```

> [!NOTE]
> **Automatic 3D Wield Item Parity**: Switching between GLB and B3D automatically updates active wield items and compensates for Blitz3D exporter axis inversions. See [Dual-Format Orientation Parity & Exporter Coordinate Discrepancy](#dual-format-orientation-parity--exporter-coordinate-discrepancy) below.

---

## 3D Wield Items

`x_player_api` provides native 3D wielded item rendering via an ephemeral child `LuaEntity` attached to the standard `Arm_Right` bone.

### Key Technical Features

* **Native 3D Extrusion & Mesh Rendering**: Uses Luanti's built-in `visual = "wielditem"`, automatically extruding 2D inventory sprites into 3D voxel items and rendering registered node boxes and 3D meshes natively.
* **Zero Rig Alteration**: Attached directly to the canonical `Arm_Right` bone. Syncs seamlessly with all walking, sprinting, mining, attacking, and emote animations across both `character.glb` and `character.b3d`.
* **Dual-Format Orientation Parity**: Automatic bone coordinate space compensation ensures held weapons, tools, and blocks point forward identically in both GLB and B3D without requiring separate mod transforms or exporter patches.
* **Server Performance (`static_save = false`)**: Child entities are never saved to mapblocks. In the event of a server shutdown or restart, entities vanish cleanly without database pollution or orphaned items.
* **Physics & Raycast Isolation (`pointable = false`)**: Attached items never block user crosshairs, node digging, or projectile raycasts.
* **Throttled Updates (0.2s Interval)**: Item checks are decoupled from frame step intervals. Property updates are pushed to clients only when the held item string changes (instant on hotbar swap).
* **Natural Forward Alignment & Proportionate Scale**: Calibrated with canonical forward bone orientation (`rot = {x = -90, y = 45, z = 90}`, `pos = {x = 0, y = 5.2, z = -3.5}`) and calculated dynamically from the held item's `wield_scale`, preventing oversized models, backward fin-stretching, and double-scaling.
* **Smart Category & Group Orientations**: Includes built-in angle compensation for upright items (torches, saplings, plants at 180°), reverse-diagonal tools (shovels, screwdrivers, vessels at 135°), and nodes (compact 0.75x mini-blocks).
* **Pivot Translation Drift Compensation**: Automatically compensates for origin expansion on elongated weapons, keeping handles firmly positioned in the palm grip.
* **Ecosystem Compatibility**: Companion bridge mod (`x_player_bridge`) suppresses legacy 2D texture compositing from `3d_armor` / `wieldview` to prevent z-fighting and duplicate items.

### Dual-Format Position & Orientation Parity (B3D vs GLB)

When switching between `character.glb` (glTF 2.0) and `character.b3d` (Blitz3D), held items attached to `Arm_Right` and skeletal bone overrides (`Head`, `Arm_Right`, `Arm_Left`) maintain 100% visual parity, alignment, and coordinate integrity. Understanding why this requires automated compensation is important when working with low-level bone attachments, exporters, or custom player models:

#### Root Cause of the Discrepancy

1. **Master Blender Armature (`official_character.blend`)**:
   The player rig, bone hierarchy, and bone rest matrices in the master Blender file are identical for both models. The `Arm_Right` bone's head, tail, and roll angles have not been modified.
2. **Blitz3D Exporter (`export_b3d.py`) Matrix Inversion**:
   The legacy Blitz3D exporter maps Blender's Z-up right-handed coordinate space into Blitz3D's Y-up left-handed space by applying a hardcoded transformation matrix on bone definitions:
   $$\text{BONE\_TRANS\_MATRIX} = \begin{bmatrix} -1 & 0 & 0 & 0 \\ 0 & 0 & -1 & 0 \\ 0 & -1 & 0 & 0 \\ 0 & 0 & 0 & 1 \end{bmatrix}$$
   This transformation matrix effectively introduces a 180° rotation around the X-axis for every bone relative to Blender space.
3. **Axis & Position Inversion on Bone Rigs**:
   Because of this 180° X-axis flip in exported B3D files:
   - The local orientation axes are inverted: an entity pointing forward along $+Z$ in GLB space points backward along $-Z$ in B3D without rotation compensation.
   - The local position coordinates are reflected: in GLB, $Z_{\text{world}} = -Z_{\text{bone}}$ (so $Z_{\text{bone}} = -3.5$ maps to $Z_{\text{world}} = +3.5$), whereas in B3D, $Z_{\text{world}} = +Z_{\text{bone}}$. Without position compensation, an item with $Z = -3.5$ would be displaced 7 units backward behind the player rather than sitting forward with its handle in the palm!
   - Bone override Euler rotations are inverted: in B3D, pitch ($X$), yaw ($Y$), and roll ($Z$) rotate in the negated direction relative to GLB. Without runtime compensation, negative pitch tilts the B3D head downward rather than upward, and positive yaw flairs `Arm_Left` outward to the flank during bow aiming instead of drawing inward across the chest.
4. **glTF 2.0 (`.glb`) Exporter**:
   Blender's official glTF 2.0 exporter preserves native Blender joint coordinate frames and applies axis conversion at the scene root node rather than inverting individual bone coordinate spaces.

#### Automated Runtime Compensation in `wield.lua` & `bone_overrides.lua`

Rather than altering the canonical Blitz3D exporter (which would break compatibility with existing Luanti B3D animations and third-party models), `x_player_api` handles this discrepancy dynamically at runtime:
* **Wield Item Attachment Compensation (`wield.lua`)**: When `player_api.get_model_format()` returns `"b3d"`, it automatically applies position reflection along X and Z alongside Euler rotation compensation to the attachment parameters. This completely counteracts the B3D exporter's coordinate flip, ensuring all items (swords, tools, torches, bows, blocks) point forward and have their handles positioned squarely in the palm of the hand identically across both GLB and B3D.
* **Dual-Format Bone Override Compensation (`bone_overrides.lua`)**: When dispatching bone transformations to `proxies.b3d` (or in pure native B3D mode), `x_player_api.set_bone_override` automatically negates Euler rotation components ($\vec{R}_{\text{b3d}} = \{-R_x, -R_y, -R_z\}$) and reflects translation ($\vec{P}_{\text{b3d}} = \{-P_x, P_y, -P_z\}$) for symmetrical single-axis bones (e.g. `Head`, `Arm_Right`). For complex asymmetric poses like `Arm_Left` in bow aim, it applies dedicated non-linear inverse kinematics to keep the left hand firmly locked onto the bow grip across the full vertical pitch arc without flaring outward.

### B3D Rotation Wiggling Workaround (Luanti Issue #15692)

In Luanti client versions prior to engine-level fixes, Irrlicht's skeletal animation matrix decomposition (`CMatrix4<T>::getScale()`) suffers from a critical bug:
* **The Root Cause**: If a bone has a perfect 180° rotation around a cardinal axis (e.g. Y-axis: diagonal `[-1, 1, -1]`), all off-diagonal entries in the transformation matrix are exactly zero. Irrlicht's optimization falsely assumes that zero off-diagonals mean the matrix is unrotated, decomposing the bone into an **Identity rotation `(0, 0, 0)` with negative scale `(-1, 1, -1)`**. This mirrors attached wield items and shields into the wrong hand or backwards.
* **The Hybrid Solution**:
  1. **Mode B (Asset & Exporter Level)**: `assets/export_b3d.py` and `scripts/wiggle_b3d.py` perturb any exact 180° rotation by $\pm 10^{-3}$ radians ($< 0.05^\circ$), forcing Irrlicht to evaluate column lengths and return true Euclidean positive scale `(1, 1, 1)`. Canonical `models/character.b3d` is pre-patched on disk with zero runtime overhead.
  2. **Mode A (Dynamic In-Memory Fallback)**: `b3d_wiggler.lua` provides a pure Lua binary chunk walker that inspects any 3rd-party B3D models at runtime (e.g. `3d_armor_character.b3d`). If unpatched perfect rotations are detected, it wiggles both `NODE` rest poses and `KEYS` animation frames in-memory without changing file sizes or dropping keyframes, registers the wiggled mesh via `core.dynamic_add_media`, and transparently points the model definition's `def.mesh` to the wiggled asset while aliasing in `x_player_api.registered_models` (preserving model identifiers and animations).
  3. **Zero External Dependencies**: Pure Lua 5.1/LuaJIT implementation with zero mod dependencies in `mod.conf`, maintaining full backward compatibility and attributing Lars Mueller (LMD / appgurueu) and `modlib`.

#### Using the Standalone CLI Tool (`scripts/wiggle_b3d.py`)

A Python CLI script is included to inspect and pre-patch `.b3d` models directly on disk before packaging, testing, or deploying:

```bash
# In-place patching (modifies file directly):
python3 scripts/wiggle_b3d.py path/to/model.b3d

# Save patched model to a separate output file:
python3 scripts/wiggle_b3d.py path/to/input.b3d path/to/output.b3d
```

##### Example Output
```text
Processed 'models/character.b3d':
  - Nodes wiggled: 5
  - Keyframes wiggled: 994
Successfully saved to 'models/character.b3d' (216348 bytes).
```

##### Key Technical Features
* **Preserves All Baked Animations**: Recursively walks both `NODE` (rest pose) and `KEYS` (animation frame) chunks. Unlike procedural workarounds that discard `node.keys`, all keyframe ranges (`stand`, `walk`, `mine`, etc.) remain 100% intact.
* **Exact Byte-Length Preservation**: Re-encodes each perturbed quaternion in-place as four 32-bit little-endian IEEE-754 floats (`<4f`), preserving identical file sizes and chunk alignments.
* **Idempotent**: Running the script on an already patched model safely detects zero buggy rotations (`Nodes wiggled: 0, Keyframes wiggled: 0`) and makes no changes.
* **Batch Processing**: To pre-patch all `.b3d` models across a mod or models folder in one command:
  ```bash
  for f in $(find models/ -name "*.b3d"); do python3 scripts/wiggle_b3d.py "$f"; done
  ```

### 3D Wield Item Customization & Extensibility

`x_player_api` provides four decoupled mechanisms for mods to customize held item positioning, rotation, scale, and luminescence without touching core mod files:

#### Direct Item & Node Definition Properties (Flat Prefixes)

In accordance with [Luanti engine guidelines (`lua_api.md`)](https://github.com/luanti-org/luanti/blob/master/doc/lua_api.md), custom fields added to item or node definitions must start with an underscore (`_`) to avoid collisions with future engine properties. Non-prefixed attributes (like `wield_offset`) are ignored.

Any mod registering a craftitem, tool, or node can declare custom wield transforms directly using flat prefixed fields:

```lua
core.register_tool("weapons:halberd", {
    description = "Steel Halberd",
    inventory_image = "weapons_halberd.png",
    _wield_offset = {x = 0, y = 0.8, z = -0.4},   -- Hand bone translation offset {x, y, z}
    _wield_rotation = {x = -80, y = 30, z = 85},   -- Local Euler rotation in degrees
    _wield_scale = 1.8,                           -- Scalar visual scale multiplier (or Vector3)
    _wield_glow = 8,                              -- Explicit entity glow brightness (0-14)
})
```

#### Generic Item Groups (`group:*`)

Items belonging to specific item groups automatically receive calibrated transforms without requiring item-specific configurations:

| Group | Hand Alignment | Intended Items |
| :--- | :--- | :--- |
| `group:torch` | Upright forward, angled handle | Torches, lanterns, lit candles |
| `group:bucket` | Upright centered in hand grip | Buckets, pails, large containers |
| `group:vessel` | Upright centered in hand grip | Glass bottles, drinking cups, flasks |
| `group:shovel` | Forward reverse-diagonal | Shovels, spades |
| `group:bow` | Centered bow charging grip | Bows, crossbows |
| `group:screwdriver` | Forward working tip | Screwdrivers, wands, styluses |
| `group:sapling` / `group:flower` / `group:plant` | Upright natural foliage | Flowers, seedlings, crops, bushes |

Any item declaring `groups = {bucket = 1}` or `groups = {vessel = 1}` inherits the group position automatically. Disabled groups (`rating = 0`) are ignored.

#### Runtime API Registration (`player_api.register_wield_item_offset`)

External mods can register or override transforms dynamically at load time:

```lua
-- Get the active wield entity for a player
local entity = player_api.get_wield_entity(player)

-- Set visibility of a player's held item
player_api.set_wield_item_visibility(player, false)

-- Register offset for an entire item group
player_api.register_wield_item_offset("group:bucket", {
    pos = {x = 0, y = 0, z = 0.2},
    rot = {x = 180, y = 0, z = 0},
})

-- Register offset for a specific third-party item
player_api.register_wield_item_offset("weapons:greatsword", {
    pos = {x = 0, y = 5.0, z = 2.4},
    scale = {x = 1.2, y = 2.0, z = 1.2},
})
```

#### Base Type Fallbacks

Any item without custom definitions or groups automatically falls back to its engine type (`type:node`, `type:tool`, or `type:craftitem`), ensuring full 3D nodes, diagonal tools, and upright 2D craftitems render consistently with zero manual setup.

#### Configuration & Runtime Toggling

3D wielded item rendering can be enabled or disabled via settings (`luanti.conf` or the in-game Settings menu under **Mods -> x_player_api**):

```ini
# Enable 3D wielded item rendering attached to the player hand (default: true)
x_player_api.enable_wield_item = true

# Periodic throttle interval in seconds for wield item polling (default: 0.2s)
# Note: Switching held items triggers instant updates with 0ms latency
x_player_api.wield_update_interval = 0.2

# Enable double-tapping forward key to sprint (default: true)
x_player_api.enable_double_tap_sprint = true

# Enable holding AUX1 (Special) key while moving forward to sprint (default: true)
x_player_api.enable_aux1_sprint = true

# Preferred global model format (default: glb, options: glb, b3d)
x_player_api.model_format = glb

# Enable pure native B3D mode (bypasses visual proxies in B3D mode, preserving native client prediction; default: false)
x_player_api.pure_native_b3d = false
```

Or dynamically in Lua via `player_api.set_wield_item_enabled(boolean)`, `player_api.set_aux1_sprint_enabled(boolean)`, and `player_api.set_double_tap_sprint_enabled(boolean)`.

*See [3D Wield Item API in API.md](API.md#3d-wield-item-api) for full method signatures, transforms, and [WieldItemCustomDef](API.md#wielditemcustomdef).*

---

## Testing Framework

`x_player_api` includes a zero-dependency, modular BDD (Behavior-Driven Development) test framework designed for testing Luanti mods without requiring the Luanti engine or graphical client to be running. It is compatible with standard BDD runners like Busted and Mineunit.

### Running Tests

Run the complete test suite directly with Lua (compatible with Lua 5.1 / LuaJIT):

```bash
lua test.lua
```

Static analysis and lint checks are run via `luacheck`:

```bash
luacheck .
```

Workspace code style and type diagnostics are run via `lua-language-server`:

```bash
lua-language-server --check=.
```

### Test Suite Structure

The test architecture is organized under the `tests/` directory:

```
tests/
├── framework.lua         # Lightweight BDD test runner and assertion library
├── mock_env.lua          # Mock Luanti engine environment (core.*, ItemStack, vector, Player SAO)
└── specs/                # Modular test specifications
    ├── b3d_wiggler_spec.lua     # In-memory B3D byte perturbation, chunk parsing, quaternion math
    ├── controls_spec.lua        # Semantic state engine, recovery, posture & airborne gating
    ├── eating_spec.lua          # Consumable registry, node/craftitem crumbs, eating action
    ├── environment_spec.lua     # Zero-allocation liquid, ladder, and solid ground probing
    ├── equip_sound_spec.lua     # Declarative equip sounds, item overrides, pitch variance
    ├── legacy_b3d_spec.lua      # B3D single-timeline frame ranges, blend removal, action hold
    ├── model_spec.lua           # Format switching (GLB/B3D), B3D binary validation, aliases
    ├── proxies_spec.lua         # Dual visual proxies, observer cohorts, bone override throttling
    ├── pure_native_b3d_spec.lua # Zero-proxy native B3D mode & connected_players iteration
    ├── wield_entity_spec.lua    # 3D child entity lifecycle, delta updates, death/respawn
    ├── wield_offsets_spec.lua   # Attachment math, flat prefix attributes, scale normalization
    └── wield_settings_spec.lua  # Dynamic runtime settings enablement & cleanup
```

- **[`test.lua`](test.lua)**: The clean entrypoint runner that initializes the mock environment, exposes BDD test globals, requires spec suites, and reports aggregate results.
- **[`tests/framework.lua`](tests/framework.lua)**: Implements `describe`, `it`, `before_each`, and `after_each` lifecycle blocks, deep table equality assertions, colorized ANSI output, execution timing, and failure summaries without fail-stop execution.
- **[`tests/mock_env.lua`](tests/mock_env.lua)**: Pure Lua implementation of Luanti engine globals (`core.*`), vector math, item stacks with metadata serialization, particle spawner tracking, timers, and simulated player objects.

### Writing New Tests

Create a new specification file under `tests/specs/<feature>_spec.lua` or add to existing spec files.

#### 1. Anatomy of a Spec File

```lua
-- tests/specs/my_feature_spec.lua
local mock_env = require("tests.mock_env")

describe("My Feature Subsystem", function()
	local player

	before_each(function()
		-- Set up fresh player or reset state before each test case
		player = mock_env.join_player("Tester")
	end)

	after_each(function()
		-- Optional clean-up after each test
	end)

	it("evaluates expected behavior", function()
		player:set_wielded_item("default:sword_steel", 1)
		player_api.update_wield_item(player, true)

		local entity = player_api.get_wield_entity(player)
		assert.is_not_nil(entity, "Wield entity should be attached")
		assert.equal(true, entity:get_properties().is_visible)
	end)

	it("verifies numerical precision with tolerances", function()
		local pos = player:get_pos()
		assert.near(0.0, pos.x, 1e-4, "Position X should be near zero")
	end)
end)
```

#### 2. Registering the Spec in `test.lua`

Add your new spec file to [`test.lua`](test.lua):

```lua
require("tests.specs.my_feature_spec")
```

#### 3. Available Assertions

The built-in assertion library (`assert.*`) provides:

| Assertion | Description |
| :--- | :--- |
| `assert.equal(expected, actual, [msg])` | Exact value equality or deep table comparison with key-level diffs |
| `assert.not_equal(unexpected, actual, [msg])` | Ensures values or tables are not equal |
| `assert.near(expected, actual, [epsilon], [msg])` | Floating point comparison within an epsilon tolerance (default: `1e-5`) |
| `assert.is_true(condition, [msg])` | Asserts condition is strictly `true` |
| `assert.is_false(condition, [msg])` | Asserts condition is strictly `false` |
| `assert.is_nil(val, [msg])` | Asserts value is `nil` |
| `assert.is_not_nil(val, [msg])` | Asserts value is not `nil` |
| `assert.table_equal(expected, actual, [msg])` | Deep recursive comparison of table contents with detailed field diffs |
| `assert.error(func, [msg])` | Verifies that executing `func()` raises an error |

#### 4. Working with Mock Objects

The mock environment provides helpers to simulate Luanti engine behaviors:

* `mock_env.join_player(name)`: Creates a mock player object, registers it in `core.get_connected_players()`, triggers `core.register_on_joinplayer` callbacks, and resolves any immediate attachment timers.
* `mock_env.create_player(name)`: Instantiates a standalone mock player object without triggering join callbacks.
* `player:set_wielded_item(item_name, count, meta)`: Simulates player holding an item with optional metadata (e.g. `meta = {color = "#FF0000"}`).
* `player:set_hp(hp)`: Adjusts player health points (e.g. `0` to test death handlers).
* `core._after_timers`: Inspect or execute queued timers created by `core.after(delay, fn)`.
* `core._particlespawners`: Inspect active particle spawners created by `core.add_particlespawner`.
* `core._sounds_played`: Inspect sounds triggered via `core.sound_play`.

---

## Compiling API Documentation with lua-language-server

All public API methods, configuration registries, types, classes, and callback signatures in `x_player_api` are thoroughly annotated using standard [LuaLS Annotations](https://github.com/LuaLS/lua-language-server/wiki/Annotations) (`@class`, `@type`, `@param`, `@return`, `@nodiscard`, `@alias`).

A fully compiled, exhaustive API reference is maintained in [`API.md`](API.md).

### Prerequisites
Install `lua-language-server`:
* **macOS** (Homebrew): `brew install lua-language-server`
* **Linux** (Arch/Debian/Fedora/pip): Package manager or release binary from [LuaLS GitHub releases](https://github.com/LuaLS/lua-language-server/releases).

### Compilation Command
To recompile `API.md` from the Lua source code annotations:

```bash
mkdir -p doc_build && lua-language-server --doc=. --doc_out_path=doc_build --doc_format_path=scripts/doc_format.lua && cp doc_build/doc.md API.md && rm -rf doc_build
```

### Configuration (`.luarc.json`)
The export behavior and workspace settings are configured in [`.luarc.json`](.luarc.json):
* Targets `Lua 5.1` runtime.
* Pre-defines global engine types (`core`, `player_api`, `x_player_api`, `vector`, `ItemStack`).
* Excludes asset directories, test harnesses, and scratch scripts from documentation output.
* Sets package export namespace to `x_player_api`.

---

## Installation

### From ContentDB
Search for **X Player API** in the Luanti online content repository and click **Install**.

Alternatively, install directly from the ContentDB package page: [https://content.luanti.org/packages/SaKeL/x_player_api/](https://content.luanti.org/packages/SaKeL/x_player_api/)

### From Git
Clone directly into your Luanti `mods/` directory:
```bash
git clone https://github.com/sakel-hub/x_player_api.git
```

Enable `x_player_api` in your world configuration. If `player_api` is present, `x_player_api` safely and seamlessly acts as a drop-in override.

---

## AI Transparency & Assistance Statement

This package adheres to an **AI-Assisted** development model under strict human authorship and editorial control:

- **Human Creative Authority & Codebase**: All software architecture, gameplay mechanics, core algorithms, and mod logic are authored, designed, and directed by a human developer.
- **Administrative & Tooling Scope**: AI tools are utilized strictly in an auxiliary capacity for administrative workflows, repository maintenance (e.g., changelogs, commit formatting), documentation drafting, and test-case structuring.
- **Zero Synthetic Media**: Generative AI is **not** used to produce textures, sprites, 3D meshes/models, audio, or visual assets. All media files are created or attributed to original human artists under valid open licenses.
- **Verification & Responsibility**: Every line of code, configuration, and documentation is manually inspected, tested, and validated by the maintainer, who retains full copyright and legal responsibility for the package.

## Authors & License

See `license.txt` for license details (LGPLv2.1+ / CC-BY-4.0).

