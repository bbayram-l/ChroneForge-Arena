class_name Module
extends Resource

enum Category { STRUCTURAL, POWER, WEAPON, DEFENSE, THERMAL, TEMPORAL, AI }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var category: Category = Category.STRUCTURAL
@export var rarity: Rarity = Rarity.COMMON
@export var description: String = ""

# Economy
@export var cost: int = 3

# Grid footprint
@export var grid_size: Vector2i = Vector2i(1, 1)

# Physical properties (affect PhysicsLite)
@export var weight: float = 1.0
@export var structural_load: float = 1.0

# Power
@export var power_gen: float = 0.0    # units generated per tick (power modules)
@export var power_draw: float = 0.0   # units consumed per tick

# Heat
@export var heat_gen: float = 0.0         # heat added per shot/tick
@export var heat_reduction: float = 0.0   # heat removed per tick (thermal modules)

# Combat — weapons
@export var base_damage: float = 0.0
@export var fire_rate: float = 0.0    # shots per second; 0 = non-weapon
@export var recoil_force: float = 0.0

# Combat — defense
@export var hp: float = 0.0
@export var shield_value: float = 0.0

# Temporal
@export var paradox_rate: float = 0.0  # paradox added per second while active

# Runtime flag — set by ParadoxSystem on overload
var disabled: bool = false
