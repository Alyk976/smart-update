#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin"

STATE_FILE="$TEST_DIR/arch-news.last"
FEED_FILE="$TEST_DIR/feed.xml"

cat >"$FEED_FILE" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>Arch Linux News</title>

    <item>
      <title>Nouvelle annonce</title>
      <link>https://archlinux.org/news/new/</link>
      <description>&lt;p&gt;Nouvelle information importante.&lt;/p&gt;</description>
      <pubDate>Sun, 02 Aug 2026 10:00:00 +0000</pubDate>
      <guid isPermaLink="false">guid-new</guid>
    </item>

    <item>
      <title>Ancienne annonce</title>
      <link>https://archlinux.org/news/old/</link>
      <description>&lt;p&gt;Ancienne information.&lt;/p&gt;</description>
      <pubDate>Sat, 01 Aug 2026 10:00:00 +0000</pubDate>
      <guid isPermaLink="false">guid-old</guid>
    </item>
  </channel>
</rss>
XML

cat >"$TEST_DIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash

if [[ "${MOCK_CURL_FAIL:-no}" == "yes" ]]; then
    exit 22
fi

output_file=""

while (($#)); do
    case "$1" in
        --output)
            output_file="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$output_file" ]]; then
    exit 1
fi

cp "$MOCK_ARCH_NEWS_FEED" "$output_file"
MOCK

chmod +x "$TEST_DIR/bin/curl"

export PATH="$TEST_DIR/bin:$PATH"
export MOCK_ARCH_NEWS_FEED="$FEED_FILE"

# shellcheck source=lib/arch_news_context.sh
source "./lib/arch_news_context.sh"

# Fonction désactivée
arch_news_prepare \
    "no" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "DISABLED" ]]
[[ -z "$ARCH_NEWS_CONTEXT_ERROR" ]]

# Première exécution : les deux annonces sont nouvelles
arch_news_prepare \
    "yes" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "NEW" ]]
[[ "$ARCH_NEWS_LATEST_GUID" == "guid-new" ]]
((${#ARCH_NEWS_NEW_INDEXES[@]} == 2))

# La dernière annonce est déjà connue
arch_news_state_save "$STATE_FILE" "guid-new"

arch_news_prepare \
    "yes" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "UP_TO_DATE" ]]
((${#ARCH_NEWS_NEW_INDEXES[@]} == 0))

# Une annonce plus récente existe
arch_news_state_save "$STATE_FILE" "guid-old"

arch_news_prepare \
    "yes" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "NEW" ]]
((${#ARCH_NEWS_NEW_INDEXES[@]} == 1))
[[ "${ARCH_NEWS_NEW_INDEXES[0]}" == "0" ]]

# Le GUID enregistré est absent du flux
arch_news_state_save "$STATE_FILE" "guid-unknown"

if arch_news_prepare \
    "yes" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"; then

    printf "Erreur : un GUID inconnu a été accepté.\n" >&2
    exit 1
fi

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "ERROR" ]]
[[ "$ARCH_NEWS_CONTEXT_ERROR" == "Le dernier GUID consulté est absent du flux collecté." ]]

# Le téléchargement échoue
export MOCK_CURL_FAIL="yes"

if arch_news_prepare \
    "yes" \
    "https://example.test/feed.xml" \
    2 \
    "$STATE_FILE"; then

    printf "Erreur : un téléchargement défaillant a été accepté.\n" >&2
    exit 1
fi

[[ "$ARCH_NEWS_CONTEXT_STATUS" == "ERROR" ]]
[[ "$ARCH_NEWS_CONTEXT_ERROR" == "Impossible de télécharger le flux Arch Linux." ]]

printf "Tous les tests du contexte Arch News ont réussi.\n"
