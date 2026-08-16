# Smart Update — Guide utilisateur

## Objectif

Smart Update analyse une transaction de mise à jour Arch Linux avant de décider
si son installation est acceptable. En mode `guarded`, il peut exécuter une
transaction autorisée. Il ne remplace pas Pacman et ne contourne jamais la
politique administrateur.

La configuration distribuée utilise par défaut :

```bash
MODE="audit"
ENABLE_AUR_UPDATES="no"
```

Le mode audit analyse et produit un rapport sans installer de paquet.

---

## Résultats principaux

Les résultats contrôlés les plus importants sont :

- `0` — `OK` : exécution normale ;
- `29` — `POLICY_BLOCK` : la politique a volontairement bloqué la transaction ;
- `34` — `MANUAL_TRANSACTION_REQUIRED` : la transaction nécessite une décision
  Pacman que Smart Update refuse volontairement d'automatiser.

Les codes `29` et `34` sont des résultats de sécurité contrôlés, pas des crashs.
Dans l'unité systemd, ils figurent dans `SuccessExitStatus`.

Les autres codes non nuls représentent une erreur technique, une incohérence ou
un résultat partiel nécessitant une investigation. Par exemple, `31` indique un
échec de découverte AUR ou de validation de l'identité AUR.

Voir [`../EXIT_CODES.md`](../EXIT_CODES.md) pour le contrat complet.

---

## Lancer Smart Update

```bash
sudo /usr/bin/smart-update
rc=$?
printf 'Smart Update exit code: %d\n' "$rc"
```

En mode `audit`, aucune installation n'est réalisée.

En mode `guarded`, une transaction ordinaire peut être installée uniquement si
les politiques et la capacité d'exécution l'autorisent.

---

## Comprendre la décision

Smart Update évalue notamment :

- le nombre de mises à jour ;
- la stabilité des candidats officiels ;
- les paquets critiques ;
- les paquets Foreign/AUR ;
- les annonces Arch Linux ;
- les suppressions prévues ;
- les remplacements ;
- les nouveaux paquets et nouvelles dépendances ;
- les questions interactives de transaction Pacman ;
- les dérives entre transaction analysée et transaction prête à exécuter ;
- la protection contre l'écrasement forcé de fichiers.

Le verdict final est :

- `ALLOW` : aucune politique ne s'oppose à la transaction ;
- `WARNING` : la transaction reste autorisable mais mérite une attention ;
- `BLOCK` : l'installation est interdite.

Un verdict `ALLOW` ou `WARNING` n'entraîne une installation que si `MODE="guarded"`
et si la transaction est considérée comme exécutable sans décision Pacman
interactive non autorisée.

---

## Configuration

Les fichiers système sont :

```text
/etc/smart-update/smart-update.conf
/etc/smart-update/critical-packages.conf
```

Modifier la configuration avec :

```bash
sudoedit /etc/smart-update/smart-update.conf
```

Valeurs de sécurité distribuées :

```bash
MODE="audit"
ENABLE_AUR_UPDATES="no"
AUR_HELPER="yay"
AUR_USER="auto"
ALLOW_CRITICAL_UPDATES="yes"
ALLOW_REMOVALS="no"
ALLOW_NEW_DEPENDENCIES="no"
ALLOW_REPLACEMENTS="no"
ALLOW_OVERWRITE="no"
MAX_UPDATE_COUNT=500
MIN_ROOT_FREE_MIB=4096
CHECK_ARCH_NEWS="yes"
ARCH_NEWS_LIMIT=10
AUTO_REBOOT="no"
AUTO_SNAPSHOT="no"
REPORT_RETENTION_DAYS=90
```

`ALLOW_CRITICAL_UPDATES="yes"` autorise une mise à jour critique uniquement si
elle passe d'abord les contrôles de stabilité. La politique critique renvoie
alors `WARNING`. Avec `no`, toute mise à jour critique devient `BLOCK`.

---

## Mode guarded

Activer explicitement :

```bash
MODE="guarded"
```

En mode guarded, Smart Update ne lance Pacman qu'après :

1. les contrôles système ;
2. l'analyse libalpm de la transaction ;
3. les politiques ;
4. la décision finale ;
5. la vérification des questions interactives ;
6. le contrôle final de dérive de transaction.

Une transaction qui nécessite une suppression conflictuelle, un remplacement,
un choix de fournisseur ou une autre décision Pacman sensible est différée et
retourne `34` au lieu d'être acceptée globalement.

Un `BLOCK` empêche toujours l'installation.

---

## Mises à jour AUR

AUR est désactivé par défaut :

```bash
ENABLE_AUR_UPDATES="no"
```

Pour une exécution manuelle sous `sudo`, la découverte AUR peut utiliser :

```bash
ENABLE_AUR_UPDATES="yes"
AUR_HELPER="yay"
AUR_USER="auto"
```

`auto` n'accepte qu'un `SUDO_USER` non-root valide provenant d'une invocation
manuelle de confiance.

Pour une exécution via systemd, il n'existe pas de `SUDO_USER` appelant fiable.
Si AUR est activé, configurer explicitement un utilisateur non-root :

```bash
ENABLE_AUR_UPDATES="yes"
AUR_USER="username"
```

Ne jamais utiliser `root` comme `AUR_USER` et ne pas créer de règle
`NOPASSWD: ALL` pour Smart Update.

Si AUR est activé mais que l'identité ne peut pas être résolue, Smart Update
retourne `31` avant toute transaction officielle.

### Limite de durcissement AUR en v1.1.0

Les commandes `yay` en lecture seule s'exécutent sous l'identité non-root
validée. Le chemin d'installation actuel est cependant encore lancé depuis
l'orchestrateur privilégié et s'appuie sur `yay` pour abandonner les privilèges
de compilation.

La v1.1.0 ne sépare donc pas encore complètement un builder AUR non-root d'un
installateur root minimal. L'automatisation AUR par timer ne doit pas être
présentée comme entièrement durcie.

Smart Update ne crée aucune règle sudoers, n'utilise pas `--sudoloop` et
n'active pas `--devel`.

---

## Logs et rapports

```text
/var/log/smart-update/smart-update.log
/var/log/smart-update/blocked.log
/var/log/smart-update/reports/
```

Les rapports contiennent notamment :

- informations système ;
- mises à jour détectées ;
- paquets critiques ;
- état Foreign/AUR ;
- décisions des politiques ;
- verdict final ;
- code de sortie public ;
- durée d'exécution.

Les rapports sont conservés selon `REPORT_RETENTION_DAYS`, 90 jours par défaut.

---

## Automatisation systemd

Activer le timer :

```bash
sudo systemctl enable --now smart-update.timer
```

Vérifier :

```bash
systemctl is-enabled smart-update.timer
systemctl is-active smart-update.timer
systemctl is-active smart-update.service
systemctl list-timers smart-update.timer --all
```

État normal au repos :

```text
enabled
active
inactive
```

Le service est `oneshot` : il reste normalement `inactive` entre deux
exécutions tandis que le timer reste actif.

Les codes `29` et `34` sont traités par systemd comme résultats contrôlés. Le
code `31` et les autres codes non nuls restent des échecs de service.

---

## Bonnes pratiques

- conserver `audit` jusqu'à comprendre les rapports ;
- passer à `guarded` uniquement après validation ;
- lire les annonces Arch Linux lorsqu'elles signalent une intervention manuelle ;
- examiner toute suppression, tout remplacement et toute nouvelle dépendance ;
- ne jamais supprimer `/var/lib/pacman/db.lck` sans vérifier qu'aucun gestionnaire
  de paquets n'est actif ;
- ne pas considérer `WARNING` comme synonyme de risque nul ;
- garder AUR désactivé pour l'automatisation officielle si le durcissement AUR
  actuel ne correspond pas au niveau de confiance souhaité.
