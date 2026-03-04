## GameState — global singleton (autoload)
## Tracks run economy, round progression, and match results.
extends Node

signal gold_changed(new_amount: int)
signal round_changed(new_round: int)
@warning_ignore("UNUSED_SIGNAL")
signal run_ended(won: bool)

var gold: int = 0
var temporal_shards: int = 0
var current_round: int = 1
var win_streak: int = 0
var loss_streak: int = 0
var mmr: int = 1000
var player_lives: int = 3
var total_wins: int = 0
var total_losses: int = 0

const BASE_INCOME: int = 5
const MAX_INTEREST: int = 5
const WIN_BONUS: int = 2

func start_run() -> void:
	gold = BASE_INCOME
	temporal_shards = 0
	current_round = 1
	win_streak = 0
	loss_streak = 0
	player_lives = 3
	total_wins = 0
	total_losses = 0

## outcome: "player" = win, "enemy" = loss, "draw" = neither.
## Draws advance the round but cost no life and grant no win bonus.
func earn_round_income(outcome: String) -> void:
	var income := BASE_INCOME

	# Interest: +1 per 10 gold saved, capped at 5
	@warning_ignore("INTEGER_DIVISION")
	income += mini(gold / 10, MAX_INTEREST)

	if outcome == "player":
		income += WIN_BONUS
		win_streak += 1
		loss_streak = 0
		mmr += 25
		total_wins += 1
	elif outcome == "enemy":
		player_lives -= 1
		loss_streak += 1
		win_streak = 0
		mmr = maxi(0, mmr - 20)
		# Loss streak consolation: +1–3 bonus
		income += mini(loss_streak - 1, 3)
		total_losses += 1
	# draw: no life lost, no win bonus, streaks unchanged

	gold += income
	current_round += 1
	gold_changed.emit(gold)
	round_changed.emit(current_round)

func is_run_over() -> bool:
	return player_lives <= 0

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func get_reroll_cost() -> int:
	if current_round <= 3:
		return 2
	elif current_round <= 7:
		return 3
	return 4
