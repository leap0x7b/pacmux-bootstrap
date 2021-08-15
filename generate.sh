PACMUX_ARCH="aarch64"
PACMUX_PREFIX="/data/data/com.pacmux/files"
PACMUX_BOOTSTRAP_BUILDDIR="$(pwd)/build"
PACMUX_BOOTSTRAP_ROOTFSDIR="$PACMUX_BOOTSTRAP_BUILDDIR/rootfs"
PACMUX_BOOTSTRAP_PREFIXDIR="$PACMUX_BOOTSTRAP_ROOTFSDIR/$PACMUX_PREFIX"

print() {
	echo -e " \033[1;34m-->\033[0m $@"
}

print2() {
	echo -e "  \033[1;34m->\033[0m $@"
}

download() {
	mkdir -p $PACMUX_BOOTSTRAP_BUILDDIR
	cd $PACMUX_BOOTSTRAP_BUILDDIR
	print "Downloading package repository"
	# Installing an archive with these packages.
	wget https://github.com/Maxython/arch-packages-for-termux/releases/download/packages-v2021.08.10/packages-${PACMUX_ARCH}.tar.xz
	tar xJf packages-${PACMUX_ARCH}.tar.xz
}

package() {
	mkdir -p $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local
	cd $PACMUX_BOOTSTRAP_PREFIXDIR
	for i in "$PACMUX_BOOTSTRAP_BUILDDIR/packages"/*.pkg.tar.xz; do
		PACKAGE_TMP=$(basename $i .pkg.tar.xz)
		PACKAGE=${PACKAGE_TMP%-*}
		print "Installing $PACKAGE..."
		tar xJf $i
		source <(tar xJOf $i .PKGINFO | sed -n -E "/^\[.*\]/{s/\[(.*)\]/\1/;h;n;};/^[a-zA-Z]/{s/#.*//;G;s/([^ ]*) *= *(.*)\n(.*)/\3\1+=('\2')/;p;}")
		mkdir -p $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE
		# Placeholder values are filled for zlib and termux-commands
		cat << EOF > $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE/desc | perl -pe 'chomp if eof'
%NAME%
${pkgname}

%VERSION%
${pkgver}

%BASE%
${pkgbase}

%DESC%
${pkgdesc:-"Compression library implementing the deflate compression method found in gzip and PKZIP"}

%URL%
${url:-"https://termux.com"}

%ARCH%
${arch}

%BUILDDATE%
${builddate}

%INSTALLDATE%
$(date +%s)

%PACKAGER%
${packager}

%SIZE%
${size}

%LICENSE%
$(for i in ${license[@]}; do
	echo "$i"
done)

%VALIDATION%
$(if [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "sha256sum" ]]; then
	echo "sha256"
elif [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "sha224sum" ]]; then
	echo "sha224"
elif [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "sha384sum" ]]; then
	echo "sha384"
elif [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "sha512sum" ]]; then
	echo "sha512"
elif [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "sha1sum" ]]; then
	echo "sha1"
elif [[ `tar xJOf $i .BUILDINFO | grep pkgbuild` =~ "md5sum" ]]; then
	echo "md5"
fi)

$(if [[ ! -z ${depend} ]]; then
	echo %DEPENDS%
	for i in ${depend[@]}; do
		echo $i
	done
fi)
$(if [[ ! -z ${optdepend} ]]; then
	echo
	echo %OPTDEPENDS%
	for i in ${optdepend[@]}; do
		echo $i
	done
fi)

EOF
		tar xJOf $i .MTREE > $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE/mtree
		if tar tJf $i | grep -F .INSTALL &>/dev/null; then
			tar xJOf $i .INSTALL > $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE/install
			cat << EOF > $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE/files
%FILES%
$(tar tJf $i | sed -e '1,4d')
EOF
		else
			cat << EOF > $PACMUX_BOOTSTRAP_PREFIXDIR/usr/var/lib/pacman/local/$PACKAGE/files
%FILES%
$(tar tJf $i | sed -e '1,3d')
EOF
		fi
		unset pkgname pkgver pkgbase pkgdesc url builddate packager size license depend optdepend
	done
}

generate() {
	cd $PACMUX_BOOTSTRAP_BUILDDIR
	print "Generating rootfs"
	tar cJf rootfs.tar.xz -C $PACMUX_BOOTSTRAP_ROOTFSDIR $PACMUX_BOOTSTRAP_ROOTFSDIR
}

download
package
generate
