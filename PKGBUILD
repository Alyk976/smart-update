# Maintainer: Mahadi Alykitra <Alyk976@users.noreply.github.com>

pkgname=smart-update-v2
pkgver=1.0.0rc1
pkgrel=1
pkgdesc="Deterministic policy-driven update decision engine for Arch Linux"
arch=('x86_64')
url="https://github.com/Alyk976/smart-update-v2"
license=('custom')
depends=('bash' 'pacman' 'pacman-contrib' 'libxml2' 'systemd')
makedepends=('gcc' 'git' 'make' 'pkgconf')
backup=('etc/smart-update/smart-update.conf'
        'etc/smart-update/critical-packages.conf')
source=("${pkgname}::git+ssh://git@github.com/Alyk976/smart-update-v2.git#commit=ce43053544e47c0e7cc1b2c81197706a27fda53a")
sha256sums=('SKIP')

build() {
    cd "$srcdir/$pkgname"
    make helper
}

check() {
    cd "$srcdir/$pkgname"
    ./tests/run_tests.sh
}

package() {
    cd "$srcdir/$pkgname"
    make DESTDIR="$pkgdir" install
}
