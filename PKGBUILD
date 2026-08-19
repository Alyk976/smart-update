# Maintainer: Mahadi Alykitra <Alyk976@users.noreply.github.com>

pkgname=smart-update
pkgver=1.1.1
pkgrel=1
pkgdesc="Deterministic policy-driven update decision engine for Arch Linux"
arch=('x86_64')
url="https://github.com/Alyk976/smart-update"
license=('Apache-2.0')
depends=('bash' 'pacman' 'pacman-contrib' 'libxml2' 'systemd')
optdepends=('logrotate: rotate Smart Update log files'
            'yay: update stable AUR packages')
makedepends=('gcc' 'git' 'make' 'pkgconf')
backup=('etc/smart-update/smart-update.conf'
        'etc/smart-update/critical-packages.conf')
source=("${pkgname}::git+https://github.com/Alyk976/smart-update.git#tag=v${pkgver}")
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

    # Runtime directories are owned by systemd-tmpfiles in the package.
    rm -rf "$pkgdir/var/lib/smart-update" "$pkgdir/var/log/smart-update"
    install -Dm644 packaging/smart-update.tmpfiles \
        "$pkgdir/usr/lib/tmpfiles.d/smart-update.conf"

}
