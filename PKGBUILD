# Maintainer: Joshua Taillon <jat255 AT gmail DOT com>
_pkgname=restic-systemd-automatic-backup
pkgname=$_pkgname-git
pkgver=r44.bab7a8b
pkgrel=1
pkgdesc="A restic backup solution using systemd timers (or cron) and email notifications on failure."
arch=('any')
url="https://github.com/jat255/restic-systemd-automatic-backup"
license=('BSD')
depends=('restic' 'bash')
source=("$_pkgname::git+https://github.com/jat255/$_pkgname.git")
md5sums=('SKIP')

pkgver() {
    cd "$srcdir/$_pkgname"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/$_pkgname"
    make PREFIX="$pkgdir/" all
}