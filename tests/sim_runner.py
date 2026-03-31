#!/usr/bin/env python3
"""
sim_runner.py — Idle Orbit full progression simulator
Simulates an optimal active player across multiple prestige runs.

Usage:
  python tests/sim_runner.py              # single run, 60min
  python tests/sim_runner.py --prestige   # multi-prestige simulation
"""

import json
import math
import os
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")

# ── Data loading ─────────────────────────────────────────────────────────────

def read_json(rel_path):
    with open(os.path.join(PROJECT_ROOT, rel_path), encoding="utf-8") as f:
        return json.load(f)

# ── Research engine ──────────────────────────────────────────────────────────

class Research:
    def __init__(self, data):
        self.data = data
        self.levels = {nid: 0 for nid in data}

    def reset(self):
        self.levels = {nid: 0 for nid in self.data}

    def get_level(self, nid):
        return self.levels.get(nid, 0)

    def is_unlocked(self, nid):
        return self.get_level(nid) >= 1

    def is_maxed(self, nid):
        return self.get_level(nid) >= self.data[nid]["max_level"]

    def all_maxed(self):
        return all(self.is_maxed(nid) for nid in self.data)

    def get_next_cost(self, nid, research_discount=1.0):
        node = self.data[nid]
        level = self.get_level(nid)
        cost_values = node.get("cost_values", [])
        if level < len(cost_values):
            return float(cost_values[level]) * research_discount
        return node["base_cost"] * math.pow(node["cost_growth"], level) * research_discount

    def can_upgrade(self, nid, tech, research_discount=1.0):
        if self.is_maxed(nid):
            return False
        for req in self.data[nid].get("requires", []):
            if not self.is_unlocked(req):
                return False
        return tech >= self.get_next_cost(nid, research_discount)

    def upgrade(self, nid, research_discount=1.0):
        cost = self.get_next_cost(nid, research_discount)
        self.levels[nid] += 1
        return cost

    def get_energy_multiplier(self):
        total = 0.0
        for nid, node in self.data.items():
            if node.get("effect", {}).get("type") == "energy_multiplier":
                total += self.get_level(nid) * node.get("effect_per_level", 0)
        return 1.0 + total

    def get_cost_multiplier(self):
        total = 0.0
        for nid, node in self.data.items():
            if node.get("effect", {}).get("type") == "module_cost_multiplier":
                total += self.get_level(nid) * node.get("effect_per_level", 0)
        return max(0.1, 1.0 - total)

    def get_tech_tap_multiplier(self):
        total = 0.0
        for nid, node in self.data.items():
            if node.get("effect", {}).get("type") == "tech_tap_multiplier":
                total += self.get_level(nid) * node.get("effect_per_level", 0)
        return 1.0 + total

    def get_auto_tap_interval(self):
        best = 0.0
        for nid, node in self.data.items():
            lvl = self.get_level(nid)
            if lvl == 0:
                continue
            if node.get("effect", {}).get("type") == "auto_tap_interval":
                vals = node.get("effect_values", [])
                if lvl - 1 < len(vals):
                    interval = float(vals[lvl - 1])
                    if best == 0.0 or interval < best:
                        best = interval
        return best

    def summary(self):
        parts = []
        for nid in self.data:
            lvl = self.get_level(nid)
            if lvl > 0:
                parts.append(f"{nid[:12]}:{lvl}")
        return " ".join(parts) if parts else "-"

# ── Prestige engine ──────────────────────────────────────────────────────────

PRESTIGE_TALENTS = {
    # Tier 1 — cheap, impactful
    "energy_plus":    {"name": "Energie+",     "effect": "energy_mult",     "per_level": 0.15, "cost": 5,   "max": 5},
    "tech_plus":      {"name": "Tech+",        "effect": "tech_tap_mult",   "per_level": 0.15, "cost": 5,   "max": 5},
    "start_plus":     {"name": "Depart+",      "effect": "starting_energy", "per_level": 30.0, "cost": 4,   "max": 5},
    # Tier 2 — mid cost
    "research_minus": {"name": "Recherche-",   "effect": "research_disc",   "per_level": 0.10, "cost": 12,  "max": 5},
    "speed_plus":     {"name": "Vitesse+",     "effect": "global_speed",    "per_level": 0.08, "cost": 15,  "max": 5},
    "auto_start":     {"name": "Drone Init",   "effect": "auto_tap_start",  "per_level": 1.0,  "cost": 20,  "max": 1},
    # Tier 3 — expensive, powerful
    "energy_plus2":   {"name": "Energie++",    "effect": "energy_mult",     "per_level": 0.25, "cost": 30,  "max": 3},
    "offline_plus":   {"name": "Offline+",     "effect": "offline_mult",    "per_level": 0.20, "cost": 25,  "max": 3},
    "module_discount":{"name": "Modules-",     "effect": "module_disc",     "per_level": 0.08, "cost": 20,  "max": 5},
    # Tier 4 — endgame
    "orbit_bonus":    {"name": "Orbit+",       "effect": "orbit_mult",      "per_level": 0.15, "cost": 50,  "max": 3},
    "mega_speed":     {"name": "Warp",         "effect": "global_speed",    "per_level": 0.15, "cost": 80,  "max": 2},
    # Tier 5 — deep endgame (orbit sink)
    "module_cost_reduction": {"name": "Ingenierie", "effect": "module_disc", "per_level": 0.06, "cost": 500, "max": 5},
    "energy_plus3":   {"name": "Energie+++",   "effect": "energy_mult",     "per_level": 0.30, "cost": 800, "max": 3},
    "prestige_accelerator": {"name": "Accelerateur", "effect": "threshold_disc", "per_level": 0.10, "cost": 1000, "max": 3},
    "deep_mining":    {"name": "Forage Profond", "effect": "tech_tap_mult", "per_level": 0.20, "cost": 1500, "max": 3},
}

# Priority: cheap first, then scaling, then endgame, then tier 5
TALENT_PRIORITY = [
    "energy_plus", "tech_plus", "start_plus",
    "research_minus", "speed_plus", "auto_start",
    "energy_plus2", "module_discount", "offline_plus",
    "orbit_bonus", "mega_speed",
    "module_cost_reduction", "energy_plus3", "prestige_accelerator", "deep_mining",
]

class Prestige:
    def __init__(self):
        self.total_orbits = 0
        self.prestige_count = 0
        self.talents = {tid: 0 for tid in PRESTIGE_TALENTS}

    def get_prestige_threshold(self):
        """Energy totale requise pour prestige. Croissant à chaque cycle."""
        base = 500_000
        accel = self.talents.get("prestige_accelerator", 0) * PRESTIGE_TALENTS["prestige_accelerator"]["per_level"]
        reduction = max(0.3, 1.0 - accel)
        return base * math.pow(3.0, self.prestige_count) * reduction

    def calculate_orbits(self, total_energy_produced):
        base = int(math.floor(math.sqrt(total_energy_produced / 1000.0)))
        return int(base * self.get_orbit_multiplier())

    def add_orbits(self, amount):
        self.total_orbits += amount

    def get_available_orbits(self):
        spent = sum(
            self.talents[tid] * PRESTIGE_TALENTS[tid]["cost"]
            for tid in self.talents
        )
        return self.total_orbits - spent

    def auto_allocate(self):
        """Greedy allocation in priority order."""
        while True:
            bought = False
            for tid in TALENT_PRIORITY:
                talent = PRESTIGE_TALENTS[tid]
                if self.talents[tid] < talent["max"] and self.get_available_orbits() >= talent["cost"]:
                    self.talents[tid] += 1
                    bought = True
                    break
            if not bought:
                break

    def get_energy_mult(self):
        total = self.talents.get("energy_plus", 0) * PRESTIGE_TALENTS["energy_plus"]["per_level"]
        total += self.talents.get("energy_plus2", 0) * PRESTIGE_TALENTS["energy_plus2"]["per_level"]
        total += self.talents.get("energy_plus3", 0) * PRESTIGE_TALENTS["energy_plus3"]["per_level"]
        return 1.0 + total

    def get_tech_tap_mult(self):
        total = self.talents.get("tech_plus", 0) * PRESTIGE_TALENTS["tech_plus"]["per_level"]
        total += self.talents.get("deep_mining", 0) * PRESTIGE_TALENTS["deep_mining"]["per_level"]
        return 1.0 + total

    def get_starting_energy(self, base):
        return base + self.talents.get("start_plus", 0) * PRESTIGE_TALENTS["start_plus"]["per_level"]

    def get_global_speed(self):
        total = self.talents.get("speed_plus", 0) * PRESTIGE_TALENTS["speed_plus"]["per_level"]
        total += self.talents.get("mega_speed", 0) * PRESTIGE_TALENTS["mega_speed"]["per_level"]
        return 1.0 + total

    def get_research_discount(self):
        total = self.talents.get("research_minus", 0) * PRESTIGE_TALENTS["research_minus"]["per_level"]
        return max(0.1, 1.0 - total)

    def get_module_discount(self):
        total = self.talents.get("module_discount", 0) * PRESTIGE_TALENTS["module_discount"]["per_level"]
        total += self.talents.get("module_cost_reduction", 0) * PRESTIGE_TALENTS["module_cost_reduction"]["per_level"]
        return max(0.1, 1.0 - total)

    def get_orbit_multiplier(self):
        return 1.0 + self.talents.get("orbit_bonus", 0) * PRESTIGE_TALENTS["orbit_bonus"]["per_level"]

    def has_auto_start(self):
        return self.talents.get("auto_start", 0) >= 1

    def summary(self):
        parts = [f"{tid}:{self.talents[tid]}" for tid in self.talents if self.talents[tid] > 0]
        return " ".join(parts) if parts else "none"

# ── Module helpers ───────────────────────────────────────────────────────────

def module_cost(modules, mid, counts, cost_mult):
    mod = modules[mid]
    base = mod["base_cost"]
    growth = mod.get("cost_growth", 1.15)
    return base * math.pow(growth, counts.get(mid, 0)) * cost_mult

def module_unlocked(modules, mid, counts):
    cond = modules[mid].get("unlock_condition")
    if not cond:
        return True
    return counts.get(cond["module"], 0) >= cond["count"]

def production(modules, counts, resource, energy_mult):
    total = 0.0
    for mid, mod in modules.items():
        if mod.get("resource") == resource:
            total += mod["base_production"] * counts.get(mid, 0)
    if resource == "energy":
        total *= energy_mult
    return total

RESEARCH_PRIORITY = [
    "auto_tap", "auto_tap_upgrade", "nebula_boost",
    "tech_boost", "module_discount", "offline_boost",
]

# ── Achievement tracking ────────────────────────────────────────────────────

class AchievementTracker:
    def __init__(self, data):
        self.data = data
        self.unlocked = {}
        self.stats = {
            "total_taps": 0,
            "total_modules_bought": 0,
            "total_research_bought": 0,
            "total_events_completed": 0,
            "last_stand_best_wave": 0,
            "cumulative_energy": 0.0,
        }
        self.unlock_log = []

    def on_tap(self):
        self.stats["total_taps"] += 1

    def on_module_bought(self):
        self.stats["total_modules_bought"] += 1

    def on_research_bought(self):
        self.stats["total_research_bought"] += 1

    def on_energy_produced(self, amount):
        self.stats["cumulative_energy"] += amount

    def on_last_stand(self, waves):
        self.stats["last_stand_best_wave"] = max(self.stats["last_stand_best_wave"], waves)

    def check_all(self, time, counts, modules, research, prestige):
        for ach_id, ach in self.data.items():
            if ach_id in self.unlocked:
                continue
            if self._check(ach_id, ach, counts, modules, research, prestige):
                self.unlocked[ach_id] = True
                reward = ach.get("reward", {})
                rtype = reward.get("type", "")
                amount = reward.get("amount", 0)
                self.unlock_log.append((time, ach_id, ach.get("name", ""), f"{rtype}:{amount}"))

    def _check(self, ach_id, ach, counts, modules, research, prestige):
        cond = ach.get("condition", {})
        ctype = cond.get("type", "")
        if ctype == "module_count":
            return counts.get(cond.get("module", ""), 0) >= cond.get("count", 1)
        elif ctype == "total_modules":
            return sum(counts.values()) >= cond.get("count", 1)
        elif ctype == "total_taps":
            return self.stats["total_taps"] >= cond.get("count", 1)
        elif ctype == "total_energy":
            return self.stats["cumulative_energy"] >= cond.get("amount", 0)
        elif ctype == "prestige_count":
            return prestige.prestige_count >= cond.get("count", 1)
        elif ctype == "research_count":
            return self.stats["total_research_bought"] >= cond.get("count", 1)
        elif ctype == "research_all_maxed":
            return research.all_maxed()
        elif ctype == "module_unlocked":
            return module_unlocked(modules, cond.get("module", ""), counts)
        elif ctype == "total_orbits":
            return prestige.total_orbits >= cond.get("count", 1)
        elif ctype == "talent_count":
            return sum(prestige.talents.values()) >= cond.get("count", 1)
        elif ctype == "all_talents":
            return all(
                prestige.talents[tid] >= PRESTIGE_TALENTS[tid]["max"]
                for tid in prestige.talents
            )
        elif ctype == "last_stand_waves":
            return self.stats["last_stand_best_wave"] >= cond.get("count", 1)
        elif ctype == "event_count":
            return self.stats["total_events_completed"] >= cond.get("count", 1)
        return False

# ── Single run simulation ────────────────────────────────────────────────────

def run_single(balance, modules, research_data, prestige, sim_duration=7200, tick=0.25, taps_per_second=4.0, energy_target=None, ach_tracker=None):
    """Run a single prestige cycle. Stops when energy_target reached or sim_duration exceeded."""

    starting_energy = prestige.get_starting_energy(balance.get("starting_energy", 10.0))
    energy = starting_energy
    tech = 0.0
    counts = {mid: 0 for mid in modules}
    research = Research(research_data)
    tech_per_tap = balance.get("mining_tech_per_tap", 1.0)
    global_speed = prestige.get_global_speed()
    research_discount = prestige.get_research_discount()
    prestige_energy_mult = prestige.get_energy_mult()
    prestige_tech_mult = prestige.get_tech_tap_mult()
    prestige_module_disc = prestige.get_module_discount()

    # Auto-start: begin with auto_tap lv1 already unlocked
    if prestige.has_auto_start():
        research.levels["auto_tap"] = max(research.levels.get("auto_tap", 0), 1)

    total_energy_produced = 0.0
    t = 0.0
    auto_tap_accum = 0.0
    all_research_done_at = None
    events = []

    while t <= sim_duration:
        # Production (scaled by global speed)
        e_mult = research.get_energy_multiplier() * prestige_energy_mult
        cost_mult = research.get_cost_multiplier() * prestige_module_disc
        e_rate = production(modules, counts, "energy", e_mult) * global_speed
        t_rate = production(modules, counts, "tech", e_mult) * global_speed

        energy_tick = e_rate * tick
        energy += energy_tick
        tech += t_rate * tick
        total_energy_produced += energy_tick

        # Tap bonus from tech modules
        total_tech_modules = sum(
            counts.get(mid, 0) for mid, mod in modules.items()
            if mod.get("resource") == "tech"
        )
        module_tap_bonus = 1.0 + 0.10 * total_tech_modules

        # Manual taps
        taps_this_tick = int(taps_per_second * tick)
        tap_mult = research.get_tech_tap_multiplier() * module_tap_bonus * prestige_tech_mult
        tech += taps_this_tick * tech_per_tap * tap_mult
        if ach_tracker:
            for _ in range(taps_this_tick):
                ach_tracker.on_tap()
            ach_tracker.on_energy_produced(energy_tick)

        # Auto-tap
        auto_interval = research.get_auto_tap_interval()
        if auto_interval > 0:
            auto_tap_accum += tick
            while auto_tap_accum >= auto_interval:
                auto_tap_accum -= auto_interval
                tech += tech_per_tap * tap_mult

        # Research buy
        for nid in RESEARCH_PRIORITY:
            if nid in research.data and research.can_upgrade(nid, tech, research_discount):
                cost = research.upgrade(nid, research_discount)
                tech -= cost
                events.append((t, f"RESEARCH:{nid}:lv{research.get_level(nid)}"))
                if ach_tracker:
                    ach_tracker.on_research_bought()
                break

        # Module buy (cheapest greedy)
        best_id, best_cost = None, float("inf")
        for mid in modules:
            if not module_unlocked(modules, mid, counts):
                continue
            c = module_cost(modules, mid, counts, cost_mult)
            if c <= energy and c < best_cost:
                best_cost = c
                best_id = mid
        if best_id:
            energy -= best_cost
            counts[best_id] += 1
            if ach_tracker:
                ach_tracker.on_module_bought()

        # Check all research done
        if all_research_done_at is None and research.all_maxed():
            all_research_done_at = t
            events.append((t, "ALL_RESEARCH_MAXED"))

        # Achievement check (every 30s to avoid perf hit)
        if ach_tracker and int(t * 4) % 120 == 0:
            ach_tracker.check_all(t, counts, modules, research, prestige)

        # Stop if energy target reached
        if energy_target and total_energy_produced >= energy_target:
            events.append((t, f"TARGET_REACHED:{total_energy_produced:.0f}"))
            break

        t += tick

    # Final achievement check
    if ach_tracker:
        ach_tracker.check_all(t, counts, modules, research, prestige)

    return total_energy_produced, all_research_done_at, events, e_rate, t

def format_time(seconds):
    if seconds is None:
        return "N/A"
    m = int(seconds) // 60
    s = int(seconds) % 60
    return f"{m:02d}:{s:02d}"

# ── Multi-prestige simulation ────────────────────────────────────────────────

def run_prestige_sim(num_runs=5, run_duration=2400):
    balance = read_json("data/balance.json")
    modules = read_json("data/modules.json")
    research_data = read_json("data/research.json")
    prestige = Prestige()

    print("=" * 90)
    print("IDLE ORBIT -- PRESTIGE LOOP SIMULATOR")
    print(f"{num_runs} runs, {run_duration//60}min each, 4 taps/s, auto-buy, greedy talent allocation")
    print("=" * 90)
    print()
    print(f"{'RUN':<5} {'TARGET':>12} {'DURATION':>10} {'ORBITS':>8} {'TOTAL':>8} {'E.PROD':>12} {'E/s.END':>10}  TALENTS")
    print("-" * 110)

    for run_idx in range(1, num_runs + 1):
        prestige.auto_allocate()
        threshold = prestige.get_prestige_threshold()

        total_e, res_done_at, events, final_e_rate, run_time = run_single(
            balance, modules, research_data, prestige,
            sim_duration=14400, tick=0.25, taps_per_second=4.0,
            energy_target=threshold
        )

        orbits_gained = prestige.calculate_orbits(total_e)
        prestige.add_orbits(orbits_gained)
        prestige.prestige_count += 1

        duration_str = format_time(run_time)
        target_str = f"{threshold:,.0f}"
        print(f"  {run_idx:<3} {target_str:>12} {duration_str:>9}  +{orbits_gained:>5}  {prestige.total_orbits:>7}  {total_e:>11,.0f}  {final_e_rate:>9,.0f}/s  {prestige.summary()}")

        key_events = [e for e in events if "ALL_RESEARCH" in e[1] or "TARGET" in e[1]]
        for evt_time, evt_text in key_events:
            print(f"        [{format_time(evt_time)}] {evt_text}")

    # Final talent state
    print()
    print("=" * 90)
    print("FINAL PRESTIGE STATE")
    print("=" * 90)
    print(f"  Total Orbits: {prestige.total_orbits}")
    print(f"  Available:    {prestige.get_available_orbits()}")
    print(f"  Talents:      {prestige.summary()}")
    print()
    print("  Bonuses:")
    print(f"    Energy production: x{prestige.get_energy_mult():.2f}")
    print(f"    Tech/tap:          x{prestige.get_tech_tap_mult():.2f}")
    print(f"    Starting energy:   {prestige.get_starting_energy(balance.get('starting_energy', 10.0)):.0f}")
    print(f"    Global speed:      x{prestige.get_global_speed():.2f}")
    print(f"    Research discount:  {(1-prestige.get_research_discount())*100:.0f}%")

# ── Single run mode (legacy) ─────────────────────────────────────────────────

def run_single_mode():
    balance = read_json("data/balance.json")
    modules = read_json("data/modules.json")
    research_data = read_json("data/research.json")
    prestige = Prestige()

    total_e, res_done_at, events, final_e_rate, run_time = run_single(
        balance, modules, research_data, prestige,
        sim_duration=3600, tick=0.25, taps_per_second=4.0
    )

    print("=" * 80)
    print("IDLE ORBIT -- SINGLE RUN (no prestige)")
    print("=" * 80)
    print()
    print(f"  Total energy produced: {total_e:,.0f}")
    print(f"  All research maxed at: {format_time(res_done_at)}")
    print(f"  Final energy rate:     {final_e_rate:,.0f}/s")
    print(f"  Orbits if prestige:    {int(math.floor(math.sqrt(total_e / 1000)))}")
    print()
    print("  EVENTS:")
    for evt_time, evt_text in events:
        print(f"    [{format_time(evt_time)}] {evt_text}")

# ── Main ─────────────────────────────────────────────────────────────────────

def run_achievements_sim(num_runs=8):
    """Simulate multi-prestige with achievement tracking."""
    balance = read_json("data/balance.json")
    modules = read_json("data/modules.json")
    research_data = read_json("data/research.json")
    achievements_data = read_json("data/achievements.json")
    prestige = Prestige()
    tracker = AchievementTracker(achievements_data)

    print("=" * 100)
    print("IDLE ORBIT -- ACHIEVEMENT PROGRESSION SIMULATOR")
    print(f"{num_runs} prestige runs, tracking all {len(achievements_data)} achievements")
    print("=" * 100)

    for run_idx in range(1, num_runs + 1):
        prestige.auto_allocate()
        threshold = prestige.get_prestige_threshold()

        # Simulate a last stand result (waves = prestige_count * 2 + 3, capped at 10)
        simulated_waves = min(prestige.prestige_count * 2 + 3, 10)
        tracker.on_last_stand(simulated_waves)

        total_e, res_done_at, events, final_e_rate, run_time = run_single(
            balance, modules, research_data, prestige,
            sim_duration=14400, tick=0.25, taps_per_second=4.0,
            energy_target=threshold, ach_tracker=tracker
        )

        orbits_gained = prestige.calculate_orbits(total_e)
        prestige.add_orbits(orbits_gained)
        prestige.prestige_count += 1

        # Check after prestige
        tracker.check_all(run_time, {mid: 0 for mid in modules}, modules,
                          Research(research_data), prestige)

        print(f"\n  Run {run_idx}: {format_time(run_time)} | +{orbits_gained} orbits | Total: {prestige.total_orbits}")

    print()
    print("=" * 100)
    print("ACHIEVEMENT UNLOCK TIMELINE")
    print("=" * 100)
    print(f"  {'TIME':>8}  {'ID':<25} {'NAME':<25} REWARD")
    print("-" * 90)
    for t, ach_id, name, reward in tracker.unlock_log:
        print(f"  {format_time(t):>8}  {ach_id:<25} {name:<25} {reward}")

    print(f"\n  Unlocked: {len(tracker.unlocked)} / {len(achievements_data)}")
    not_unlocked = [aid for aid in achievements_data if aid not in tracker.unlocked]
    if not_unlocked:
        print(f"  Not unlocked: {', '.join(not_unlocked)}")

    print(f"\n  Stats:")
    for k, v in tracker.stats.items():
        print(f"    {k}: {v:,.0f}" if isinstance(v, float) else f"    {k}: {v:,}")

def main():
    if "--prestige" in sys.argv:
        run_prestige_sim(num_runs=6, run_duration=2400)
    elif "--achievements" in sys.argv:
        run_achievements_sim(num_runs=8)
    else:
        run_single_mode()

if __name__ == "__main__":
    main()
