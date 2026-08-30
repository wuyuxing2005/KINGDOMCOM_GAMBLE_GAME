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
	_test_face_distributions()
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
	_expect_true(not DiceCatalog.get_ids().has(DiceCatalog.DEFAULT_ID), "ordinary die hidden from special selection")
	for definition in DiceCatalog.DEFINITIONS:
		_expect_true(not String(definition["name"]).is_empty(), "type has name")
		_expect_true(not String(definition["odds"]).is_empty(), "type exposes odds")
		_expect_true(not String(definition["description"]).is_empty(), "type exposes a concise description")
		_expect_eq((definition["faces"] as Array).size(), 6, "type has six defined faces")
	var normalized := DiceCatalog.normalize_loadout(["wild", "gambler"])
	_expect_eq(normalized.size(), 6, "loadout fills to six")
	_expect_eq(normalized.slice(0, 2), ["wild", "gambler"], "chosen dice retained")
	_expect_eq(normalized.count(DiceCatalog.DEFAULT_ID), 4, "missing slots use defaults")
	_expect_eq(DiceCatalog.normalize_loadout(["debt", "debt", "debt", "debt", "debt", "debt", "debt"]).size(), 6, "loadout capped at six")
	_expect_eq(DiceCatalog.normalize_loadout(["unknown"]), DiceCatalog.default_loadout(), "unknown type ignored")
	_expect_eq(DiceCatalog.get_definition("wild")["faces"], [2, 3, 4, 5, 6, DiceCatalog.WILD_FACE], "wild die faces")
	_expect_eq(DiceCatalog.get_definition("gambler")["faces"], [1, 1, 5, 5, DiceCatalog.BLANK_FACE, DiceCatalog.BLANK_FACE], "gambler die faces")
	_expect_eq(DiceCatalog.get_definition("sequence")["faces"], [2, 3, 3, 4, 4, 5], "sequence die faces")
	_expect_eq(DiceCatalog.get_definition("greed")["faces"], [1, 3, 4, 5, 6, DiceCatalog.GREED_FACE], "greed die faces")
	_expect_eq(DiceCatalog.get_definition("debt")["faces"], [1, 1, 5, 5, 6, DiceCatalog.DEBT_FACE], "debt die faces")
	var random_rng := RandomNumberGenerator.new()
	random_rng.seed = 314159
	var random_loadout := DiceCatalog.random_loadout(random_rng)
	_expect_eq(random_loadout.size(), DiceCatalog.MAX_DICE, "random loadout contains six dice")
	for type_id in random_loadout:
		_expect_true(DiceCatalog.get_ids().has(type_id), "random loadout only uses selectable special dice")
	var repeated_rng := RandomNumberGenerator.new()
	repeated_rng.seed = 314159
	_expect_eq(DiceCatalog.random_loadout(repeated_rng), random_loadout, "random loadout is reproducible with a fixed seed")


func _test_face_distributions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	var gambler_scoring_faces := 0
	var sequence_middle_faces := 0
	var wild_faces := 0
	var greed_faces := 0
	var debt_faces := 0
	for index in range(6000):
		var gambler := DiceCatalog.roll_value("gambler", rng)
		var sequence := DiceCatalog.roll_value("sequence", rng)
		gambler_scoring_faces += int(gambler == 1 or gambler == 5)
		sequence_middle_faces += int(sequence == 3 or sequence == 4)
		wild_faces += int(DiceCatalog.roll_value("wild", rng) == DiceCatalog.WILD_FACE)
		greed_faces += int(DiceCatalog.roll_value("greed", rng) == DiceCatalog.GREED_FACE)
		debt_faces += int(DiceCatalog.roll_value("debt", rng) == DiceCatalog.DEBT_FACE)
	_expect_true(gambler_scoring_faces > 3800, "gambler die scores on about four faces")
	_expect_true(sequence_middle_faces > 3800, "sequence die has four middle faces")
	_expect_true(wild_faces > 850 and wild_faces < 1150, "wild face appears on one of six sides")
	_expect_true(greed_faces > 850 and greed_faces < 1150, "greed face appears on one of six sides")
	_expect_true(debt_faces > 850 and debt_faces < 1150, "debt face appears on one of six sides")


func _test_session_type_flow() -> void:
	var player_loadout := ["wild", "gambler", "sequence", "greed", "debt", "wild"]
	var opponent_loadout := ["debt", "debt", "debt", "debt", "debt", "debt"]
	var game := Session.new(4000, 1234, [player_loadout, opponent_loadout])
	_expect_true(game.apply_action(Action.roll()), "typed first roll accepted")
	_expect_eq(game.current_roll_types, player_loadout, "first roll uses current player's loadout")
	game.phase = Session.Phase.AWAITING_SELECTION
	game.current_roll.assign([1, 2, 1, 3, 4, 5])
	game.current_roll_types.assign(player_loadout)
	game.selected_indices.assign([0, 2])
	_expect_true(game.apply_action(Action.roll_again()), "typed partial reroll accepted")
	_expect_eq(game.held_dice_types, ["wild", "sequence"], "selected dice types move to held area")
	_expect_eq(game.current_roll_types, ["gambler", "greed", "debt", "wild"], "unselected dice retain their types")

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
	var loadouts := [["wild", "default", "default", "default", "default", "default"], ["gambler", "sequence", "greed", "default", "default", "default"]]
	var game := Session.new(2500, 21, loadouts)
	game.current_roll.assign([1, 4])
	game.current_roll_types.assign(["wild", "gambler"])
	game.held_dice.assign([5])
	game.held_dice_types.assign(["sequence"])
	game.must_roll_again = true
	var restored := Protocol.snapshot_from_dictionary(Protocol.snapshot_to_dictionary(game.get_snapshot()))
	_expect_eq(restored.player_dice_loadouts, loadouts, "snapshot preserves both loadouts")
	_expect_eq(restored.current_roll_types, ["wild", "gambler"], "snapshot preserves rolled types")
	_expect_eq(restored.held_dice_types, ["sequence"], "snapshot preserves held types")
	_expect_true(restored.must_roll_again, "snapshot preserves forced reroll state")
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
