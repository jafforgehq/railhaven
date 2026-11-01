extends Node
## Rewarded ads. No ad SDK is linked yet (needs an AdMob account and app ids), so this build
## grants the reward after a short pause and says so. Replace _show() with the AdMob plugin's
## rewarded-ad call when it is added; callers stay the same.

signal ad_finished(placement: String, rewarded: bool)

const TEST_DELAY := 0.8


func rewarded(placement: String, on_reward: Callable) -> void:
	var ok := await _show(placement)
	ad_finished.emit(placement, ok)
	if ok:
		on_reward.call()


func _show(_placement: String) -> bool:
	Game.toast.emit("Test build: ad skipped, reward granted", "info")
	await get_tree().create_timer(TEST_DELAY).timeout
	return true
