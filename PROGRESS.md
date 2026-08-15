# Smart Update — Suivi du projet

## État actuel

Version : `v1.0.0`

Smart Update est prêt pour sa première version stable. Le moteur analyse les
mises à jour Arch Linux, prépare un contexte de transaction libalpm, exécute les
politiques et applique une décision finale avant toute installation.

## Fonctionnalités livrées

- modes `audit` et `guarded` ;
- décisions déterministes `ALLOW`, `WARNING` et `BLOCK` ;
- barrière centrale interdisant l’installation après un `BLOCK` ;
- contrôles système, verrou d’instance et gestion explicite des codes de sortie ;
- suivi des annonces Arch Linux avec état persistant atomique ;
- détection des paquets critiques et étrangers/AUR ;
- détection libalpm des suppressions, remplacements et ajouts transactionnels ;
- identification des nouveaux paquets et dépendances par comparaison avec la
  base locale installée ;
- journaux structurés et rapports finalisés de manière idempotente ;
- rétention des rapports pendant 90 jours ;
- rotation optionnelle des journaux avec logrotate ;
- service et timer systemd, ainsi que création des répertoires par tmpfiles ;
- paquet Arch natif et installation validée sur une machine réelle.

## Validation v1.0.0

- 33 tests automatisés ;
- validation `bash -n` et ShellCheck ;
- validation des unités avec `systemd-analyze verify` ;
- construction propre avec `makepkg --cleanbuild --syncdeps --check` ;
- analyse `namcap` du `PKGBUILD` et du paquet ;
- intégrité du paquet installé vérifiée par Pacman ;
- audit réel retournant le blocage politique contrôlé `29` ;
- configuration logrotate validée sans rotation réelle.

## Invariants de sécurité

- aucune politique n’installe directement de paquet ;
- aucune installation ne précède la décision finale ;
- une analyse transactionnelle invalide bloque le workflow ;
- aucune suppression de verrou Pacman n’est automatisée ;
- aucun redémarrage, snapshot ou écrasement forcé n’est automatique ;
- la configuration locale et les données d’exécution restent séparées du code.

## Étape de release

La préparation restante est opérationnelle : commit des métadonnées et de la
documentation finales, mise à jour séparée du pin source, renommage du dépôt
distant, construction reproductible finale, puis création du tag `v1.0.0`.
