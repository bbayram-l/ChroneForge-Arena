## DamageResolver — pure static helpers implementing all combat formulas
## from the SYSTEM design document. No state; safe to call from anywhere.
class_name DamageResolver

## Core damage formula:
## FinalDamage = BaseDamage × PowerEfficiency × StabilityModifier
##             × TemporalModifier × RandomVariance
static func resolve_shot(
	weapon:            Module,
	power_efficiency:  float,
	stability_modifier: float,
	temporal_modifier: float,
	rng:               RandomNumberGenerator
) -> float:
	var variance := rng.randf_range(0.9, 1.1)
	return maxf(
		weapon.base_damage
			* clampf(power_efficiency,  0.0, 1.2)
			* clampf(stability_modifier, 0.0, 1.0)
			* clampf(temporal_modifier,  0.0, 2.0)
			* variance,
		0.0
	)

## Diminishing returns: StackModifier = 1 / (1 + k × (Stacks − 1))
## Default k values: damage=0.15, shield=0.25, cooldown=0.35
static func stack_modifier(stacks: int, k: float = 0.15) -> float:
	if stacks <= 1:
		return 1.0
	return 1.0 / (1.0 + k * float(stacks - 1))

## EffectiveHP = HP + ShieldValue × RechargeEfficiency (capped at 1.8×)
static func apply_shield(
	raw_damage:         float,
	current_shield:     float,
	_recharge_efficiency: float  # stored for future use
) -> Dictionary:
	var absorbed := minf(raw_damage, current_shield)
	return {
		"hp_damage":     raw_damage - absorbed,
		"shield_damage": absorbed,
	}

## Burst reduction: 30% once per 3 seconds (Reactive Armor)
static func apply_reactive_armor(raw_damage: float) -> float:
	return raw_damage * 0.70

## OverheatPenalty = 1 − (ExcessHeat / MaxHeat) — linear decay
static func apply_overheat(base_output: float, excess_heat: float, max_heat: float) -> float:
	if excess_heat <= 0.0:
		return base_output
	return base_output * maxf(1.0 - excess_heat / max_heat, 0.0)
