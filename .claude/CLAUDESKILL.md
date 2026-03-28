# CLAUDESKILL — Idle Orbit (ex Little Orbit v1)
# Transfer de connaissances architecture depuis le v1
# Date : 2026-03-28

---

## Tableau de bord v1
| Métrique | Valeur |
|----------|--------|
| Scripts GDScript | 26 |
| Fichiers JSON data | 12 |
| Scènes Godot | 2 |
| Assets sprites | 17 |
| Autoloads | 12 |
| Version save finale | 3 |
| Runs simulation | 3300+ |
| Statut | Internal Testing Google Play |

---

## Décisions Architecture (DA)

### DA-01 — Audio 100% procédural ✅ CONSERVER
**Verdict** : Pattern validé en v1. 28 SFX + 5 ambiances orbitales sans aucun fichier audio.
**Comment** : `AudioStreamGenerator` + `AudioStreamGeneratorPlayback` en GDScript. Chaque son est une fonction qui remplit un buffer PCM.
**Gotcha** : Le sample rate doit correspondre entre le stream et le buffer. Utiliser 22050 Hz pour mobile.
**Pattern** :
```gdscript
func play_sfx(id: String) -> void:
    var player = AudioStreamPlayer.new()
    var stream = AudioStreamGenerator.new()
    stream.mix_rate = 22050.0
    player.stream = stream
    add_child(player)
    player.play()
    _fill_buffer(player.get_stream_playback(), id)
```

### DA-02 — Save JSON versionné ✅ CONSERVER (améliorer)
**Verdict** : Le v1 avait des douleurs de migration en cours de dev. Intégrer `save_version` dès le commit 1.
**Pattern** :
```gdscript
const CURRENT_SAVE_VERSION = 1

func load_game() -> Dictionary:
    var data = _read_json()
    if data.get("save_version", 0) < CURRENT_SAVE_VERSION:
        data = _migrate(data, data.get("save_version", 0))
    return data

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
    if from_version < 1:
        # migration v0 → v1
        pass
    return data
```

### DA-03 — Autoloads comme services globaux ✅ CONSERVER
**Verdict** : Pattern solide. GameManager, SaveManager, EventBus, AudioManager en AutoLoad Godot.
**Ordre d'init important** : EventBus en premier, puis SaveManager, puis GameManager.
**Gotcha** : Ne pas faire d'appels croisés dans `_ready()` — utiliser `call_deferred` ou attendre `EventBus.game_ready`.

### DA-04 — EventBus signal-based ✅ CONSERVER
**Verdict** : Découple complètement les systèmes. Toute communication inter-module passe par des signaux.
**Pattern** :
```gdscript
# event_bus.gd (autoload)
signal resource_changed(type: String, amount: float)
signal prestige_triggered(orbit: int)
signal module_purchased(module_id: String)
signal mining_hit(tech_gained: float)
```
**Gotcha** : Ne pas connecter depuis `_ready()` si le node n'est pas encore dans l'arbre. Utiliser `await ready`.

### DA-05 — Config-driven balance ✅ CONSERVER (renforcer)
**Problème v1** : Balance constants dupliquées entre `constants.gd`, scripts, et JSON. Source de bugs silencieux.
**Solution v2** : `data/balance.json` est la SOURCE DE VÉRITÉ unique. `constants.gd` = identifiants et enums UNIQUEMENT.
**Pattern** : GameManager charge `balance.json` au démarrage, expose `GameManager.balance` en lecture seule.

### DA-06 — Skins station incrémentaux ❌ SUPPRIMER
**Problème** : 9 sprites de station (lv1 à lv9) = dette assets, coupling fort avec le niveau de station.
**Décision v2** : Pas de skin progressif. Un sprite de station, variations éventuelles par orbite (thématique).

### DA-07 — Upkeep/maintenance ❌ SUPPRIMER (déjà supprimé en v1 fin)
**Décision** : `UPKEEP_MIN_STATION_LEVEL = 999` en v1 = désactivé. Ne pas réintroduire.

### DA-08 — Événements négatifs ❌ SUPPRIMER
**Décision ferme** : Zéro événement négatif. Voir DD-01 dans DESIGN_DECISIONS.md.

### DA-09 — Simulation de balance ✅ CONSERVER le principe
**Outil** : `sim_runner.gd` headless + CSV output. 3300+ runs validaient le balance en v1.
**Quand** : Créer le sim runner une fois le core loop stable, avant tout tuning de balance.

### DA-10 — Debug gating ✅ CONSERVER
**Pattern v1** : `OS.is_debug_build()` pour gater les features debug.
```gdscript
if OS.is_debug_build():
    $DebugPanel.show()
```
**Ne jamais** laisser un `print()` ou un panel debug accessible en release.

---

## Bugs connus du v1 (ne pas reproduire)

### BUG-01 — Balance constants dupliquées [HAUTE]
**Symptôme** : Modifier une valeur dans `constants.gd` n'avait pas d'effet car JSON prenait la priorité (ou inversement).
**Cause** : Deux sources de vérité.
**Fix v2** : DA-05 — tout dans `balance.json`.

### BUG-02 — Save non versionné au départ [HAUTE]
**Symptôme** : Migrations douloureuses lors des changements de structure save en cours de dev.
**Fix v2** : DA-02 — `save_version` dès le commit 1.

### BUG-03 — MAX buy mode affichage [MOYENNE]
**Symptôme** : Le mode "Acheter MAX" affichait une quantité incorrecte (calcul OK, affichage KO).
**Cause** : UI pas mise à jour après calcul batch.
**Fix** : Forcer `queue_redraw()` / `text = ...` après calcul dans `_process`.

### BUG-04 — Autoloads appels croisés dans _ready() [MOYENNE]
**Symptôme** : Crashs aléatoires au démarrage selon l'ordre d'init des autoloads.
**Fix** : Utiliser `call_deferred("_post_init")` ou écouter `EventBus.game_ready` avant tout appel.

### BUG-05 — Audio craquements sur Android [BASSE]
**Symptôme** : Buffer audio trop petit → artefacts sur appareils lents.
**Fix** : Augmenter `buffer_length` à 0.1s minimum. Tester sur Android bas de gamme.

---

## Patterns réutilisables (P)

### P1 — Number Formatter
```gdscript
# number_formatter.gd
static func format(value: float) -> String:
    if value >= 1_000_000_000:
        return "%.1fB" % (value / 1_000_000_000.0)
    elif value >= 1_000_000:
        return "%.1fM" % (value / 1_000_000.0)
    elif value >= 1_000:
        return "%.1fK" % (value / 1_000.0)
    return "%.0f" % value
```

### P2 — Responsive UI (RUI)
Le v1 avait `responsive_ui.gd` pour calculer les tailles selon la densité d'écran.
```gdscript
# responsive_ui.gd
static func scale(base_px: float) -> float:
    return base_px * (DisplayServer.screen_get_dpi() / 160.0)
```

### P3 — Production tick (delta accumulation)
```gdscript
var _tick_accumulator: float = 0.0
const TICK_INTERVAL = 0.25  # 4 ticks/sec

func _process(delta: float) -> void:
    _tick_accumulator += delta
    while _tick_accumulator >= TICK_INTERVAL:
        _tick_accumulator -= TICK_INTERVAL
        _production_tick(TICK_INTERVAL)
```
**Pourquoi** : Évite les calculs de production à chaque frame. Plus stable sur mobile.

### P4 — Offline production (AFK)
```gdscript
func calculate_offline_gain(seconds_offline: float) -> Dictionary:
    var capped = min(seconds_offline, MAX_OFFLINE_SECONDS)  # cap à 8h
    return {
        "energy": production_rate_energy * capped,
        "tech": production_rate_tech * capped * offline_tech_ratio
    }
```

### P5 — Module cost scaling
```gdscript
func get_module_cost(module_id: String, current_count: int) -> float:
    var base = balance.modules[module_id].base_cost
    var growth = balance.modules[module_id].cost_growth  # ex: 1.15
    return base * pow(growth, current_count)
```

---

## Dépendances clés v1 (pour référence)

| Package | Usage | Conserver ? |
|---------|-------|-------------|
| Godot 4.6 | Engine | ✅ |
| GDScript natif | Audio procédural | ✅ |
| export_presets Android | APK/AAB build | ✅ |
| AdMob plugin | Rewarded ads | ⏳ Plus tard |
| IAP plugin | Achats in-app | ⏳ Plus tard |
| Firebase | Analytics | ⏳ Plus tard |

---

## Timeline v1 (référence)
- Semaine 1-2 : Prototype core loop
- Semaine 3 : Devenu MVP (pas de réécriture)
- Mars 2026 : Internal Testing Google Play (build 1.0.0)
- Fin mars 2026 : REBOOT → Idle Orbit v2.0

---

## Leçons résumées (à lire en début de session)
1. **Balance dans JSON dès le départ** — pas dans constants.gd
2. **Save version = 1 dès le premier commit** — pas de rattrapage
3. **EventBus avant tout** — premier autoload, pas d'appels dans _ready()
4. **Audio procédural validé** — copier les patterns du v1, ça marche
5. **Sim runner tôt** — ne pas balancer à l'œil, simuler
6. **Pas d'upkeep, pas d'events négatifs** — testé, ça nuit à l'expérience cozy
7. **Skins station = dette** — éviter les assets liés au niveau
