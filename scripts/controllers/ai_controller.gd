class_name AIController
extends PlayerController

const BANK_THRESHOLDS := {
	1: 200,
	2: 350,
	3: 500,
	4: 650,
	5: 800,
	6: 900,
}

func choose_selection(roll: Array[int]) -> Array[int]:
	var best_indices: Array[int] = []
	var best_score := -1
	for subset in ScoringRules.get_scoring_subsets(roll):
		var score: int = subset["score"]
		var indices: Array[int] = subset["indices"]
		if score > best_score or (score == best_score and indices.size() < best_indices.size()):
			best_score = score
			best_indices = indices.duplicate()
	return best_indices

func should_bank(projected_turn_score: int, remaining_dice: int, scores: Array[int], target_score: int) -> bool:
	if scores[1] + projected_turn_score >= target_score:
		return true
	var effective_remaining := 6 if remaining_dice == 0 else remaining_dice
	var threshold: int = BANK_THRESHOLDS[effective_remaining]
	if scores[0] - scores[1] >= ceili(target_score * 0.25):
		threshold += 150
	if scores[0] >= target_score - 500:
		threshold += 200
	return projected_turn_score >= threshold

