class_name ScoringRules
extends RefCounted

const INVALID := -1
const LOW_STRAIGHT: Array[int] = [1, 2, 3, 4, 5]
const HIGH_STRAIGHT: Array[int] = [2, 3, 4, 5, 6]
const FULL_STRAIGHT: Array[int] = [1, 2, 3, 4, 5, 6]


static func score_selection(values: Array[int]) -> int:
	if values.is_empty():
		return INVALID
	var normal_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var wild_count := 0
	for value in values:
		if value >= 1 and value <= 6:
			normal_counts[value] += 1
		elif value == DiceCatalog.WILD_FACE:
			wild_count += 1
		else:
			return INVALID
	if wild_count == 0:
		return _score_token_counts(normal_counts, [0, 0, 0, 0, 0, 0, 0], {})
	return _score_wild_distributions(normal_counts, wild_count, 1, [0, 0, 0, 0, 0, 0, 0])


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
	var wild_count := 0
	for value in values:
		if value == 1 or value == 5:
			return true
		if value >= 1 and value <= 6:
			counts[value] += 1
		elif value == DiceCatalog.WILD_FACE:
			wild_count += 1
	for face in range(1, 7):
		if counts[face] + wild_count >= 3:
			return true
	for sequence in [LOW_STRAIGHT, HIGH_STRAIGHT, FULL_STRAIGHT]:
		var missing := 0
		for face in sequence:
			missing += int(counts[face] == 0)
		if missing <= wild_count:
			return true
	return false


static func _score_wild_distributions(normal_counts: Array[int], remaining: int, face: int, wild_counts: Array[int]) -> int:
	if face == 6:
		wild_counts[face] = remaining
		var score := _score_token_counts(normal_counts.duplicate(), wild_counts.duplicate(), {})
		wild_counts[face] = 0
		return score
	var best := INVALID
	for amount in range(remaining + 1):
		wild_counts[face] = amount
		best = maxi(best, _score_wild_distributions(normal_counts, remaining - amount, face + 1, wild_counts))
	wild_counts[face] = 0
	return best


static func _score_token_counts(normal_counts: Array[int], wild_counts: Array[int], memo: Dictionary) -> int:
	var total := 0
	for face in range(1, 7):
		total += normal_counts[face] + wild_counts[face]
	if total == 0:
		return 0

	var key := "%s|%s" % [normal_counts, wild_counts]
	if memo.has(key):
		return memo[key]

	var best := INVALID
	for single in [1, 5]:
		if normal_counts[single] > 0:
			normal_counts[single] -= 1
			var rest := _score_token_counts(normal_counts, wild_counts, memo)
			normal_counts[single] += 1
			if rest >= 0:
				best = maxi(best, rest + (100 if single == 1 else 50))

	for face in range(1, 7):
		var normal_available := normal_counts[face]
		var wild_available := wild_counts[face]
		var available := normal_available + wild_available
		for amount in range(3, available + 1):
			var minimum_wild := maxi(0, amount - normal_available)
			var maximum_wild := mini(amount, wild_available)
			for wild_used in range(minimum_wild, maximum_wild + 1):
				var normal_used := amount - wild_used
				normal_counts[face] -= normal_used
				wild_counts[face] -= wild_used
				var rest := _score_token_counts(normal_counts, wild_counts, memo)
				normal_counts[face] += normal_used
				wild_counts[face] += wild_used
				if rest >= 0:
					var base := 1000 if face == 1 else face * 100
					best = maxi(best, rest + base * (1 << (amount - 3)))

	best = maxi(best, _score_straight_tokens(normal_counts, wild_counts, FULL_STRAIGHT, 1500, memo, 0))
	best = maxi(best, _score_straight_tokens(normal_counts, wild_counts, LOW_STRAIGHT, 500, memo, 0))
	best = maxi(best, _score_straight_tokens(normal_counts, wild_counts, HIGH_STRAIGHT, 750, memo, 0))
	memo[key] = best
	return best


static func _score_straight_tokens(normal_counts: Array[int], wild_counts: Array[int], sequence: Array[int], points: int, memo: Dictionary, position: int) -> int:
	if position == sequence.size():
		var rest := _score_token_counts(normal_counts, wild_counts, memo)
		return INVALID if rest < 0 else rest + points
	var face := sequence[position]
	var best := INVALID
	if normal_counts[face] > 0:
		normal_counts[face] -= 1
		best = maxi(best, _score_straight_tokens(normal_counts, wild_counts, sequence, points, memo, position + 1))
		normal_counts[face] += 1
	if wild_counts[face] > 0:
		wild_counts[face] -= 1
		best = maxi(best, _score_straight_tokens(normal_counts, wild_counts, sequence, points, memo, position + 1))
		wild_counts[face] += 1
	return best
