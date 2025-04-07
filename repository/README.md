# Local Repository for Builds

This repository contains custom packages for use with the build system. It allows you to maintain and distribute your own packages alongside those from official repositories.

## Setup

Run the setup script to create the repository structure:

```bash
chmod +x /usr/local/bin/setup-local-repo.sh
/usr/local/bin/setup-local-repo.sh
```

## Building Packages with Makepkg

1. Create a new package:

```bash
mkdir -p ~/builds/my-package
cd ~/builds/my-package
```

2. Create a PKGBUILD file. Here's a basic template:

```bash
# Maintainer: Your Name <your.email@example.com>
pkgname=my-package
pkgver=1.0.0
pkgrel=1
pkgdesc="Description of my package"
arch=('x86_64')
url="https://example.com"
license=('GPL')
depends=('dependency1' 'dependency2')
makedepends=('make' 'gcc')
source=("$pkgname-$pkgver.tar.gz::https://example.com/$pkgname-$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
  cd "$pkgname-$pkgver"
  ./configure --prefix=/usr
  make
}

package() {
  cd "$pkgname-$pkgver"
  make DESTDIR="$pkgdir/" install
}
```

3. Build the package:

```bash
makepkg -si
```

## Adding Packages to the Repository

After building your package, add it to the repository:

```bash
repo-add /var/cache/pacman/syncopated/syncopated.db.tar.gz ~/builds/my-package/*.pkg.tar.zst
```

## Updating the Package Database

After adding packages, update your package database:

```bash
sudo pacman -Sy
```

## Installing Packages from Your Repository

Install packages from your repository:

```bash
sudo pacman -S my-package
```

## Maintaining the Repository

To update a package:

1. Update the PKGBUILD (increment `pkgver` or `pkgrel`)
2. Rebuild the package
3. Add the new package to the repository
4. Remove the old package version if desired

## Integration with Build System

This repository can be used with the build system by including it in the pacman.conf file of your ISO build:

```conf
[syncopated]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/syncopated
```

For CI/CD environments, you may need to copy the repository to the build environment or host it on a web server.
