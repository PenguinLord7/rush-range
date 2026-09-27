extends Node
## Global signal bus.
##
## Gameplay systems emit here instead of reaching directly into the HUD or the
## effects layer. This keeps weapons, targets and UI decoupled: the HUD listens
## for ammo/score, the effects layer listens for impacts, etc.

## A projectile/hitscan/punch connected with a target.
## headshot - true if the head hitbox was hit.
## killed   - true if that hit destroyed the target.
signal hit_confirmed(killed: bool, headshot: bool)

## A numeric damage popup should appear at world_position.
signal damage_dealt(world_position: Vector3, amount: int, headshot: bool)

## The active weapon changed. info has: name, slot, icon, kind.
signal weapon_equipped(slot: int, info: Dictionary)

## Ammo state for the HUD. current/reserve are weapon-specific (reserve == -1
## means "infinite", e.g. the fist).
signal ammo_changed(current: int, reserve: int, reloading: bool)

signal reload_started(duration: float)
signal reload_finished()

## A shot was blocked because reserve ammo was empty.
signal out_of_ammo()

signal score_changed(score: int)
signal target_destroyed(world_position: Vector3)

## A weapon shot was fired (used for crosshair kick feedback).
signal weapon_fired

## An explosion happened; the effects layer spawns the blast.
signal explosion(world_position: Vector3, radius: float)

## Transient on-screen message (e.g. "NO AMMO").
signal notice(text: String)
