class_name ScoringRules
extends RefCounted

const INVALID := -1
const LOW_STRAIGHT: Array[int] = [1, 2, 3, 4, 5]
const HIGH_STRAIGHT: Array[int] = [2, 3, 4, 5, 6]
const FULL_STRAIGHT: Array[int] = [1, 2, 3, 4, 5, 6]

static func score_selection(values: Array[int]) -> int:
	if values.is_empty():
		return INVALID
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for value in values:
		if value < 1 or value > 6:
			return INVALID
		counts[value] += 1
	return _score_counts(counts, {})

static func get_scoring_subsets(values: Array[int]) -> Array[Dictionary]:
	var subsets: Array[Dictionary] = []
	for mask in range(1, 1 << values.size()):
		var indices: Array[int] = []
		var selected_values: Array[int] = []
		for index in range(values.size()):
			if mask & (1 << index):
				indices.append(index)
				selected_values.append(values[index])
		var score := score_selection(selected_values)
		if score > 0:
			subsets.append({
				"indices": indices,
				"values": selected_values,
				"score": score,
			})
	return subsets

static func has_score(values: Array[int]) -> bool:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for value in values:
		if value == 1 or value == 5:
			return true
		if value >= 1 and value <= 6:
			counts[value] += 1
			if counts[value] >= 3:
				return true
	return false

static func _score_counts(counts: Array[int], memo: Dictionary) -> int:
	var total := 0
	for face in range(1, 7):
		total += counts[face]
	if total == 0:
		return 0

	var key := str(counts)
	if memo.has(key):
		return memo[key]

	var best := INVALID

	for single in [1, 5]:
		if counts[single] > 0:
			counts[single] -= 1
			var rest := _score_counts(counts, memo)
			counts[single] += 1
			if rest >= 0:
				best = maxi(best, rest + (100 if single == 1 else 50))

	for face in range(1, 7):
		var count := counts[face]
		for amount in range(3, count + 1):
			counts[face] -= amount
			var rest := _score_counts(counts, memo)
			counts[face] += amount
			if rest >= 0:
				var base := 1000 if face == 1 else face * 100
				best = maxi(best, rest + base * (1 << (amount - 3)))

	best = maxi(best, _score_straight(counts, FULL_STRAIGHT, 1500, memo))
	best = maxi(best, _score_straight(counts, LOW_STRAIGHT, 500, memo))
	best = maxi(best, _score_straight(counts, HIGH_STRAIGHT, 750, memo))

	memo[key] = best
	return best

static func _score_straight(counts: Array[int], sequence: Array[int], points: int, memo: Dictionary) -> int:
	for face in sequence:
		if counts[face] == 0:
			return INVALID
	for face in sequence:
		counts[face] -= 1
	var rest := _score_counts(counts, memo)
	for face in sequence:
		counts[face] += 1
	return INVALID if rest < 0 else rest + points

