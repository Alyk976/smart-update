# Smart Update v2 — Suivi du projet

## État actuel

Phase : Refactorisation du prototype

Dernière étape terminée :
- Création de l’arborescence du projet
- Déplacement des fichiers dans :
  - bin/
  - lib/
  - config/
  - systemd/
  - docs/
  - scripts/
  - tests/

## Prochaine étape

Créer le module :

lib/logger.sh

Objectif :
- extraire les fonctions de journalisation de lib/functions.sh
- utiliser des noms préfixés :
  - logger_info
  - logger_warning
  - logger_error
  - logger_blocked
  - logger_success
  - logger_debug

## Étapes suivantes

1. Créer lib/logger.sh
2. Tester le module logger
3. Modifier bin/smart-update pour charger logger.sh
4. Retirer les anciennes fonctions de log de functions.sh
5. Faire un commit Git
6. Créer ensuite le module config.sh

## Règles du projet

- Une étape à la fois
- Un test après chaque modification
- Un commit par évolution
- Aucun déploiement système avant validation
- Toujours documenter l’étape terminée et la suivante
