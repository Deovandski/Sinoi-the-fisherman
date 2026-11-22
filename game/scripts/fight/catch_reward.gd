class_name CatchReward
extends RefCounted
## What a caught fish earns. Decided by Deovandski (2026-11-22): a streak of
## catches earns higher quality, bigger fish and bonus pearls. Accuracy over
## the fight also nudges quality. Numbers live in data/fish.json ("rewards").


## Rolls a catch of `fish` made with `streak` catches already in a row and
## `accuracy` (0..1) over the fight. Returns quality (tier index), quality_name,
## size_cm, pearls, base_pearls and bonus (the streak's pearl bonus, 0..1).
static func roll(fish: Dictionary, streak: int, accuracy: float, rng: RandomNumberGenerator, rewards := {}) -> Dictionary:
	if rewards.is_empty():
		rewards = FishCatalog.rewards()
	var names: Array = rewards.get("quality_names", ["Normal"])
	var multipliers: Array = rewards.get("quality_pearls", [1.0])
	var top := names.size() - 1

	var score := rng.randf()
	score += streak * float(rewards.get("quality_per_streak", 0.25))
	score += float(rewards.get("quality_accuracy", 0.5)) * clampf((accuracy - 0.5) / 0.5, 0.0, 1.0)
	var quality := clampi(floori(score), 0, top)

	# Higher streaks push the size roll toward the top of the range.
	var size_range: Array = fish.get("size_cm", [0, 0])
	var push := 1.0 + streak * float(rewards.get("size_per_streak", 0.3))
	var t := 1.0 - pow(1.0 - rng.randf(), push)
	var size_cm := snappedf(lerpf(float(size_range[0]), float(size_range[1]), t), 0.1)

	var pearl_range: Array = fish.get("pearls", [1, 1])
	var base := rng.randi_range(int(pearl_range[0]), int(pearl_range[1]))
	var multiplier := float(multipliers[mini(quality, multipliers.size() - 1)])
	var bonus := minf(streak * float(rewards.get("pearls_per_streak", 0.1)), float(rewards.get("pearls_streak_cap", 1.0)))
	var pearls := roundi(base * multiplier * (1.0 + bonus))

	return {"quality": quality, "quality_name": str(names[quality]), "size_cm": size_cm,
		"pearls": pearls, "base_pearls": base, "bonus": bonus}
