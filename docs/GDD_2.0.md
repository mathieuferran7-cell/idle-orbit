# IDLE ORBIT — GDD v0.1

## Vision
Construire et automatiser une station spatiale. Miner des ressources. S'étendre à de nouvelles orbites. Recommencer avec des bonus permanents.

Idle cozy avec une boucle de minage active dans un univers pixel art.

---

## Core Loop

```
[ÉNERGIE] ←─ modules passifs
     ↓
[Acheter/Upgrader modules]
     ↓
[TECH] ←─ mining actif + modules
     ↓
[Recherche] → bonus permanents
     ↓
[Prestige] → orbite suivante + Stars
     ↑_________________________________|
```

1. **Produire** : les modules génèrent Énergie (et un peu de Tech) passivement
2. **Miner** : action active — taper sur la zone d'astéroïdes pour extraire de la Tech
3. **Upgrader** : dépenser Énergie pour améliorer/acheter des modules
4. **Rechercher** : dépenser Tech pour débloquer des upgrades permanents
5. **Prestige** : reset Énergie/Tech/modules → gain de Stars + bonus → orbite suivante

---

## Ressources

| Ressource | Icône | Production | Usage |
|-----------|-------|------------|-------|
| Énergie | ⚡ | Modules passifs (solaire, réacteur...) | Acheter modules, upgrades de base |
| Tech | 🔧 | Mining actif + modules avancés | Arbre de recherche, upgrades avancés |

**Pas d'autre ressource au MVP.** La complexité vient des multiplicateurs, pas du nombre de ressources.

---

## Modules (station)

Pas de progression visuelle de la station par niveau. La station est un espace avec des slots.

### Modules de base (Énergie)
| Module | Production | Coût initial | Scaling |
|--------|------------|--------------|---------|
| Panneau solaire | ⚡/s | bas | x1.15 par niveau |
| Réacteur orbital | ⚡/s (x3) | moyen | x1.15 |
| Générateur de fusion | ⚡/s (x10) | élevé | x1.15 |

### Modules avancés (Tech passif)
| Module | Production | Débloqué via |
|--------|------------|--------------|
| Foreuse orbitale | 🔧/s faible | Recherche niv.1 |
| Laboratoire | 🔧/s + boost recherche | Recherche niv.3 |

### Modules de support
| Module | Effet |
|--------|-------|
| Antenne comm | Multiplicateur global +% |
| Serre | Multiplicateur Énergie +% |
| Station de raffinage | Convertit excès Énergie → Tech |

---

## Mining Loop (NOUVEAU v2)

### Concept
Zone d'astéroïdes accessible depuis l'écran principal (onglet ou section).

- **Tap sur un astéroïde** → gain de Tech (quantité = mining_power)
- **Astéroïdes** : HP variables, explosent quand détruits → bonus
- **Respawn** automatique après destruction
- **Drones miniers** : upgrade qui ajoute du mining passif automatique

### Progression mining
1. Mining manuel (tap)
2. Mining Drone x1 → auto (lent)
3. Mining Drone x2 → auto (moyen)
4. Foreuse Orbitale (module station) → auto (rapide)

### Événements liés au mining
- **Astéroïde rare** : spawn aléatoire, récompense bonus en Tech
- **Mining Surge** : multiplicateur mining x3 pendant 30s

---

## Prestige (5 Orbites)

### Principe
Reset soft : Énergie, Tech, modules → remis à zéro.
Conservé : Recherche (intégrale ou partielle — à décider en session), Stars gagnées.

### Les 5 Orbites
| Orbite | Nom | Bonus prestige | Condition reset |
|--------|-----|----------------|-----------------|
| 1 | Orbite Basse | Base | X Énergie totale produite |
| 2 | Orbite Médiane | +25% prod globale | X* plus élevé |
| 3 | Orbite Haute | +50% prod globale | ... |
| 4 | Orbite Géostationnaire | Mining auto dès départ | ... |
| 5 | Orbite Lunaire | Unlock bonus permanent | ... |

*Les seuils exacts seront définis lors de la session balance.*

### Stars ★ (monnaie prestige)
- Gagnées à chaque prestige (quantité selon orbite + progression)
- Dépensées dans l'arbre prestige (bonus passifs permanents)
- **Ne jamais resetterr**

---

## Arbre de Recherche

### Principe
- Alimenté par Tech 🔧
- Débloque des améliorations permanentes et des modules
- Survit au prestige (intégral)

### Branches (à détailler en session)
- **Énergie** : multiplicateurs de production
- **Mining** : boost mining power, drone upgrades
- **Automatisation** : unlock modules avancés
- **Prestige** : bonus au reset

---

## Événements (positifs UNIQUEMENT)

Tous les événements = opportunité ou bonus. Jamais de pénalité.

| Événement | Effet | Durée |
|-----------|-------|-------|
| Marchand orbital | Offre d'échange avantageux | Tap pour accepter |
| Anomalie quantique | Bonus Tech x2 | 60s |
| Signal profond | Gain immédiat Tech | Instantané |
| Vague solaire | Bonus Énergie x3 | 30s |
| Mining Surge | Boost mining x3 | 30s |
| Astéroïde rare | Apparaît dans zone mining | HP élevé, drop élevé |

---

## UI / Esthétique

- **Style** : Pixel art cozy space
- **Palette** : bleu nuit profond, oranges/jaunes stellaires, accents néon doux
- **Layout** : mobile-first 1080x1920, scroll vertical ou onglets bas
- **Pas de skins** par niveau de station
- **Audio** : procédural (0 fichiers), ambiances orbitales génératives

---

## Ce qu'on implémente PAS au départ
- Quêtes / missions (post-MVP)
- Achievements (post-MVP)
- Monetisation (AdMob, IAP) — framework prévu, non câblé
- Localisation multilingue (français d'abord)
- Cloud save
