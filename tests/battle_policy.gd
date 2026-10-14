extends RefCounted
## Test-only policy. Every action is an ordinary equipped-card selection.
static func choose(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("status", "") != "active" or snapshot.get("paused", false):
		return {}
	for item in snapshot.get("pending", []):
		if item.kind == "cast":
			return {}
	var targets: Array = snapshot.get("enemies", [])
	var cards: Array = snapshot.get("cards", [])
	var target: Dictionary = {}
	for enemy in targets:
		if enemy.is_anchor:
			target = enemy
			break
	if target.is_empty():
		for kind in ["instrument", "observer", "tutorial", "guard", "elite", "boss"]:
			for enemy in targets:
				if enemy.kind == kind:
					target = enemy
					break
			if not target.is_empty():
				break
	if target.is_empty():
		return {}
	var imminent := false
	for enemy in targets:
		if enemy.kind in ["tutorial", "guard", "elite", "boss"] and float(enemy.duration) - float(enemy.charge) < 0.9:
			imminent = true
	if imminent and int(snapshot.shield) < 3 and (int(snapshot.hp) < 25 or int(snapshot.energy) >= 2):
		for card in cards:
			if card.playable and card.type in ["shield", "ember_shield", "heavy_shield"]:
				return {"card_id":card.id, "target_id":""}
	if not target.is_anchor:
		for card in cards:
			if card.playable and card.type == "charge" and int(snapshot.energy) <= 3:
				return {"card_id":card.id, "target_id":""}
	for type in ["fire", "ignite", "delay", "ember"]:
		for card in cards:
			if card.playable and card.type == type:
				if type == "delay":
					var occupied := false
					for effect in snapshot.pending:
						if effect.kind == "delay" and effect.target == target.id:
							occupied = true
					if occupied:
						continue
				return {"card_id":card.id, "target_id":target.id}
	for card in cards:
		if card.playable and card.type == "charge" and int(snapshot.energy) <= 3:
			return {"card_id":card.id, "target_id":""}
	return {}
