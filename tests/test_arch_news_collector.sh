#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/feed.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>Arch Linux News</title>

    <item>
      <title>Paquet test requires manual intervention</title>
      <link>https://archlinux.org/news/test-manual-intervention/</link>
      <description>&lt;p&gt;Une action &lt;strong&gt;manuelle&lt;/strong&gt; est requise avant la mise à jour.&lt;/p&gt;</description>
      <pubDate>Tue, 21 Jul 2026 13:01:46 +0000</pubDate>
      <guid isPermaLink="false">tag:archlinux.org,2026-07-21:/news/test-manual-intervention/</guid>
    </item>

    <item>
      <title>Deuxième annonce de test</title>
      <link>https://archlinux.org/news/second-test/</link>
      <description>&lt;p&gt;Description de la deuxième annonce.&lt;/p&gt;</description>
      <pubDate>Fri, 12 Jun 2026 18:41:28 +0000</pubDate>
      <guid isPermaLink="false">tag:archlinux.org,2026-06-12:/news/second-test/</guid>
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
export MOCK_ARCH_NEWS_FEED="$TEST_DIR/feed.xml"

# shellcheck source=lib/arch_news.sh
source "./lib/arch_news.sh"

arch_news_collect "https://example.test/feed.xml" 1

[[ -z "$ARCH_NEWS_ERROR" ]]
((${#ARCH_NEWS_GUIDS[@]} == 1))
((${#ARCH_NEWS_TITLES[@]} == 1))
((${#ARCH_NEWS_DATES[@]} == 1))
((${#ARCH_NEWS_LINKS[@]} == 1))
((${#ARCH_NEWS_DESCRIPTIONS[@]} == 1))

[[ "${ARCH_NEWS_TITLES[0]}" == "Paquet test requires manual intervention" ]]

[[ "${ARCH_NEWS_DESCRIPTIONS[0]}" == "Une action manuelle est requise avant la mise à jour." ]]

arch_news_collect "https://example.test/feed.xml" 2

((${#ARCH_NEWS_GUIDS[@]} == 2))
[[ "${ARCH_NEWS_TITLES[1]}" == "Deuxième annonce de test" ]]
[[ "${ARCH_NEWS_LINKS[1]}" == "https://archlinux.org/news/second-test/" ]]

export MOCK_CURL_FAIL="yes"

if arch_news_collect "https://example.test/feed.xml" 2; then
    printf 'Erreur : un échec de téléchargement a été accepté.\n' >&2
    exit 1
fi

[[ "$ARCH_NEWS_ERROR" == "Impossible de télécharger le flux Arch Linux." ]]

((${#ARCH_NEWS_GUIDS[@]} == 0))

printf 'Tous les tests du collecteur Arch News ont réussi.\n'
