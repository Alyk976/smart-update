# Maintainer: Mahadi Alykitra <Alyk976@users.noreply.github.com>

pkgname=smart-update-v2
pkgver=1.0.0rc1
pkgrel=1
pkgdesc="Deterministic policy-driven update decision engine for Arch Linux"
arch=('x86_64')
url="https://github.com/Alyk976/smart-update-v2"
license=('LicenseRef-Smart-Update-RC')
depends=('bash' 'pacman' 'pacman-contrib' 'libxml2' 'systemd')
makedepends=('gcc' 'git' 'make' 'pkgconf')
backup=('etc/smart-update/smart-update.conf'
        'etc/smart-update/critical-packages.conf')
source=("${pkgname}::git+ssh://git@github.com/Alyk976/smart-update-v2.git#commit=508a58b7baa8ef65fae272dc9579d46151789a44")
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

    install -Dm644 LICENSE \
        "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
