# Smart Update v2 — Suivi du projet

## État actuel

Phase : moteur de décision opérationnel, sécurité centrale validée et intégration Arch News terminée.

Version de développement : `v0.2-dev`

Dernier commit stable :

```text
38d9d58 docs(readme): explain Arch News workflow
```

## Architecture terminée

Smart Update v2 fonctionne désormais comme un moteur de décision piloté par des politiques.

Le workflow principal est organisé ainsi :

```text
Détection des mises à jour
→ préparation des contextes
→ chargement des politiques
→ exécution des politiques
→ simulation Pacman
→ décision finale
→ installation seulement si elle est autorisée
→ finalisation du rapport
```

Composants principaux :

- `bin/smart-update` : orchestration du workflow
- `lib/engine.sh` : chargement et exécution des politiques
- `lib/decision.sh` : agrégation et contrôle de la décision finale
- `lib/logger.sh` : journalisation centralisée
- `lib/report.sh` : génération et finalisation des rapports
- `lib/system_checks.sh` : contrôles système préalables
- `lib/policies/` : politiques indépendantes et déterministes

## Contrat des politiques

Chaque politique produit exclusivement :

```text
POLICY_NAME
POLICY_RESULT
POLICY_REASON
POLICY_DETAILS
```

Valeurs autorisées pour `POLICY_RESULT` :

- `ALLOW`
- `WARNING`
- `BLOCK`

Les politiques ne journalisent pas directement, ne génèrent pas de rapport, ne lancent aucune installation et ne terminent pas le programme.

Le moteur valide leurs résultats, les journalise et les transmet au système de décision.

## Politiques disponibles

- limite du nombre de mises à jour
- détection des paquets critiques
- détection des paquets étrangers/AUR
- consultation des annonces officielles Arch Linux

## Sécurité de la décision finale

La barrière centrale de décision est opérationnelle.

Avant toute installation :

- `ALLOW` autorise la poursuite ;
- `WARNING` autorise la poursuite avec signalement ;
- `BLOCK` interdit l’installation ;
- une décision absente ou invalide interrompt également le workflow.

Une politique ne peut donc plus produire un `BLOCK` sans empêcher réellement l’installation.

Les nouvelles dépendances sont également traitées par la décision centrale :

- autorisées par la configuration : `WARNING` ;
- refusées par la configuration : `BLOCK`.

## Arch News — terminé

La chaîne Arch News est intégrée de bout en bout :

```text
Flux RSS officiel Arch Linux
→ collecte structurée
→ lecture de l’état persistant
→ détection des nouvelles annonces
→ préparation du contexte
→ politique Arch News
→ décision
→ enregistrement atomique du dernier GUID
```

### Modules

- `lib/arch_news.sh`
  - téléchargement du flux RSS ;
  - extraction du GUID, du titre, de la date, du lien et du résumé.

- `lib/arch_news_state.sh`
  - lecture du dernier GUID traité ;
  - détection des nouvelles annonces ;
  - écriture atomique de l’état avec permissions `0640`.

- `lib/arch_news_context.sh`
  - orchestration de la collecte et de l’état ;
  - statuts `DISABLED`, `UP_TO_DATE`, `NEW` et `ERROR`.

- `lib/policies/40_arch_news.sh`
  - `ALLOW` lorsque la fonction est désactivée ou qu’aucune annonce nouvelle n’existe ;
  - `WARNING` lorsque de nouvelles annonces doivent être consultées ;
  - `BLOCK` en cas d’erreur de collecte, de parsing ou d’état.

### État persistant

```text
/var/lib/smart-update/arch-news.last
```

Règles :

- première exécution : toutes les annonces collectées sont considérées comme nouvelles ;
- exécutions suivantes : seules les annonces placées avant le dernier GUID enregistré sont nouvelles ;
- aucune nouveauté : le fichier d’état n’est pas réécrit ;
- décision finale bloquante : le GUID n’est pas avancé ;
- GUID enregistré absent du flux : continuité invalide, donc `BLOCK`.

## Validation

### Tests automatisés

```text
Tests exécutés : 15
Réussis        : 15
Échecs         : 0
```

### Test fonctionnel Arch News

Première exécution réelle en mode audit :

```text
Contexte Arch News : NEW
Décision            : WARNING
Annonces détectées  : 10
État enregistré     : oui
Installation        : aucune
```

Deuxième exécution réelle en mode audit :

```text
Contexte Arch News : UP_TO_DATE
Décision            : ALLOW
GUID                : inchangé
Fichier d’état      : non réécrit
Installation        : aucune
```

Le test complet a également confirmé :

- code retour `0` ;
- rapport correctement finalisé ;
- journalisation des annonces ;
- permissions `0640` du fichier d’état ;
- aucune installation en mode `audit`.

## Commits principaux de cette phase

```text
868a447 feat(engine): add modular policy execution engine
19cf040 feat(engine): centralize policy result handling
40af4cb feat(policies): migrate foreign packages check
0b4d19d feat(config): validate Arch news settings
6eeb92d feat(arch-news): add RSS feed collector
f0682ad feat(arch-news): add persistent news state
3ae6805 feat(arch-news): add news preparation context
482911d feat(policies): add Arch news policy
a5a0a15 feat(decision): enforce blocking decision before install
6dc47fe feat(arch-news): integrate news policy workflow
38d9d58 docs(readme): explain Arch News workflow
```

## Prochaine étape

Prochain objectif logique : analyser les contrôles de transaction encore configurés mais pas encore implémentés comme politiques complètes.

Priorités proposées :

1. suppressions de paquets ;
2. remplacements de paquets ;
3. options Pacman interdites ou dangereuses.

Avant tout code, définir pour chaque politique :

- les données d’entrée ;
- les conditions `ALLOW`, `WARNING` et `BLOCK` ;
- les motifs de décision ;
- les détails exposés ;
- les scénarios de test ;
- le point exact d’intégration dans le workflow.

## Règles du projet

- une évolution logique à la fois ;
- architecture et contrat avant le code ;
- tests après chaque modification ;
- un commit ciblé par évolution ;
- aucun déploiement avant validation ;
- toujours documenter l’étape terminée et la suivante.
