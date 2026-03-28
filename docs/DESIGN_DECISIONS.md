# IDLE ORBIT — Décisions de Design (v1 → v2)

## Ce document trace les décisions explicites pour Idle Orbit.
## Les décisions marquées ⛔ sont FERMES — ne pas revenir dessus sans discussion.

---

## ⛔ DD-01 : Zéro événement négatif
**Décision** : Tous les événements du jeu sont positifs (bonus, opportunités, découvertes).
**Pourquoi** : Les événements négatifs créent de la frustration dans un idle cozy. Le joueur doit toujours avoir le sentiment de progresser.
**Impact** :
- `events.json` : uniquement des entrées positives
- Assets supprimés du v1 : `event_asteroid` (attaque), `event_solar_flare` (panne), `event_power_failure`
- Assets conservés/adaptés : merchant, quantum_anomaly, deep_signal
- Nouveaux événements : mining_surge, solar_wave (bonus énergie), rare_asteroid (bonus mining)
- Le bonus prestige `negative_event_reduction` est supprimé (sans objet)

---

## ⛔ DD-02 : Pas de skins incrémentaux par niveau de station
**Décision** : La station n'a pas de progression visuelle par niveau (lv1.png → lv9.png).
**Pourquoi** : Cela créait de la dette technique et des assets difficiles à maintenir. La progression se ressent via les modules et l'interface.
**Impact** :
- Un seul sprite de station (ou quelques variations thématiques par orbite, à voir plus tard)
- Suppression du système `station_level_skins` du v1

---

## ⛔ DD-03 : Ressources simplifiées — Énergie + Tech
**Décision** : Deux ressources uniquement. Énergie (⚡) production passive, Tech (🔧) mining actif + modules avancés.
**Pourquoi** : Le v1 avait Tech + Bio ce qui créait de la confusion. Tech est maintenant clairement liée à la recherche/progression, Énergie à la production de base.
**Rôle de Tech** : alimente exclusivement l'arbre de recherche.

---

## DD-04 : Mining loop active (NOUVEAU)
**Décision** : Ajout d'une boucle de minage active — tap sur des astéroïdes pour produire de la Tech.
**Pourquoi** : Donne un engagement actif dans un idle, rewarde les sessions actives sans pénaliser le AFK.
**Design** :
- Zone d'astéroïdes accessible (onglet ou section de l'écran principal)
- Mining manuel (tap) + Mining auto via drones/modules
- Les astéroïdes ont des HP, explosent à 0 → drop + respawn
- Événements liés : astéroïde rare, mining surge

---

## DD-05 : Système de quêtes/missions — différé
**Décision** : Le système de quêtes n'est PAS implémenté au départ.
**Pourquoi** : Le v1 avait un système de missions complexe (15 daily + 20 milestones) qui ajoutait de la complexité avant que le core loop soit solide.
**Quand** : Post-MVP, une fois le core loop validé.

---

## DD-06 : Recherche refactorisée (survit au prestige)
**Décision** : L'arbre de recherche est alimenté par Tech, survit intégralement au prestige.
**Pourquoi** : La recherche est le vecteur de progression long terme. La perdre au prestige serait frustrant.
**Branches** : Énergie / Mining / Automatisation / Prestige (à détailler en session)

---

## DD-07 : Save versionné dès le premier commit
**Décision** : Le fichier save contient toujours un champ `save_version: int`, migration systématique.
**Pourquoi** : Le v1 a eu des douleurs lors des migrations de save. On intègre ça dès le départ.
**Pattern** : `save_manager.gd` gère `_migrate(data, from_version)`, appelé si `save_version < CURRENT_VERSION`.

---

## DD-08 : Audio 100% procédural
**Décision** : Zéro fichiers audio externes. Tout généré en GDScript via `AudioStreamGenerator`.
**Pourquoi** : Le v1 avait validé cette approche — 28 SFX + 5 ambiances orbitales sans assets. Légèreté du build, zéro licence.
**Pattern** : `audio_manager.gd` expose `play_sfx(id)` et `play_ambient(orbit_id)`.

---

## DD-09 : Config-driven (balance dans data/ uniquement)
**Décision** : Toutes les constantes de balance (coûts, taux de production, scaling) sont dans `data/balance.json`. `constants.gd` ne contient que des identifiants et enums.
**Pourquoi** : Le v1 avait des valeurs dupliquées entre `constants.gd`, les scripts, et les JSON — source de bugs.

---

## DD-10 : Services externes câblés plus tard
**Décision** : AdMob, IAP, cloud save ne sont PAS câblés au départ. Les classes existent en stub.
**Pattern** : Interfaces vides (`ad_service.gd`, `iap_service.gd`) retournant des valeurs mockées en dev.
