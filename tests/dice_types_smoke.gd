extends SceneTree

const Session = preload("res://scripts/core/game_session.gd")
const Action = preload("res://scripts/core/game_action.gd")
const Protocol = preload("res://scripts/network/network_protocol.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog()
	_test_weighted_rolls()
	_test_session_type_flow()
	_test_snapshot_roundtrip()
	if failures == 0:
		print("PASS: %d dice-type checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d dice-type checks failed" % [failures, checks])
		quit(1)


func _test_catalog() -> void:
	_expect_eq(DiceCatalog.DEFINITIONS.size(), 5, "five public dice types")
	for definition in DiceCatalog.DEFINITIONS:
		_expect_true(not String(definition["name"]).is_empty(), "type has name")
		_expect_true(not String(definition["odds"]).is_empty(), "type exposes odds")
		_expect_true(String(definition["advantage"]).begins_with("优势："), "type exposes advantage")
		_expect_true(String(definition["tradeoff"]).begins_with("代价："), "type exposes tradeoff")
		_expect_eq((definition["weights"] as Array).size(), 6, "type has six face weights")
	var normalized := DiceCatalog.normalize_loadout(["lucky", "iron"])
	_expect_eq(normalized.size(), 6, "loadout fills to six")
	_expect_eq(normalized.slice(0, 2), ["lucky", "iron"], "chosen dice retained")
	_expect_eq(normalized.count(DiceCatalog.DEFAULT_ID), 4, "missing slots use defaults")
	_expect_eq(DiceCatalog.normalize_loadout(["royal", "royal", "royal", "royal", "royal", "royal", "royal"]).size(), 6, "loadout capped at six")
	_expect_eq(DiceCatalog.normalize_loadout(["unknown"]), DiceCatalog.default_loadout(), "unknown type ignored")
	var random_rng := RandomNumberGenerator.new()
	random_rng.seed = 314159
	var random_loadout := DiceCatalog.random_loadout(random_rng)
	_expect_eq(random_loadout.size(), DiceCatalog.MAX_DICE, "random loadout contains six dice")
	for type_id in random_loadout:
		_expect_true(DiceCatalog.is_valid_type(type_id), "random loadout only uses known dice")
	var repeated_rng := RandomNumberGenerator.new()
	repeated_rng.seed = 314159
	_expect_eq(DiceCatalog.random_loadout(repeated_rng), random_loadout, "random loadout is reproducible with a fixed seed")


func _test_weighted_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	var lucky_scoring_faces := 0
	var iron_middle_faces := 0
	var royal_sixes := 0
	for index in range(6000):
		var lucky := DiceCatalog.roll_value("lucky", rng)
		var iron := DiceCatalog.roll_value("iron", rng)
		var royal := DiceCatalog.roll_value("royal", rng)
		lucky_scoring_faces += int(lucky == 1 or lucky == 5)
		iron_middle_faces += int(iron == 3 or iron == 4)
		royal_sixes += int(royal == 6)
	_expect_true(lucky_scoring_faces > 2050, "lucky die favors one and five")
	_expect_true(iron_middle_faces > 3300, "iron die favors three and four")
	_expect_true(royal_sixes > 1600, "royal die favors six")


func _test_session_type_flow() -> void:
	var player_loadout := ["lucky", "iron", "royal", "reckless", "default", "lucky"]
	var opponent_loadout := ["royal", "royal", "royal", "royal", "royal", "royal"]
	var game := Session.new(4000, 1234, [player_loadout, opponent_loadout])
	_expect_true(game.apply_action(Action.roll()), "typed first roll accepted")
	_expect_eq(game.current_roll_types, player_loadout, "first roll uses current player's loadout")
	game.phase = Session.Phase.AWAITING_SELECTION
	game.current_roll.assign([1, 2, 1, 3, 4, 5])
	game.current_roll_types.assign(player_loadout)
	game.selected_indices.assign([0, 2])
	_expect_true(game.apply_action(Action.roll_again()), "typed partial reroll accepted")
	_expect_eq(game.held_dice_types, ["lucky", "royal"], "selected dice types move to held area")
	_expect_eq(game.current_roll_types, ["iron", "reckless", "default", "lucky"], "unselected dice retain their types")

	var hot_game := Session.new(4000, 4321, [player_loadout, opponent_loadout])
	hot_game.phase = Session.Phase.AWAITING_SELECTION
	hot_game.current_roll.assign([1, 2, 3, 4, 5, 6])
	hot_game.current_roll_types.assign(player_loadout)
	hot_game.selected_indices.assign([0, 1, 2, 3, 4, 5])
	_expect_true(hot_game.apply_action(Action.roll_again()), "typed hot dice accepted")
	_expect_eq(hot_game.current_roll_types, player_loadout, "hot dice restores player's full loadout")
	hot_game.phase = Session.Phase.BUSTED
	hot_game.resolve_bust()
	_expect_true(hot_game.apply_action(Action.roll()), "opponent typed roll accepted")
	_expect_eq(hot_game.current_roll_types, opponent_loadout, "next player uses independent loadout")


func _test_snapshot_roundtrip() -> void:
	var loadouts := [["lucky", "default", "default", "default", "default", "default"], ["iron", "royal", "reckless", "default", "default", "default"]]
	var game := Session.new(2500, 21, loadouts)
	game.current_roll.assign([1, 4])
	game.current_roll_types.assign(["lucky", "iron"])
	game.held_dice.assign([5])
	game.held_dice_types.assign(["royal"])
	var restored := Protocol.snapshot_from_dictionary(Protocol.snapshot_to_dictionary(game.get_snapshot()))
	_expect_eq(restored.player_dice_loadouts, loadouts, "snapshot preserves both loadouts")
	_expect_eq(restored.current_roll_types, ["lucky", "iron"], "snapshot preserves rolled types")
	_expect_eq(restored.held_dice_types, ["royal"], "snapshot preserves held types")
	var legacy := Protocol.snapshot_from_dictionary({"current_roll": [1, 5], "held_dice": [1]})
	_expect_eq(legacy.current_roll_types, ["default", "default"], "legacy roll receives default types")
	_expect_eq(legacy.held_dice_types, ["default"], "legacy held dice receive default types")


func _expect_true(value: bool, label: String) -> void:
	_expect_eq(value, true, label)


func _expect_eq(actual, expected, label: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		printerr("%s: expected %s, got %s" % [label, expected, actual])
