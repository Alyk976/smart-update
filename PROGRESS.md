# Smart Update — Suivi du projet

## État actuel

Version stable : `v1.1.0`

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
- timer systemd validé `enabled` et `active`, service oneshot `inactive` au repos.

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

La branche `master` reste la base de développement après `v1.1.0`. Les nouvelles
fonctionnalités appartiendront à la prochaine version mineure ; une `v1.1.x`
sera réservée aux correctifs nécessaires de la ligne stable 1.1.
