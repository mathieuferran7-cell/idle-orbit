# IDLE ORBIT — CLAUDE.md

## Identité
- **Nom** : Idle Orbit
- **Package** : com.idleorbit.app
- **Concept** : Space station idle — Build, automate, conquer the stars
- **Genre** : Idle/Incremental + active mining loop + prestige loop + mini-jeu Last Stand + événements FTL
- **Cible** : Android-first (Godot 4.6)
- **Play Store** : test fermé actif (Grimoire Culinaire dev account), v1.1.3 (code 15)
- **Ce projet est un reboot de Little Orbit v1**

## Stack technique
- **Engine** : Godot 4.6.1 / GDScript
- **Save** : JSON versionné (champ `save_version` obligatoire, commence à 1)
- **Audio** : 100% procédural (11 SFX) — zéro fichiers .ogg/.wav externes
- **Build** : Android AAB signé (keystore: idleorbit-release.keystore)
- **Export** : headless Godot + jarsigner manuel
- **AdMob** : Poing Studios plugin v4.3.1 (rewarded + banner), IDs dans data/ads.json
- **Shaders** : starfield parallaxe + station glow (shaders/*.gdshader)
- **Particules** : CPUParticles2D (tap, death enemy, projectile trail)
- **Simulateur** : Python (`tests/sim_runner.py`) pour valider la balance (single run + multi-prestige + achievements)
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
│   ├── game_manager.gd     # Logique principale, facades (buy_talent, upgrade_research, claim_quest), prestige flow
│   ├── save_manager.gd     # Save/load JSON versionné
│   ├── event_bus.gd        # 18 signaux globaux
│   ├── audio_manager.gd    # 11 SFX procéduraux
│   └── ad_manager.gd       # AdMob rewarded + banner, fallback desktop
├── core/           # Systèmes de jeu
│   ├── prestige_manager.gd # Orbits, 15 talents permanents (5 tiers), coûts incrémentaux, seuils x3 avec réduction, add_orbits()
│   ├── research_manager.gd # 6 noeuds, get_effective_cost(), set_level(), all_maxed()
│   ├── mining_manager.gd   # Loop mining actif + auto-tap + module scaling
│   ├── event_manager.gd    # Timer aléatoire, 7 events FTL, 5 buffs, 3 milestones, get_state/load_state
│   ├── achievement_manager.gd # 31 achievements, stats persistantes, signal-driven, check_all()
│   └── quest_manager.gd    # 12 daily pool (3/jour) + 5 weekly, scaling prestige, reset quotidien/hebdo
├── minigame/       # Mini-jeu Last Stand (transition prestige, optionnel)
│   ├── last_stand.gd       # Controller : state machine, viewport dynamique, starfield + glow shaders
│   ├── enemy.gd            # Area2D : mouvement, HP, 3 types (small/fast/big), death particles
│   ├── turret.gd           # Auto-target nearest, fire projectile
│   ├── projectile.gd       # Bullet linéaire, collision Area2D (radius 5px aligné), trail particles
│   └── shockwave.gd        # Cône de choc expandable (swipe), hit detection manuelle
├── ui/             # Controllers UI (jamais de logique métier — passe par GameManager)
│   ├── main_ui.gd          # Header, 4 onglets, modules, offline popup, event popup FTL, buff display, banner ad, quêtes, achievement toast, floating tap text
│   ├── research_ui.gd      # Constellation de recherche (card.modulate 3 états)
│   └── prestige_ui.gd      # Arbre de talents (5 tiers), bouton prestige rapide + Last Stand, DEV menu
└── utils/
    ├── constants.gd        # Identifiants et enums UNIQUEMENT (pas de balance)
    └── number_formatter.gd # Formatage grands nombres (1.2K, 4.5M)
scenes/
├── main/main.tscn          # Scène principale (4 onglets : Modules, Recherche, Prestige, Quêtes)
└── minigame/last_stand.tscn # Scène mini-jeu (Node2D, procédural)
shaders/                    # Shaders visuels CanvasItem
├── starfield.gdshader      # Fond étoilé 3 couches parallaxe avec scintillement
└── station_glow.gdshader   # Glow radial station (pulse cyan→rouge selon HP)
data/                       # SOURCE DE VÉRITÉ pour toute la balance
├── modules.json            # 7 modules (4 énergie, 3 tech)
├── balance.json            # 15 constantes globales (tick, offline, prestige, mining, events)
├── prestige.json           # 15 talents sur 5 tiers (coûts incrémentaux base * growth^level)
├── research.json           # 6 noeuds de recherche
├── events.json             # 7 événements FTL avec choix + récompenses
├── minigame.json           # Balance Last Stand (station, tourelles, ennemis, 10 vagues + overflow)
├── ads.json                # IDs AdMob (app_id, rewarded_id, banner_id)
├── achievements.json       # 31 achievements (conditions, récompenses)
└── quests.json             # 12 quêtes daily pool + 5 weekly, scaling prestige
addons/
└── admob/                  # Plugin Poing Studios v4.3.1
assets/
├── icon.png                # Icône app 1024x1024
├── icon_512.png            # Icône Play Store 512x512
└── feature_graphic.png     # Image présentation Play Store 1024x500
docs/
└── privacy-policy.html     # Politique de confidentialité (GitHub Pages)
tests/
├── sim_runner.py           # Simulateur Python (single run + multi-prestige + achievements)
└── .gdignore               # Empêche Godot d'importer les CSV de test
```

## Règles absolues (ne jamais déroger)
1. **Zéro événement négatif** — aucun malus, pénalité ou frustration via événement
2. **Config-driven** — toute la balance dans `data/*.json`, jamais codée en dur dans les scripts
3. **Save versionné** — champ `save_version: int` obligatoire dans chaque save, migration gérée
4. **Audio procédural** — tout en code GDScript, zéro import de fichiers audio
5. **Source de vérité unique** — `data/` pour les valeurs, `constants.gd` pour les identifiants/enums uniquement
6. **Signal-based** — passer par `EventBus` pour la communication inter-systèmes (18 signaux)
7. **Autoloads pour les services** — GameManager, SaveManager, EventBus, AudioManager, AdManager en AutoLoad
8. **Zéro logique métier dans les widgets UI** — passer par les facades GameManager (buy_talent, upgrade_research, buy_module)
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
PRESTIGE (2 options)
  → Prestige Rapide : orbits base, skip mini-jeu
  → Last Stand : mini-jeu survie par vagues → orbits base × bonus vagues
  → Continue via pub OU Prestige (si Last Stand)
  → Reset complet (énergie, tech, modules, recherche, buffs)
  → Orbits gagnés → Achète talents permanents (5 tiers)
  → Atterrit sur onglet Prestige
  → Nouvelle run avec bonus
```

## Prestige
- **Seuil** : `prestige_threshold_base * 3^prestige_count * reduction` (reduction = Accélérateur talent, min 0.3)
- **Orbits** : `floor(sqrt(total_energy / 1000)) * orbit_multiplier`
- **Reset** : tout sauf Orbits et talents
- **Talents** : 15 sur 5 tiers
  - Tier 1 : énergie+, tech+, départ+
  - Tier 2 : recherche-, vitesse+, drone init
  - Tier 3 : énergie++, offline+, modules-
  - Tier 4 : orbit+, warp
  - Tier 5 : ingénierie (module cost), énergie+++, accélérateur (threshold), forage profond (tech/tap)
- **Flow** : prestige_ui → Prestige Rapide (quick_prestige, 0 bonus) OU Last Stand (start_prestige_minigame → last_stand.tscn → complete_prestige_with_bonus) → main.tscn (onglet Prestige)

## Mini-jeu Last Stand
- Station au centre (viewport dynamique), menaces 360°
- Tourelles auto (nombre = modules tech possédés, min 1)
- Swipe = onde de choc en cône 90°, cooldown 1.5s, damage 3
- Station HP = base_hp + modules_énergie * hp_per_module
- 10 vagues définies + overflow infini (+3 ennemis/vague, -0.05s interval)
- Types : small (1HP, lent), fast (1HP, rapide), big (3HP, lent)
- Game over → résultats (orbits base × bonus × vagues) → Continue pub OU Prestige
- Transition : `change_scene_to_packed` aller-retour, autoloads persistent, _in_minigame flag pause production

## Événements FTL
- Timer aléatoire (5-10 min) + 3 milestones (premier tier 2, première recherche max, premier prestige)
- 7 événements narratifs spatiaux avec 3 choix (2 gratuits + 1 premium pub rewarded)
- Récompenses : énergie, tech, orbits, buffs temporaires, modules gratuits
- Scaling proportionnel à sqrt(total_energy_produced)
- 5 buffs : energy_x2, tech_x2, speed_x2, tap_x3, research_discount
- Buffs différents se cumulent, même buff additionne les durées
- Toast résultat après choix
- État sauvegardé (buffs, history, milestones, timer)

## Achievements
- 31 achievements permanents (persistent cross-prestige)
- AchievementManager écoute EventBus, vérifie conditions, débloque, donne récompenses
- Stats trackées : total_taps, total_modules_bought, total_research_bought, total_events_completed, last_stand_best_wave, cumulative_energy
- Guard `_initialized` : signaux ignorés avant load_state() pour éviter double-reward
- Guard `_suppress_rewards` : check_all() initial sur anciennes saves ne donne pas de récompenses
- Types de conditions : module_count, total_modules, total_taps, total_energy, prestige_count, research_count, research_all_maxed, module_unlocked, total_orbits, talent_count, all_talents, last_stand_waves, event_count
- Toast notification sur unlock (icône + nom)

## Quêtes
- 12 quêtes daily (pool rotatif, 3 actives/jour, seed = hash du jour)
- 5 quêtes weekly (fixes, reset lundi)
- Scaling dynamique : quêtes avec `scale_with_prestige: true` multiplient objectif et récompense par `(1 + prestige_count * 0.5)`
- Onglet "QUÊTES" (4ème onglet) avec progress bars et bouton Claim
- Badge amber sur l'onglet quand une quête est claimable
- Reset check périodique (chaque 60s) pour les sessions passant minuit
- Types d'objectifs : taps, energy_produced, tech_collected, modules_bought, research_bought, events_completed, prestiges, last_stand_waves

## Visual polish
- **Starfield shader** : 3 couches parallaxe, scintillement, utilisé sur main scene (BG) et minigame
- **Station glow shader** : glow radial pulsant, couleur cyan→rouge selon HP station
- **Tap particles** : CPUParticles2D burst doré sur chaque tap mining
- **Enemy death particles** : explosion couleur héritée à la mort des ennemis
- **Projectile trail** : CPUParticles2D doré, local_coords=false
- **Floating text** : "+N 🔧" animé au point de tap, doré si buff tap_x3
- **Tab fade-in** : transition alpha 0→1 sur switch d'onglet
- **Module buy flash** : flash vert sur la row achetée
- **Buy mode toggle** : sticky header (ne scroll pas avec les modules)

## AdMob
- **Plugin** : Poing Studios v4.3.1 (addons/admob/)
- **App ID** : ca-app-pub-2568736669187422~6903408208
- **Rewarded** : ca-app-pub-2568736669187422/6763807402 (offline x2, event premium, Last Stand continue)
- **Banner** : ca-app-pub-2568736669187422/5612807024 (bas d'écran pendant idle)
- **Fallback** : si pas de pub dispo, récompense donnée immédiatement
- **Protection** : flag _is_showing empêche double-click
- **Config** : data/ads.json (config-driven)
- **Note** : permission AD_ID non injectée par le plugin (publié sans autorisation, ads fonctionnent)

## Export Android
- **Keystore** : `%APPDATA%\Godot\keystores\idleorbit-release.keystore` (alias: idleorbit, pass: OrbitRelease2026!)
- **Export** : Godot headless `--export-release "Android"` → jarsigner → idle-orbit-signed.aab
- **Config** : arm64-v8a, SDK 24-35, portrait forcé (`window/handheld/orientation=1`)
- **Version actuelle** : code 15, name 1.1.3
- **Manifeste release** : android/build/src/release/AndroidManifest.xml (INTERNET permission, portrait, AdMob App ID auto-injecté par plugin)

## Ce qu'on NE reproduit PAS (erreurs v1)
- Pas de skins incrémentaux par niveau de station
- Pas de balance constants dupliquées entre scripts et JSON
- Pas d'upkeep/maintenance
- Pas d'événements négatifs
- Pas de quêtes/missions au départ

## Mécaniques en attente (ne pas implémenter prématurément)
- IAP (No Ads 1.99€, Starter Pack)
- Cloud save
- Localisation multilingue
- Visual polish passe 2 (sprites réels pour station, ennemis, modules)
- Icône adaptative Android (foreground/background)
- Permission AD_ID (fix plugin Poing)
- Artefacts / système de collection
- Carte stellaire (exploration post-prestige)
- Onboarding / tutoriel contextuel (3 étapes)
- Contrats deep scan (objectifs par run)
