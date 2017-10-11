#!/bin/bash

PN="binutils"
PV=$1
pver=$2

if [[ -z ${PV} ]] ; then
	echo "Usage: $0 binutils-version patchset-version-to-be-created"
	echo "Please read the script before trying to use it :)"
	exit 1
fi

# check that we're in the root of a binutils-gdb git repo

if [[ ! -f COPYING.LIBGLOSS ]] || [[ ! -d .git ]] ; then
	echo "Error: You need to call this script in the main directory of a Gentoo binutils-gdb git clone"
	exit 1
fi

# check that we're on a branch gentoo/${PV}

mybranchinfo=$(git status --porcelain -b|grep '^##')
mybranch=$(echo ${mybranchinfo}|sed -e 's:^## ::' -e 's:\.\.\..*$::')
if [[ ! "gentoo/binutils-${PV}" == "${mybranch}" ]] ; then
	echo "Error: Your git repository is on the incorrect branch ${mybranch}; should be gentoo/binutils-${PV}"
	exit 1
fi

# check that the working directory is clean

mystatusinfo=$(git status --porcelain)
if [[ ! -z "${mystatusinfo}" ]] ; then
	echo "Error: Your working directory is not clean"
	exit 1
fi

# check if the tag already exists

mytaginfo=$(git tag -l|grep "gentoo/binutils-${PV}-${pver}")
if [[ ! -z "${mytaginfo}" ]] ; then
	echo "Error: A tag corresponding to this patch level already exists (gentoo/binutils-${PV}-${pver})"
	exit 1
fi

# luckily binutils git has no /tmp dir and no tar.xz files, but let's better check and be pathologically careful

if [[ -e tmp ]] || [[ -e ${PN}-${PV}-patches-${pver}.tar.xz ]] ; then
	echo "Error: tmp or ${PN}-${PV}-patches-${pver}.tar.xz exists in git"
	exit 1
fi
rm -rf tmp
rm -f ${PN}-${PV}-*.tar.bz2

for myname in 0*.patch ; do
	if [[ -e "${myname}" ]]; then
		echo "Error: ${myname} exists in git"
		exit 1
	fi
done
rm -f 0*.patch

# check if we have to override the upstream tag

mytaginfo=$(git tag -l|grep "gentoo/binutils-${PV}-upstream")
if [[ ! -z "${mytaginfo}" ]] ; then
	starttag="gentoo/binutils-${PV}-upstream"
else
	starttag="binutils-${PV//./_}"
fi
if [[ "${PV}" == "9999" ]]; then
	starttag="master"
fi
echo "Starting from tag ${starttag}"

mkdir -p tmp/patch

# copy README.Gentoo.patches

cp scripts/gentoo/README.Gentoo.patches tmp/ || exit 1

# create and rename patches

git format-patch ${starttag}..HEAD > /dev/null || exit 1

# remove all patches where the summary line starts with:
# - [no-tarball]: not related to upstream tarball
# - [no-patch]: not related to upstream patches
# - "Automatic date update in version.in": daily bumps
rm -f 0???-no-tarball-*.patch
rm -f 0???-no-patch-*.patch
rm -f 0???-Automatic-date-update-in-version.in.patch

for myname in 0*.patch ; do
	mv ${myname} tmp/patch/ || exit 1
done

# add the extra patch if needed

if [[ "${PV}" != "9999" ]]; then
	cp scripts/gentoo/0000-Gentoo-Git-is-development tmp/patch/0000-Gentoo-Git-is-development.patch || exit 1
	cp scripts/gentoo/9999-Gentoo-We-make-a-release tmp/patch/9999-Gentoo-We-make-a-release.patch || exit 1
fi

# add a history file

git log --stat --decorate ${starttag}..HEAD > tmp/patch/README.history || exit 1

# package everything up

tar -Jcf ${PN}-${PV}-patches-${pver}.tar.xz \
	-C tmp patch README.Gentoo.patches || exit 1
rm -r tmp

du -b *.tar.xz

# tag the commit

git tag -s -m "Gentoo patchset binutils-${PV}-${pver}" "gentoo/binutils-${PV}-${pver}"
