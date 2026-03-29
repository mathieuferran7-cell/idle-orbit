# IDLE ORBIT — CLAUDE.md

## Identité
- **Nom** : Idle Orbit
- **Dossier de travail** : LittleOrbitREBOOT
- **Package** : com.idleorbit.app (à confirmer)
- **Concept** : Space station idle — Build, automate, conquer the stars
- **Genre** : Idle/Incremental + active mining loop + prestige loop + mini-jeu Last Stand
- **Cible** : Android-first (Godot 4.6)
- **Ce projet est un reboot de Little Orbit v1** — voir `.claude/CLAUDESKILL.md` pour les leçons

## Stack technique
- **Engine** : Godot 4.6 / GDScript
- **Save** : JSON versionné (champ `save_version` obligatoire, commence à 1)
- **Audio** : 100% procédural — zéro fichiers .ogg/.wav externes
- **Build** : Android APK/AAB
- **Services externes** : à câbler plus tard (AdMob, IAP, cloud save)
- **Simulateur** : Python (`tests/sim_runner.py`) pour valider la balance

## Ressources du jeu
| Ressource | Icône | Source principale | Usage principal |
|-----------|-------|-------------------|-----------------|
| Énergie   | ⚡    | Modules passifs   | Acheter modules, upgrades de base |
| Tech      | 🔧    | Mining actif + modules | Alimenter la Recherche, upgrades avancés |
| Orbits    | ⭐    | Prestige          | Acheter talents permanents |

## Architecture dossiers
```
scripts/
├── autoloads/      # Singletons globaux (project settings → AutoLoad)
│   ├── game_manager.gd     # Logique principale, ressources, modules, prestige flow
│   ├── save_manager.gd     # Save/load JSON versionné
│   ├── event_bus.gd        # Dispatcher signaux global
│   └── audio_manager.gd    # Audio 100% procédural
├── core/           # Systèmes de jeu
│   ├── prestige_manager.gd # Orbits, talents permanents, seuils
│   ├── research_manager.gd # Arbre de recherche (reset au prestige)
│   └── mining_manager.gd   # Loop mining actif + auto-tap
├── minigame/       # Mini-jeu Last Stand (transition prestige)
│   ├── last_stand.gd       # Controller : state machine, waves, HUD
│   ├── enemy.gd            # Area2D : mouvement, HP, types
│   ├── turret.gd           # Auto-target, projectiles
│   ├── projectile.gd       # Bullet linéaire
│   └── shockwave.gd        # Cône de choc (swipe)
├── ui/             # Controllers UI (jamais de logique métier)
│   ├── main_ui.gd          # Header, onglets, modules, offline popup
│   ├── research_ui.gd      # Constellation de recherche
│   └── prestige_ui.gd      # Arbre de talents, bouton prestige
└── utils/
    ├── constants.gd        # Identifiants et enums UNIQUEMENT (pas de balance)
    └── number_formatter.gd # Formatage grands nombres (1.2K, 4.5M)
scenes/
├── main/main.tscn          # Scène principale (3 onglets : Modules, Recherche, Prestige)
└── minigame/last_stand.tscn # Scène mini-jeu (Node2D)
data/                       # SOURCE DE VÉRITÉ pour toute la balance
├── modules.json            # 7 modules (4 énergie, 3 tech)
├── balance.json            # Constantes globales (tick, offline, prestige seuils, mining)
├── prestige.json           # 11 talents sur 4 tiers
├── research.json           # 6 noeuds de recherche
└── minigame.json           # Balance Last Stand (station, tourelles, ennemis, vagues)
assets/sprites/             # (vide — tout est procédural pour l'instant)
tests/
├── sim_runner.py           # Simulateur Python (single run + multi-prestige)
└── .gdignore               # Empêche Godot d'importer les CSV de test
```

## Règles absolues (ne jamais déroger)
1. **Zéro événement négatif** — aucun malus, pénalité ou frustration via événement
2. **Config-driven** — toute la balance dans `data/*.json`, jamais codée en dur dans les scripts
3. **Save versionné** — champ `save_version: int` obligatoire dans chaque save, migration gérée
4. **Audio procédural** — tout en code GDScript, zéro import de fichiers audio
5. **Source de vérité unique** — `data/` pour les valeurs, `constants.gd` pour les identifiants/enums uniquement
6. **Signal-based** — passer par `EventBus` pour la communication inter-systèmes
7. **Autoloads pour les services** — GameManager, SaveManager, EventBus, AudioManager en AutoLoad
8. **Zéro logique métier dans les widgets UI**
9. **Research UI : card.modulate only** — 3 états (BUYABLE=blanc, LOCKED=gris, MAXED=doré), jamais de couleur par label

## Boucle de jeu complète
```
RUN (idle)
  → Mine (tap + auto-tap) → Tech
  → Achète modules → Énergie/Tech passifs
  → Achète recherches → Multiplicateurs
  → Accumule énergie totale → Seuil prestige atteint
PRESTIGE
  → Mini-jeu Last Stand (survie par vagues)
  → Vagues survécues = bonus Orbits (x1.0 à x2.0+)
  → Reset complet (énergie, tech, modules, recherche)
  → Orbits gagnés → Achète talents permanents
  → Nouvelle run avec bonus
```

## Prestige
- **Seuil** : `prestige_threshold_base * 3^prestige_count` (500K, 1.5M, 4.5M, 13.5M...)
- **Orbits** : `floor(sqrt(total_energy / 1000)) * orbit_multiplier`
- **Reset** : tout sauf Orbits et talents
- **Talents** : 11 sur 4 tiers (énergie+, tech+, départ+, recherche-, vitesse+, drone init, énergie++, offline+, modules-, orbit+, warp)

## Mini-jeu Last Stand
- Station au centre, menaces 360°
- Tourelles auto (nombre = modules tech possédés)
- Swipe = onde de choc en cône 90°, cooldown 1.5s
- Station HP = base + modules énergie * 2
- 10 vagues définies + overflow infini
- Types : small (1HP), fast (1HP rapide), big (3HP)
- Transition : `change_scene_to_packed` aller-retour main ↔ last_stand

## Ce qu'on NE reproduit PAS (erreurs v1)
- Pas de skins incrémentaux par niveau de station
- Pas de balance constants dupliquées entre scripts et JSON
- Pas d'upkeep/maintenance
- Pas d'événements négatifs
- Pas de quêtes/missions au départ

## Mécaniques en attente (ne pas implémenter prématurément)
- Événements positifs (event_spawner.gd)
- Système de quêtes/missions
- AdMob / IAP
- Cloud save
- Localisation multilingue
- Achievements
- Visual polish (sprites, particules)
