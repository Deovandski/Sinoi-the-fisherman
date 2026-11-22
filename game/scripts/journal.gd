class_name Journal
extends RefCounted
## The fishing journal: one entry per fish species caught, kept in the save
## ("journal"). Decided by Deovandski (2026-11-22): the journal shows, for
## each fish caught, how many, the biggest catch, and the average payoff in
## pearls. Each entry also keeps the totals needed to update it, so the
## journal stays right even if the catch log is trimmed one day.
##
## Entry: {"caught", "pearls_total", "biggest_cm", "biggest_quality",
##         "best_quality", "first_caught_at", "last_caught_at"}


## Adds one catch (a catch-log entry) to `journal` in place.
static func record(journal: Dictionary, catch_entry: Dictionary) -> void:
	var id := str(catch_entry.get("fish", ""))
	if id.is_empty():
		return
	var when := str(catch_entry.get("caught_at", ""))
	var e: Dictionary = journal.get(id, {
		"caught": 0, "pearls_total": 0, "biggest_cm": 0.0, "biggest_quality": 0,
		"best_quality": 0, "first_caught_at": when, "last_caught_at": when,
	})
	var size := float(catch_entry.get("size_cm", 0.0))
	var quality := int(catch_entry.get("quality", 0))
	e.caught = int(e.caught) + 1
	e.pearls_total = int(e.pearls_total) + int(catch_entry.get("pearls", 0))
	if size > float(e.biggest_cm):
		e.biggest_cm = size
		e.biggest_quality = quality
	e.best_quality = maxi(int(e.best_quality), quality)
	if str(e.first_caught_at).is_empty():
		e.first_caught_at = when
	e.last_caught_at = when
	journal[id] = e


## Builds a journal from a whole catch log (used to upgrade older saves).
static func rebuild(catches: Array) -> Dictionary:
	var journal := {}
	for c in catches:
		if typeof(c) == TYPE_DICTIONARY:
			record(journal, c)
	return journal


## Average pearls per catch for one entry.
static func average_pearls(entry: Dictionary) -> float:
	var caught := int(entry.get("caught", 0))
	return float(entry.get("pearls_total", 0)) / caught if caught > 0 else 0.0
