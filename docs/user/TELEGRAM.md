# Notifications Telegram (développement v1.2)

Option désactivée par défaut, compatible avec les anciens fichiers de configuration.
Une seule tentative à la sortie de chaque exécution ayant créé un rapport, en
mode audit comme guarded : machine, mode, décision, code de sortie, résultats
Official et AUR. Le code de sortie distingue notamment un blocage de politique
d'une erreur d'exécution. Le rapport local reste la source des détails.

Les erreurs précédant la création du rapport (configuration invalide, instance
déjà active), SIGKILL et coupures de courant ne peuvent pas être notifiées ici.
Une panne Telegram n'altère ni les politiques ni le résultat de Smart Update.
La livraison peut ajouter au maximum 15 secondes ; aucun retry automatique.

## Configuration sur Arch Linux

Installer `jq` (`sudo pacman -S --needed jq`). Créer un bot avec BotFather,
ouvrir sa conversation et envoyer `/start`. Relever le **chat.id numérique**
dans `getUpdates` : le nom du bot n'est pas le Chat ID de cette conversation.
Documentation : https://core.telegram.org/bots/api#sendmessage

Dans un shell root, enregistrer le token sans l'inscrire dans l'historique :

```bash
install -d -m 750 /etc/smart-update
( set +x
  umask 077
  read -rsp 'Bot Token : ' token
  echo
  printf '%s\n' "$token" > /etc/smart-update/telegram.token
  chmod 600 /etc/smart-update/telegram.token
)
```

Le fichier doit appartenir à root, avoir le mode 600 et contenir uniquement
le token brut (pas de `TOKEN=`, guillemets ou commande shell).
Ne jamais le committer ni partager son contenu.

Dans `/etc/smart-update/smart-update.conf` :

```bash
TELEGRAM_ENABLED="yes"
TELEGRAM_CHAT_ID="REMPLACER_PAR_ID_NUMERIQUE"
TELEGRAM_TOKEN_FILE="/etc/smart-update/telegram.token"
```

Une exécution normale en mode audit permet de vérifier l'intégration sans
installer de mises à jour. Ce n'est pas une commande de test sur Debian/OMV :
Smart Update reste un outil Arch Linux. Les tests automatisés simulent Telegram
et n'envoient aucun message. Ne pas transmettre de vrai token aux tests.

Les erreurs de livraison produisent uniquement un avertissement générique dans
le journal. Le token, la réponse Telegram et le rapport complet ne sont pas
journalisés par ce module. Le message transmet le nom de la machine à Telegram.
