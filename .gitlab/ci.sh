#!/usr/bin/env bash

set -Eeuo pipefail

source "$CI_PROJECT_DIR/.gitlab/common.sh"


export GHCUP_INSTALL_BASE_PREFIX="$CI_PROJECT_DIR/toolchain"
export CABAL_DIR="$CI_PROJECT_DIR/cabal"

case "$(uname)" in
    MSYS_*|MINGW*)
        export CABAL_DIR="$(cygpath -w "$CABAL_DIR")"
		GHCUP_BINDIR="${GHCUP_INSTALL_BASE_PREFIX}/ghcup/bin"
        ;;
	*)
		GHCUP_BINDIR="${GHCUP_INSTALL_BASE_PREFIX}/.ghcup/bin"
		;;
esac

mkdir -p "$CABAL_DIR"
mkdir -p "$GHCUP_BINDIR"
export PATH="$GHCUP_BINDIR:$PATH"

export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
export BOOTSTRAP_HASKELL_GHC_VERSION=$GHC_VERSION
export BOOTSTRAP_HASKELL_CABAL_VERSION=$CABAL_INSTALL_VERSION
export BOOTSTRAP_HASKELL_VERBOSE=1
export BOOTSTRAP_HASKELL_ADJUST_CABAL_CONFIG=yes

curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# https://github.com/haskell/cabal/issues/7313#issuecomment-811851884
if [ "$(getconf LONG_BIT)" == "32" ] ; then
    echo 'constraints: lukko -ofd-locking' >> cabal.project.release.local
fi

args=(
    -w "ghc-$GHC_VERSION"
    --disable-profiling
    --enable-executable-stripping
    --project-file=cabal.project.release
    ${ADD_CABAL_ARGS}
)

run cabal v2-build ${args[@]} cabal-install

mkdir "$CI_PROJECT_DIR/out"
cp "$(cabal list-bin ${args[@]} cabal-install:exe:cabal)" "$CI_PROJECT_DIR/out/cabal"
cp dist-newstyle/cache/plan.json "$CI_PROJECT_DIR/out/plan.json"
cd "$CI_PROJECT_DIR/out/"

# create tarball/zip
TARBALL_PREFIX="cabal-install-$("$CI_PROJECT_DIR/out/cabal" --numeric-version)"
case "${TARBALL_EXT}" in
    zip)
        zip "${TARBALL_PREFIX}-${TARBALL_ARCHIVE_SUFFIX}.${TARBALL_EXT}" cabal plan.json
        ;;
    tar.xz)
        tar caf "${TARBALL_PREFIX}-${TARBALL_ARCHIVE_SUFFIX}.${TARBALL_EXT}" cabal plan.json
        ;;
    *)
        fail "Unknown TARBALL_EXT: ${TARBALL_EXT}"
        ;;
esac

rm cabal plan.json
