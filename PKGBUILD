# Maintainer: Matthew Wardrop <mister.wardrop@gmail.com>
pkgname=python2-parampy
pkgver=2.1.1
pkgrel=1
pkgdesc="A parameter manager that keeps track of physical (or numerical) quantities, and the relationships between them."
arch=('i686' 'x86_64')
url=""
license=('GPL')
groups=()
depends=('python2' 'python2-numpy' 'python2-sympy>=0.7.5' 'python2-scipy')
makedepends=()
provides=()
conflicts=()
replaces=()
backup=()
options=(!emptydirs)
install=
source=()
md5sums=()

package() {
  cd ".."
  #cd "$srcdir/$pkgname-$pkgver"
  python2 setup.py install --root="$pkgdir/" --optimize=1
}

# vim:set ts=2 sw=2 et:
