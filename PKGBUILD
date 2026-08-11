pkgname=smart-update-v2
pkgver=1.0.0rc1
pkgrel=1
pkgdesc="Deterministic policy-driven update decision engine for Arch Linux"
arch=('x86_64')
url="https://github.com/Alyk976/smart-update-v2"
license=('custom')
depends=('bash' 'pacman' 'pacman-contrib' 'libxml2' 'systemd')
makedepends=('gcc' 'make' 'pkgconf')
backup=('etc/smart-update/smart-update.conf'
        'etc/smart-update/critical-packages.conf')
source=()
sha256sums=()

build() {
    make helper
}

check() {
    ./tests/run_tests.sh
}

package() {
    make DESTDIR="$pkgdir" install
}
