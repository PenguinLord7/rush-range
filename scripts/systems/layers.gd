class_name Layers
## Named physics-layer bits. Keep the values in sync with the collision layer
## checkboxes in the editor if you add new categories.
##
##   1 = World      (static arena geometry, floors, walls)
##   2 = Target     (target hitboxes)
##   3 = Player
##   4 = Projectile (grenades)

const WORLD: int = 1 << 0
const TARGET: int = 1 << 1
const PLAYER: int = 1 << 2
const PROJECTILE: int = 1 << 3

## What a bullet ray can hit.
const SHOOTABLE: int = WORLD | TARGET
