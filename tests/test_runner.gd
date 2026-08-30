extends SceneTree

const Rules = preload("res://scripts/core/scoring_rules.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Action = preload("res://scripts/core/game_action.gd")
const AI = preload("res://scripts/controllers/ai_controller.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_scoring()
	_test_exhaustive_bust_consistency()
	_test_session_flow()
	_test_ai()
	if failures == 0:
		print("PASS: %d checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)

func _test_scoring() -> void:
	_expect_eq(Rules.score_selection([1]), 100, "single one")
	_expect_eq(Rules.score_selection([5]), 50, "single five")
	_expect_eq(Rules.score_selection([1, 1, 5]), 250, "singles add")
	_expect_eq(Rules.score_selection([1, 1, 1]), 1000, "triple ones")
	_expect_eq(Rules.score_selection([4, 4, 4]), 400, "triple fours")
	_expect_eq(Rules.score_selection([1, 1, 1, 1]), 2000, "four ones")
	_expect_eq(Rules.score_selection([3, 3, 3, 3, 3]), 1200, "five threes")
	_expect_eq(Rules.score_selection([1, 1, 1, 1, 1, 1]), 8000, "six ones")
	_expect_eq(Rules.score_selection([5, 5, 5, 5, 5, 5]), 4000, "six fives")
	_expect_eq(Rules.score_selection([1, 2, 3, 4, 5]), 500, "low straight")
	_expect_eq(Rules.score_selection([2, 3, 4, 5, 6]), 750, "high straight")
	_expect_eq(Rules.score_selection([1, 2, 3, 4, 5, 6]), 1500, "full straight")
	_expect_eq(Rules.score_selection([1, 1, 2, 3, 4, 5]), 600, "straight plus one")
	_expect_eq(Rules.score_selection([2, 2, 2, 3, 3, 3]), 500, "two triples")
	_expect_eq(Rules.score_selection([2, 2, 5, 5]), -1, "invalid mixed selection")
	_expect_eq(Rules.score_selection([5, 5]), 100, "two fives")
	_expect_true(not Rules.has_score([2, 3, 4, 6]), "bust roll")
	_expect_true(Rules.has_score([2, 2, 2]), "triple scores")
	_expect_eq(Rules.score_selection([3, 3, DiceCatalog.WILD_FACE]), 300, "wild completes a triple")
	_expect_eq(Rules.score_selection([1, 1, DiceCatalog.WILD_FACE]), 1000, "wild completes triple ones")
	_expect_eq(Rules.score_selection([1, 2, 3, 4, DiceCatalog.WILD_FACE]), 500, "wild completes low straight")
	_expect_eq(Rules.score_selection([2, 3, 4, 5, DiceCatalog.WILD_FACE]), 750, "wild chooses higher straight")
	_expect_eq(Rules.score_selection([1, 2, 3, 4, 5, DiceCatalog.WILD_FACE]), 1500, "wild completes full straight")
	_expect_eq(Rules.score_selection([1, 1, 2, 3, 4, DiceCatalog.WILD_FACE]), 600, "wild straight can combine with a normal scoring single")
	_expect_eq(Rules.score_selection([4, 4, 4, DiceCatalog.WILD_FACE]), 800, "wild extends a triple to four of a kind")
	_expect_eq(Rules.score_selection([DiceCatalog.WILD_FACE]), -1, "wild cannot score alone")
	_expect_eq(Rules.score_selection([1, DiceCatalog.WILD_FACE]), -1, "wild cannot become a scoring single")
	_expect_eq(Rules.score_selection([1, DiceCatalog.BLANK_FACE]), -1, "blank face invalidates a selection")
	_expect_true(Rules.has_score([2, 2, DiceCatalog.WILD_FACE]), "wild creates a scoring subset")
	_expect_true(not Rules.has_score([DiceCatalog.WILD_FACE, DiceCatalog.BLANK_FACE]), "wild and blank alone do not score")
	var special_rolls := [
		[DiceCatalog.WILD_FACE],
		[2, 2, DiceCatalog.WILD_FACE],
		[1, 2, 3, 4, DiceCatalog.WILD_FACE],
		[DiceCatalog.WILD_FACE, DiceCatalog.WILD_FACE],
		[6, DiceCatalog.WILD_FACE, DiceCatalog.WILD_FACE],
		[1, DiceCatalog.GREED_FACE],
		[5, DiceCatalog.DEBT_FACE],
		[2, 3, DiceCatalog.BLANK_FACE, DiceCatalog.GREED_FACE],
	]
	for special_roll in special_rolls:
		var typed_roll: Array[int] = []
		typed_roll.assign(special_roll)
		_expect_eq(Rules.has_score(typed_roll), not Rules.get_scoring_subsets(typed_roll).is_empty(), "special roll bust detection matches subsets: %s" % [special_roll])

func _test_exhaustive_bust_consistency() -> void:
	var mismatches := 0
	for encoded in range(46656):
		var value := encoded
		var roll: Array[int] = []
		for die in range(6):
			roll.append(value % 6 + 1)
			value /= 6
		var has_score := Rules.has_score(roll)
		var has_subset := not Rules.get_scoring_subsets(roll).is_empty()
		if has_score != has_subset:
			mismatches += 1
	_expect_eq(mismatches, 0, "all 46,656 rolls agree on bust detection")

func _test_session_flow() -> void:
	var game = Session.new(4000, 12345)
	game.phase = Session.Phase.AWAITING_SELECTION
	game.current_roll.assign([1, 2, 3, 4, 6, 2])
	_expect_true(game.apply_action(Action.set_selection([0])), "selection accepted")
	_expect_true(game.apply_action(Action.roll_again()), "roll again accepted")
	_expect_eq(game.turn_score, 100, "turn points accumulate")

	game.phase = Session.Phase.BUSTED
	game.turn_score = 0
	game.resolve_bust()
	_expect_eq(game.current_player, 1, "bust changes player")
	_expect_eq(game.dice_to_roll, 6, "new player gets six dice")

	game.phase = Session.Phase.AWAITING_SELECTION
	game.current_roll.assign([1, 2, 3, 4, 5, 6])
	game.selected_indices.assign([0, 1, 2, 3, 4, 5])
	game.turn_score = 500
	game.current_player = 0
	_expect_true(game.apply_action(Action.roll_again()), "hot dice reroll accepted")
	_expect_eq(game.turn_score, 2000, "hot dice preserves turn score")
	_expect_eq(game.current_roll.size(), 6, "hot dice immediately rolls six")

	game.phase = Session.Phase.AWAITING_SELECTION
	game.current_player = 0
	game.scores[0] = 3900
	game.turn_score = 0
	game.current_roll.assign([1])
	game.selected_indices.assign([0])
	_expect_true(game.apply_action(Action.bank()), "bank accepted")
	_expect_eq(game.winner, 0, "first target reach wins")
	_expect_eq(game.phase, Session.Phase.GAME_OVER, "game enters game over")

	var greed_game = Session.new(4000, 1, [["greed", "default", "default", "default", "default", "default"]])
	greed_game.phase = Session.Phase.AWAITING_SELECTION
	greed_game.current_roll.assign([1, DiceCatalog.GREED_FACE])
	greed_game.current_roll_types.assign(["default", "greed"])
	greed_game.selected_indices.assign([0])
	greed_game.must_roll_again = true
	_expect_eq(greed_game.get_selected_score(), 150, "greed face increases current selection by fifty percent")
	_expect_true(not greed_game.apply_action(Action.bank()), "greed face blocks banking")
	greed_game.rng.seed = _seed_for_roll(["greed"], [1])
	_expect_true(greed_game.apply_action(Action.roll_again()), "greed face allows required reroll")
	_expect_eq(greed_game.turn_score, 150, "greed bonus is added before required reroll")
	_expect_true(not greed_game.must_roll_again, "forced reroll clears when next roll has no greed face")

	var debt_game = Session.new(4000, 1, [["debt", "default", "default", "default", "default", "default"]])
	debt_game.scores[0] = 850
	debt_game.turn_score = 250
	debt_game.dice_to_roll = 2
	debt_game.rng.seed = _seed_for_roll(["debt", "default"], [DiceCatalog.DEBT_FACE, 1])
	_expect_true(debt_game.apply_action(Action.roll()), "debt effect roll accepted")
	_expect_eq(debt_game.current_roll, [DiceCatalog.DEBT_FACE, 1], "debt test rolled expected faces")
	_expect_eq(debt_game.scores[0], 550, "debt face removes three hundred total points")
	_expect_eq(debt_game.turn_score, 250, "debt face does not change current turn score")

	var debt_floor_game = Session.new(4000, 1, [["debt", "debt", "default", "default", "default", "default"]])
	debt_floor_game.scores[0] = 400
	debt_floor_game.turn_score = 250
	debt_floor_game.dice_to_roll = 3
	debt_floor_game.rng.seed = _seed_for_roll(["debt", "debt", "default"], [DiceCatalog.DEBT_FACE, DiceCatalog.DEBT_FACE, 1])
	_expect_true(debt_floor_game.apply_action(Action.roll()), "multiple debt effect roll accepted")
	_expect_eq(debt_floor_game.scores[0], 0, "multiple debt faces cannot reduce total score below zero")
	_expect_eq(debt_floor_game.turn_score, 250, "multiple debt faces leave current turn score unchanged")

func _test_ai() -> void:
	var ai = AI.new()
	var chosen := ai.choose_selection([1, 5, 2, 2, 3, 4])
	var values: Array[int] = []
	var roll: Array[int] = [1, 5, 2, 2, 3, 4]
	for index in chosen:
		values.append(roll[index])
	_expect_eq(Rules.score_selection(values), 500, "AI selects highest immediate score")
	_expect_true(ai.should_bank(350, 2, [0, 0], 4000), "AI banks at remaining-dice threshold")
	_expect_true(not ai.should_bank(349, 2, [0, 0], 4000), "AI continues below threshold")
	_expect_true(ai.should_bank(100, 5, [0, 3900], 4000), "AI banks a winning score")

func _expect_eq(actual, expected, label: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		printerr("%s: expected %s, got %s" % [label, expected, actual])

func _expect_true(value: bool, label: String) -> void:
	_expect_eq(value, true, label)

func _seed_for_roll(types: Array[String], expected_values: Array[int]) -> int:
	for candidate in range(100000):
		var candidate_rng := RandomNumberGenerator.new()
		candidate_rng.seed = candidate
		var matches := true
		for index in range(types.size()):
			if DiceCatalog.roll_value(types[index], candidate_rng) != expected_values[index]:
				matches = false
				break
		if matches:
			return candidate
	return -1
