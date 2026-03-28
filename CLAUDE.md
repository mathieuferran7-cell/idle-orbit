# IDLE ORBIT — CLAUDE.md

## Identité
- **Nom** : Idle Orbit
- **Dossier de travail** : LittleOrbitREBOOT
- **Package** : com.idleorbit.app (à confirmer)
- **Concept** : Space station idle — Build, automate, conquer the stars
- **Genre** : Idle/Incremental + active mining loop
- **Cible** : Android-first (Godot 4.6)
- **Ce projet est un reboot de Little Orbit v1** — voir `.claude/CLAUDESKILL.md` pour les leçons

## Stack technique
- **Engine** : Godot 4.6 / GDScript
- **Save** : JSON versionné (champ `save_version` obligatoire, commence à 1)
- **Audio** : 100% procédural — zéro fichiers .ogg/.wav externes
- **Build** : Android APK/AAB
- **Services externes** : à câbler plus tard (AdMob, IAP, cloud save)

## Ressources du jeu
| Ressource | Icône | Source principale | Usage principal |
|-----------|-------|-------------------|-----------------|
| Énergie   | ⚡    | Modules passifs   | Acheter modules, upgrades de base |
| Tech      | 🔧    | Mining actif + modules | Alimenter la Recherche, upgrades avancés |

## Architecture dossiers
```
scripts/
├── autoloads/      # Singletons globaux (project settings → AutoLoad)
│   ├── game_manager.gd     # Logique principale, ressources, modules
│   ├── save_manager.gd     # Save/load JSON versionné
│   ├── event_bus.gd        # Dispatcher signaux global
│   └── audio_manager.gd    # Audio 100% procédural
├── core/           # Systèmes de jeu
│   ├── prestige_manager.gd
│   ├── research_manager.gd
│   ├── mining_manager.gd   # Loop mining actif
│   └── event_spawner.gd    # Événements positifs
├── ui/             # Controllers UI (jamais de logique métier)
└── utils/
    ├── constants.gd        # Identifiants et enums UNIQUEMENT (pas de balance)
    ├── number_formatter.gd # Formatage grands nombres (1.2K, 4.5M)
    └── responsive_ui.gd    # Helpers responsive mobile
scenes/
├── main/main.tscn          # Scène principale
└── ui/                     # Scènes UI
data/                       # SOURCE DE VÉRITÉ pour toute la balance
├── modules.json
├── balance.json            # Toutes les constantes de balance ICI
├── prestige.json           # 5 orbites
├── research.json           # Arbre de recherche
├── events.json             # Événements positifs uniquement
└── locale/fr.json
assets/sprites/
docs/
tests/
```

## Règles absolues (ne jamais déroger)
1. **Zéro événement négatif** — aucun malus, pénalité ou frustration via événement
2. **Config-driven** — toute la balance dans `data/balance.json`, jamais codée en dur dans les scripts
3. **Save versionné** — champ `save_version: int` obligatoire dans chaque save, migration gérée
4. **Audio procédural** — tout en code GDScript, zéro import de fichiers audio
5. **Source de vérité unique** — `data/` pour les valeurs, `constants.gd` pour les identifiants/enums uniquement
6. **Signal-based** — passer par `EventBus` pour la communication inter-systèmes
7. **Autoloads pour les services** — GameManager, SaveManager, EventBus, AudioManager en AutoLoad
8. **Zéro logique métier dans les widgets UI**

## Ce qu'on NE reproduit PAS (erreurs v1)
- Pas de skins incrémentaux par niveau de station
- Pas de balance constants dupliquées entre scripts et JSON
- Pas d'upkeep/maintenance
- Pas d'événements négatifs
- Pas de quêtes/missions au départ (à implémenter plus tard)

## Nouveau vs v1
- **Mining loop** : boucle active tap-to-mine sur zone d'astéroïdes → produit Tech
- **Ressources simplifiées** : Énergie + Tech (au lieu de Tech + Bio)
- **Tech alimente la Recherche** explicitement
- **Recherche refactorisée** : arbre simplifié, survit au prestige

## Mécaniques en attente (ne pas implémenter prématurément)
- Système de quêtes/missions
- AdMob / IAP
- Cloud save
- Localisation multilingue
- Achievements
