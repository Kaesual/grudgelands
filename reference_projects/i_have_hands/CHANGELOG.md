# CHANGELOG

### 1.11.2:

changelog:

- added native integration with `x_player_api` player models (ported from the now removed `x_player_bridge` mod):
  - both arms are raised to hold carried containers while standing and walking
  - upright standing posture while riding carts/minecarts
  - settings: `i_have_hands.enable_carrying_posture`, `i_have_hands.enable_cart_posture`
- `x_player_api` added to optional dependencies

### 1.11.1:

changelog:

- removed "starting node timer.." message

### 1.11.0:

changelog:

- code refactor
- removed placement animation (may return once we get proper client-side mods)
- now shows the correct voxelibre chest when carried

bugfix:

- should crash 80% less.

### 1.10.2:

changelog:

- when placing down an armor stand it will now show its amor. (voxelibre/mineclonia)

bugfix:

- (voxelibre/mineclonia) picking up an armor_stand would result in amor duplication

### 1.10.1:

- added hud indicator (in case the carried inv node does not render)
- player now needs privs/perms to use commands(oops)

### 1.10.0:

- furnaces can now be picked up again
- player now looks like they are holding the inventory node in their hands
- placement animation is now an actual animation (looks smoother)
- added option to allow picking up any node (enable via command `/ihh allow_all`)
- added commands/settings (settings get reset, unless changed in init file)
- sounds effects are a bit louder
- added support for `age of mending(game)`, not fully but.. it works.
- updated some deprecated stuff
- added a CHANGELOG file
- updated demo gif and banner images

### 1.0.9:

bugfix:

- crash when dropping a chest with pipeworks installed

### 1.0.8:

bugfix:

- [x] VoxeLibre players could not open door with an empty hand

### 1.0.7

- [x] add a short delay to the hud popup
  - seeing the hud message constantly is not great
- [x] add support for mineclonia
- [x] don't show the hud when the player is already holding a "chest/inventory"

---

### 1.0.6

- [|] (nvm no real reason to implement this) MCL support for picking up double chests
- [x] update gif **make it look nice**
- [x] hover over in-game inventory show player hud
- [x] #BUG (this is a bad thing, the worst): on drop the node will remove any node in its way
- [x] #BUG the held inv should be dropped on death

---

- [x](prevent data loss): if object is not attached to anything add
  its node and set the data will have to use mod storage storage
  needs to store and objects
- [x]: inv to storage {owner=POS,data=metadata}
- [x]: drop/place node when the player leaves
- [x]: need to check if node has protection
- [x]: placing is eating blocks at times, need to check if node is empty
- [x]: view in first person
- [x](issue could be that obj pos is float): detached should appear as
  close as possible to the last location
- [x]_kinda_: add a fall back a node's visual is nil
- [x](audio:good enough,visual:good): add some effects
- [x]: figure out double chests
- [x]: add support for storage drawers mod
