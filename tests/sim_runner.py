#!/usr/bin/env python3
"""
sim_runner.py — Idle Orbit full progression simulator
Simulates an optimal active player: taps, auto-buy modules, research, auto-tap.
Detects dead zones, milestones, and simulates offline earnings.

Usage: python tests/sim_runner.py
"""

import json
import math
import os

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

    def get_level(self, nid):
        return self.levels.get(nid, 0)

    def is_unlocked(self, nid):
        return self.get_level(nid) >= 1

    def is_maxed(self, nid):
        return self.get_level(nid) >= self.data[nid]["max_level"]

    def get_next_cost(self, nid):
        node = self.data[nid]
        level = self.get_level(nid)
        cost_values = node.get("cost_values", [])
        if level < len(cost_values):
            return float(cost_values[level])
        return node["base_cost"] * math.pow(node["cost_growth"], level)

    def can_upgrade(self, nid, tech):
        if self.is_maxed(nid):
            return False
        for req in self.data[nid].get("requires", []):
            if not self.is_unlocked(req):
                return False
        return tech >= self.get_next_cost(nid)

    def upgrade(self, nid):
        cost = self.get_next_cost(nid)
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

    def get_offline_multiplier(self):
        total = 0.0
        for nid, node in self.data.items():
            if node.get("effect", {}).get("type") == "offline_multiplier":
                total += self.get_level(nid) * node.get("effect_per_level", 0)
        return 1.0 + total

    def summary(self):
        parts = []
        for nid in self.data:
            lvl = self.get_level(nid)
            if lvl > 0:
                parts.append(f"{nid[:12]}:{lvl}")
        return " ".join(parts) if parts else "-"

# ── Module engine ────────────────────────────────────────────────────────────

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

def modules_summary(counts):
    parts = [f"{mid[:10]}:{c}" for mid, c in counts.items() if c > 0]
    return " ".join(parts) if parts else "-"

# ── Simulation ───────────────────────────────────────────────────────────────

RESEARCH_PRIORITY = [
    "auto_tap",
    "auto_tap_upgrade",
    "nebula_boost",
    "tech_boost",
    "module_discount",
    "offline_boost",
]

def run_sim(sim_duration=3600, tick=0.25, taps_per_second=4.0, offline_at=None, offline_duration=7200):
    balance = read_json("data/balance.json")
    modules = read_json("data/modules.json")
    research_data = read_json("data/research.json")

    energy = balance.get("starting_energy", 10.0)
    tech = 0.0
    counts = {mid: 0 for mid in modules}
    research = Research(research_data)
    tech_per_tap = balance.get("mining_tech_per_tap", 1.0)

    t = 0.0
    rows = []
    events = []
    report_interval = 15.0
    next_report = 0.0

    # Dead zone tracking
    dead_start = None
    prev_unlocked = set()

    # Auto-tap accumulator
    auto_tap_accum = 0.0

    while t <= sim_duration:
        tick_events = []

        # ── Production ───────────────────────────────────────────────
        e_mult = research.get_energy_multiplier()
        cost_mult = research.get_cost_multiplier()
        e_rate = production(modules, counts, "energy", e_mult)
        t_rate = production(modules, counts, "tech", e_mult)
        energy += e_rate * tick
        tech += t_rate * tick

        # ── Tap bonus from tech modules ──────────────────────────────
        total_tech_modules = sum(
            counts.get(mid, 0) for mid, mod in modules.items()
            if mod.get("resource") == "tech"
        )
        module_tap_bonus = 1.0 + 0.10 * total_tech_modules

        # ── Manual taps ──────────────────────────────────────────────
        taps_this_tick = int(taps_per_second * tick)
        tap_mult = research.get_tech_tap_multiplier() * module_tap_bonus
        tech += taps_this_tick * tech_per_tap * tap_mult

        # ── Auto-tap ─────────────────────────────────────────────────
        auto_interval = research.get_auto_tap_interval()
        if auto_interval > 0:
            auto_tap_accum += tick
            while auto_tap_accum >= auto_interval:
                auto_tap_accum -= auto_interval
                tech += tech_per_tap * tap_mult

        # ── Research buy (priority order) ────────────────────────────
        for nid in RESEARCH_PRIORITY:
            if nid in research.data and research.can_upgrade(nid, tech):
                cost = research.upgrade(nid)
                tech -= cost
                lvl = research.get_level(nid)
                tick_events.append(f"RESEARCH:{nid}:lv{lvl}")
                break  # one research per tick

        # ── Module buy (cheapest greedy) ─────────────────────────────
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

        # ── Unlock detection ─────────────────────────────────────────
        for mid in modules:
            if mid not in prev_unlocked and module_unlocked(modules, mid, counts):
                if counts.get(mid, 0) == 0:
                    name = modules[mid].get("name", mid)
                    tick_events.append(f"UNLOCK:{name}")
                prev_unlocked.add(mid)

        # ── Dead zone detection ──────────────────────────────────────
        can_buy_anything = False
        for mid in modules:
            if module_unlocked(modules, mid, counts):
                c = module_cost(modules, mid, counts, cost_mult)
                if c <= energy:
                    can_buy_anything = True
                    break
        for nid in RESEARCH_PRIORITY:
            if nid in research.data and research.can_upgrade(nid, tech):
                can_buy_anything = True
                break

        if not can_buy_anything and e_rate == 0 and taps_this_tick == 0:
            if dead_start is None:
                dead_start = t
        else:
            if dead_start is not None:
                duration = t - dead_start
                if duration >= 5.0:
                    tick_events.append(f"DEAD_ZONE:{duration:.0f}s")
                dead_start = None

        # ── Offline simulation ───────────────────────────────────────
        if offline_at and abs(t - offline_at) < tick:
            off_max = balance.get("offline_max_seconds", 7200) * research.get_offline_multiplier()
            capped = min(offline_duration, off_max)
            off_e_ratio = balance.get("offline_energy_ratio", 0.5)
            off_t_ratio = balance.get("offline_tech_ratio", 0.5)
            off_e = e_rate * capped * off_e_ratio
            off_t = t_rate * capped * off_t_ratio
            energy += off_e
            tech += off_t
            tick_events.append(f"OFFLINE:{offline_duration//3600}h:{capped:.0f}s_capped:+{off_e:.0f}e+{off_t:.0f}t")

        # ── Report ───────────────────────────────────────────────────
        if t >= next_report or tick_events:
            if t >= next_report:
                next_report += report_interval
            tech_tap = tech_per_tap * research.get_tech_tap_multiplier()
            row = {
                "time": format_time(t),
                "energy": f"{energy:.0f}",
                "tech": f"{tech:.0f}",
                "e_rate": f"{e_rate:.1f}/s",
                "t_rate": f"{t_rate:.1f}/s",
                "tech/tap": f"{tech_tap:.1f}",
                "modules": modules_summary(counts),
                "research": research.summary(),
                "event": " | ".join(tick_events) if tick_events else "",
            }
            rows.append(row)

        t += tick

    return rows

def format_time(seconds):
    m = int(seconds) // 60
    s = int(seconds) % 60
    return f"{m:02d}:{s:02d}"

# ── Output ───────────────────────────────────────────────────────────────────

def main():
    print("=" * 80)
    print("IDLE ORBIT — PROGRESSION SIMULATOR")
    print("60 min active play, 4 taps/s, auto-buy, research priority, offline @30min")
    print("=" * 80)

    rows = run_sim(
        sim_duration=3600,
        tick=0.25,
        taps_per_second=4.0,
        offline_at=1800,       # simulate 2h offline at 30min mark
        offline_duration=7200,
    )

    # CSV output
    header = "time,energy,tech,e_rate,t_rate,tech/tap,modules,research,event"
    out_path = os.path.join(PROJECT_ROOT, "tests", "sim_result.csv")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(header + "\n")
        for r in rows:
            line = ",".join(str(r[k]) for k in ["time", "energy", "tech", "e_rate", "t_rate", "tech/tap", "modules", "research", "event"])
            f.write(line + "\n")

    # Console: only events + milestones
    print(f"\n{'TIME':<8} {'ENERGY':>10} {'TECH':>10} {'E/s':>8} {'T/s':>8} {'T/tap':>6}  EVENT")
    print("-" * 80)
    for r in rows:
        event = r["event"]
        # Print all event rows + every 60s snapshot
        time_parts = r["time"].split(":")
        sec = int(time_parts[0]) * 60 + int(time_parts[1])
        if event or sec % 60 == 0:
            marker = f"  << {event}" if event else ""
            print(f"{r['time']:<8} {r['energy']:>10} {r['tech']:>10} {r['e_rate']:>8} {r['t_rate']:>8} {r['tech/tap']:>6}{marker}")

    print(f"\nFull CSV -> {out_path}")

    # Summary
    print("\n" + "=" * 80)
    print("MILESTONES SUMMARY")
    print("=" * 80)
    for r in rows:
        if r["event"]:
            print(f"  [{r['time']}] {r['event']}")

if __name__ == "__main__":
    main()
