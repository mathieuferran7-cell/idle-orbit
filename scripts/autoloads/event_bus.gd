extends Node

# Resources
signal resource_changed(type: String, amount: float, total: float)

# Modules
signal module_purchased(module_id: String, count: int)
signal module_unlocked(module_id: String)

# Save
signal game_loaded()
signal game_saved()

# Mining
signal mining_tapped(tech_gained: float)

# Research
signal research_node_unlocked(node_id: String)

# Offline
signal offline_gains_ready(gains: Dictionary)

# Prestige
signal prestige_completed(orbits_gained: int)

# Events
signal event_triggered(event_data: Dictionary)
signal buff_started(buff_id: String, duration: float)
signal buff_ended(buff_id: String)

# Achievements
signal achievement_unlocked(ach_id: String, ach_data: Dictionary)

# Quests
signal quest_completed(quest_id: String)
signal quest_progress(quest_id: String, current: int, target: int)

# Last Stand result (waves survived for achievement/quest tracking)
signal last_stand_completed(waves_survived: int)

# Event completed (for achievement/quest tracking)
signal event_choice_made()

# Lifecycle
signal game_ready()
