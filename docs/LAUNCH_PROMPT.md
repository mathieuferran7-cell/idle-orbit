# PROMPT DE LANCEMENT — Idle Orbit (nouvelle session Claude Code)

## Comment utiliser ce prompt
Ouvre Claude Code dans `C:\Users\mathi\Documents\LittleOrbitREBOOT` et colle le texte ci-dessous.

---

## PROMPT À COLLER

Nouvelle session Idle Orbit. Lis CLAUDE.md et .claude/CLAUDESKILL.md avant tout.

**Contexte :**
Ce projet est le reboot de Little Orbit v1. On repart de zéro sur une architecture propre.
Le jeu s'appelle **Idle Orbit** — idle/incremental mobile, space station cozy, pixel art.
Engine : Godot 4.6 / GDScript. Cible : Android.

**Ce qui a changé vs v1 (IMPORTANT) :**
- Ressources : Énergie ⚡ (passive) + Tech 🔧 (mining actif) — plus de Bio
- Nouveau : mining loop active (tap astéroïdes → Tech)
- Recherche refactorisée : alimentée par Tech, survit au prestige
- Zéro événement négatif (décision ferme)
- Pas de skins incrémentaux de station
- Pas de système de quêtes pour l'instant
- Voir docs/DESIGN_DECISIONS.md pour toutes les décisions

**Règles absolues (voir CLAUDE.md pour le détail) :**
1. Zéro événement négatif
2. Balance dans data/balance.json uniquement
3. save_version dès le commit 1
4. Audio 100% procédural
5. EventBus pour communication inter-modules
6. Autoloads pour les services

**Objectif de cette session :**
Implémenter le LOT 1 — Core Loop minimal jouable :
- [ ] Autoloads de base : event_bus.gd, save_manager.gd, game_manager.gd, audio_manager.gd
- [ ] data/modules.json (3-4 modules de base Énergie)
- [ ] data/balance.json (constantes de balance)
- [ ] Production tick (Énergie passive)
- [ ] Achat de modules (coût Énergie, scaling x1.15)
- [ ] Scène principale minimale : afficher ressources + boutons modules
- [ ] Save/load fonctionnel avec save_version = 1

Ne pas implémenter avant validation du core : prestige, research, mining, events.
Commencer par faire tourner quelque chose de jouable.

---

## Rappel architecture

```
scripts/autoloads/   → event_bus.gd, save_manager.gd, game_manager.gd, audio_manager.gd
scripts/core/        → prestige_manager.gd, research_manager.gd, mining_manager.gd (plus tard)
scripts/ui/          → controllers UI
scripts/utils/       → constants.gd, number_formatter.gd, responsive_ui.gd
data/                → JSON config (SOURCE DE VÉRITÉ balance)
scenes/main/         → main.tscn
```

## Repo GitHub
https://github.com/mathieuferran7-cell/idle-orbit (privé)
