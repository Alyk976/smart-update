# Smart Update — Suivi du projet

## État actuel

Version stable : `v1.1.1`

Smart Update est désormais une version stable validée sur Arch Linux. Le moteur
analyse les mises à jour, prépare un contexte transactionnel libalpm, applique
les politiques, vérifie la capacité d'exécution non interactive et n'autorise
l'installation qu'après la décision finale.

## Fonctionnalités livrées en v1.1.0

- modes `audit` et `guarded` ;
- décisions déterministes `ALLOW`, `WARNING` et `BLOCK` ;
- barrière centrale interdisant toute installation après un `BLOCK` ;
- vérification de stabilité des candidats officiels ;
- refus des dépôts testing/staging/unstable et des versions explicitement
  alpha, beta, RC, pre, preview, dev, nightly, snapshot ou VCS ;
- gestion contrôlée des paquets critiques ;
- suivi des annonces Arch Linux avec état persistant atomique ;
- détection des paquets Foreign/AUR ;
- détection libalpm des suppressions, remplacements, ajouts et questions de
  transaction ;
- identification des nouveaux paquets et dépendances ;
- détection des transactions nécessitant une décision Pacman manuelle ;
- détection de dérive de transaction avant installation ;
- support AUR stable optionnel via `yay`, désactivé par défaut ;
- validation d'une identité AUR non-root et comportement fail-closed ;
- revalidation de `yay` après la mise à jour officielle ;
- journaux structurés et rapports finalisés de manière idempotente ;
- rétention des rapports pendant 90 jours ;
- rotation optionnelle des journaux avec logrotate ;
- service et timer systemd ;
- paquet Arch natif avec préservation de la configuration sous `/etc` ;
- contrat public de codes de sortie jusqu'au code `34`.

## Correctif livré en v1.1.1

- correction du reporting des paquets Foreign lorsque `ENABLE_AUR_UPDATES="no"` ;
- les paquets Foreign ne sont plus présentés comme « absents de l'AUR » lorsque
  la classification AUR n'a pas été exécutée ;
- le message indique désormais explicitement que la recherche AUR est désactivée
  et qu'aucune modification automatique n'est effectuée ;
- comportement d'installation, politiques, codes de sortie et modèle de sécurité
  inchangés ;
- test de régression ajouté pour le cas AUR désactivé.

## Validation v1.1.0

- 46 tests automatisés réussis ;
- validation `bash -n`, ShellCheck et unités systemd ;
- construction propre avec `makepkg --cleanbuild --check` ;
- paquet `smart-update 1.1.0-1` installé sur machine réelle ;
- test réel `guarded` avec blocage contrôlé `29` sans modification de paquets ;
- test réel AUR sans identité fiable retournant `31` avant toute modification ;
- test réel de transaction manuelle retournant `34` et traité correctement par
  systemd ;
- test réel `audit` non mutant ;
- exécution `guarded` réussie d'une mise à jour complète de 311 paquets avec
  code de sortie `0` ;
- redémarrage validé sur le nouveau noyau après cette mise à jour ;
- timer systemd validé `enabled` et `active`, service oneshot `inactive` au repos ;
- exécution automatique réelle via le timer systemd validée avec une transaction
  ordinaire de 10 mises à jour officielles terminée avec le code `0`.

## Validation v1.1.1

- test ciblé `test_foreign_packages_policy.sh` réussi ;
- suite complète : 46 tests réussis sur 46, 0 échec ;
- construction propre avec `makepkg --cleanbuild --check` ;
- paquet `smart-update 1.1.1-1` construit et installé sur machine réelle ;
- configuration locale conservée : `MODE="guarded"`,
  `ENABLE_AUR_UPDATES="no"`, `AUR_USER="mwalim_boro"` ;
- timer systemd conservé `enabled` et `active` après mise à niveau ;
- paquet publié avec SHA-256
  `bba0bda069f44d48497be52f52b2279e123afbef69fab9afa3d8212f4d2d28d8` ;
- release GitHub `v1.1.1` publiée avec le paquet et `SHA256SUMS`.

## Invariants de sécurité

- aucune politique n'installe directement de paquet ;
- aucune installation ne précède la décision finale ;
- une analyse transactionnelle invalide bloque le workflow ;
- une transaction nécessitant une décision Pacman est différée au lieu d'être
  acceptée globalement ;
- aucune suppression de verrou Pacman n'est automatisée ;
- aucun redémarrage, snapshot ou écrasement forcé n'est automatique ;
- les paquets AUR inconnus ne sont jamais modifiés automatiquement ;
- AUR est désactivé par défaut ;
- la configuration locale et les données d'exécution restent séparées du code ;
- les tags de release déjà utilisés ne sont pas déplacés.

## Prochaine étape

La branche `master` reste la base de développement après `v1.1.1`. Les nouvelles
fonctionnalités appartiendront à la prochaine version mineure ; une `v1.1.x`
restera réservée aux correctifs nécessaires de la ligne stable 1.1.
