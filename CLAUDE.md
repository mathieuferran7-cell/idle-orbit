# IDLE ORBIT — CLAUDE.md

## Identité
- **Nom** : Idle Orbit
- **Package** : com.idleorbit.app
- **Concept** : Space station idle — Build, automate, conquer the stars
- **Genre** : Idle/Incremental + active mining loop + prestige loop + mini-jeu Last Stand + événements FTL
- **Cible** : Android-first (Godot 4.6)
- **Play Store** : test fermé actif (Grimoire Culinaire dev account)
- **Ce projet est un reboot de Little Orbit v1**

## Stack technique
- **Engine** : Godot 4.6.1 / GDScript
- **Save** : JSON versionné (champ `save_version` obligatoire, commence à 1)
- **Audio** : 100% procédural (11 SFX) — zéro fichiers .ogg/.wav externes
- **Build** : Android AAB signé (keystore: idleorbit-release.keystore)
- **Export** : headless Godot + jarsigner manuel
- **Services externes** : hooks en place (AdMob rewarded ads), SDK pas intégré
- **Simulateur** : Python (`tests/sim_runner.py`) pour valider la balance (single run + multi-prestige)
- **Privacy** : GitHub Pages (docs/privacy-policy.html)

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
│   ├── game_manager.gd     # Logique principale, ressources, modules, prestige flow, minigame transition
│   ├── save_manager.gd     # Save/load JSON versionné
│   ├── event_bus.gd        # 13 signaux globaux
│   └── audio_manager.gd    # 11 SFX procéduraux
├── core/           # Systèmes de jeu
│   ├── prestige_manager.gd # Orbits, 11 talents permanents, seuils x3
│   ├── research_manager.gd # 6 noeuds, get_effective_cost() avec discounts
│   ├── mining_manager.gd   # Loop mining actif + auto-tap + module scaling
│   └── event_manager.gd    # Timer aléatoire, 7 events FTL, 5 buffs, 3 milestones
├── minigame/       # Mini-jeu Last Stand (transition prestige)
│   ├── last_stand.gd       # Controller : state machine (COUNTDOWN/WAVE_ACTIVE/WAVE_PAUSE/GAME_OVER)
│   ├── enemy.gd            # Area2D : mouvement, HP, 3 types (small/fast/big)
│   ├── turret.gd           # Auto-target nearest, fire projectile
│   ├── projectile.gd       # Bullet linéaire, collision Area2D
│   └── shockwave.gd        # Cône de choc expandable (swipe), hit detection manuelle
├── ui/             # Controllers UI (jamais de logique métier)
│   ├── main_ui.gd          # Header, 3 onglets, modules, offline popup, event popup FTL, buff display
│   ├── research_ui.gd      # Constellation de recherche (card.modulate 3 états)
│   └── prestige_ui.gd      # Arbre de talents, bouton prestige, DEV menu
└── utils/
    ├── constants.gd        # Identifiants et enums UNIQUEMENT (pas de balance)
    └── number_formatter.gd # Formatage grands nombres (1.2K, 4.5M)
scenes/
├── main/main.tscn          # Scène principale (3 onglets : Modules, Recherche, Prestige)
└── minigame/last_stand.tscn # Scène mini-jeu (Node2D, procédural)
data/                       # SOURCE DE VÉRITÉ pour toute la balance
├── modules.json            # 7 modules (4 énergie, 3 tech)
├── balance.json            # 15 constantes globales (tick, offline, prestige, mining, events)
├── prestige.json           # 11 talents sur 4 tiers
├── research.json           # 6 noeuds de recherche
├── events.json             # 7 événements FTL avec choix + récompenses
└── minigame.json           # Balance Last Stand (station, tourelles, ennemis, 10 vagues + overflow)
assets/
├── icon.png                # Icône app 1024x1024
├── icon_512.png            # Icône Play Store 512x512
└── feature_graphic.png     # Image présentation Play Store 1024x500
docs/
└── privacy-policy.html     # Politique de confidentialité (GitHub Pages)
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
6. **Signal-based** — passer par `EventBus` pour la communication inter-systèmes (13 signaux)
7. **Autoloads pour les services** — GameManager, SaveManager, EventBus, AudioManager en AutoLoad
8. **Zéro logique métier dans les widgets UI**
9. **Research UI : card.modulate only** — 3 états (BUYABLE=blanc, LOCKED=gris, MAXED=doré), jamais de couleur par label
10. **Mobile-first** — portrait forcé, MOUSE_FILTER_PASS sur containers dans ScrollContainer, touch-friendly

## Boucle de jeu complète
```
RUN (idle)
  → Mine (tap + auto-tap) → Tech
  → Achète modules → Énergie/Tech passifs
  → Achète recherches → Multiplicateurs (coûts effectifs avec prestige discount + buff)
  → Événements FTL aléatoires → Choix → Récompenses/Buffs
  → Accumule énergie totale → Seuil prestige atteint
PRESTIGE
  → Mini-jeu Last Stand (survie par vagues)
  → Game over → Score (orbits base × bonus vagues) → Continue via pub OU Prestige
  → Reset complet (énergie, tech, modules, recherche, buffs)
  → Orbits gagnés → Achète talents permanents
  → Atterrit sur onglet Prestige
  → Nouvelle run avec bonus
```

## Prestige
- **Seuil** : `prestige_threshold_base * 3^prestige_count` (500K, 1.5M, 4.5M, 13.5M...)
- **Orbits** : `floor(sqrt(total_energy / 1000)) * orbit_multiplier`
- **Reset** : tout sauf Orbits et talents
- **Talents** : 11 sur 4 tiers (énergie+, tech+, départ+, recherche-, vitesse+, drone init, énergie++, offline+, modules-, orbit+, warp)
- **Flow** : prestige_ui → GameManager.start_prestige_minigame() → last_stand.tscn → complete_prestige_with_bonus() → main.tscn (onglet Prestige)

## Mini-jeu Last Stand
- Station au centre (540, 960), menaces 360°
- Tourelles auto (nombre = modules tech possédés, min 1)
- Swipe = onde de choc en cône 90°, cooldown 1.5s, damage 3
- Station HP = base_hp + modules_énergie * hp_per_module
- 10 vagues définies + overflow infini (+3 ennemis/vague, -0.05s interval)
- Types : small (1HP, lent), fast (1HP, rapide), big (3HP, lent)
- Game over → résultats (orbits base × bonus × vagues) → Continue pub OU Prestige
- Transition : `change_scene_to_packed` aller-retour, autoloads persistent, _in_minigame flag pause production

## Événements FTL
- Timer aléatoire (2-5 min) + 3 milestones (premier tier 2, première recherche max, premier prestige)
- 7 événements narratifs spatiaux avec 3 choix (2 gratuits + 1 premium pub)
- Récompenses : énergie, tech, orbits, buffs temporaires, modules gratuits
- Scaling proportionnel à sqrt(total_energy_produced)
- 5 buffs : energy_x2, tech_x2, speed_x2, tap_x3, research_discount
- Buffs différents se cumulent, même buff additionne les durées
- Toast résultat après choix

## Export Android
- **Keystore** : `%APPDATA%\Godot\keystores\idleorbit-release.keystore` (alias: idleorbit, pass: OrbitRelease2026!)
- **Export** : Godot headless `--export-release "Android"` → jarsigner → idle-orbit-signed.aab
- **Config** : arm64-v8a, SDK 24-35, portrait forcé (`window/handheld/orientation=1`)

## Ce qu'on NE reproduit PAS (erreurs v1)
- Pas de skins incrémentaux par niveau de station
- Pas de balance constants dupliquées entre scripts et JSON
- Pas d'upkeep/maintenance
- Pas d'événements négatifs
- Pas de quêtes/missions au départ

## Mécaniques en attente (ne pas implémenter prématurément)
- AdMob SDK (hooks en place : offline x2, event premium, Last Stand continue)
- IAP
- Cloud save
- Localisation multilingue
- Achievements
- Visual polish (sprites, particules)
- Système de quêtes/missions
- Icône adaptative Android (foreground/background)
