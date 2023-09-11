#! /bin/bash

# verbose 
#set -x

set -o pipefail
shopt -s failglob
set -u

me="$(readlink -f "$0")"
here="${me%/*}"
me="${me##*/}"

log () {
    echo "${me}[$$]: $*" >&2 || :
}

if [ -n "${STEAM_RUNTIME-}" ]; then
    log 'Undo steam runtime to avoid interference'
    log "${STEAM_RUNTIME}/scripts/switch-runtime.sh" --runtime="" -- "$0" "$@"
    exec "${STEAM_RUNTIME}/scripts/switch-runtime.sh" --runtime="" -- "$0" "$@"
fi

# Find a suitable OS-level python interpreter
for p in python3.11 python3.10 python3.9 python3 python; do
  if [ -n "$(which $p 2>/dev/null)" ]; then
    if $($p -c 'import sys; sys.exit(0) if sys.version_info.major == 3 and sys.version_info.minor == 11 else sys.exit(1)'); then
      PYTHON=$p
      PYZ=devkit-gui-cp311.pyz
      break
    fi
    if $($p -c 'import sys; sys.exit(0) if sys.version_info.major == 3 and sys.version_info.minor == 10 else sys.exit(1)'); then
      PYTHON=$p
      PYZ=devkit-gui-cp310.pyz
      break
    fi
    if $($p -c 'import sys; sys.exit(0) if sys.version_info.major == 3 and sys.version_info.minor == 9 else sys.exit(1)'); then
      PYTHON=$p
      PYZ=devkit-gui-cp39.pyz
      break
    fi
  fi
done

# No suitable python found, check for a working pyenv
if [ -z "${PYTHON-}" ]; then
  if [ -n "$(which pyenv 2>/dev/null)" ]; then
    PYENV_VERSION="$(pyenv versions | grep -o '3\.11.*')"
    if [ -n "${PYENV_VERSION-}" ]; then
      export PYENV_VERSION="$PYENV_VERSION"
      PYTHON="pyenv exec python3.11"
      PYZ=devkit-gui-cp311.pyz
    else
      PYENV_VERSION="$(pyenv versions | grep -o '3\.10.*')"
      if [ -n "${PYENV_VERSION-}" ]; then
        export PYENV_VERSION="$PYENV_VERSION"
        PYTHON="pyenv exec python3.10"
        PYZ=devkit-gui-cp310.pyz
      else
        PYENV_VERSION="$(pyenv versions | grep -o '3\.9.*')"
        if [ -n "${PYENV_VERSION-}" ]; then
          export PYENV_VERSION="$PYENV_VERSION"
          PYTHON="pyenv exec python3.9"
          PYZ=devkit-gui-cp39.pyz
        fi
      fi
    fi

    if [ -z "${PYTHON-}" ]; then
      pyenv versions | grep '^\s*3\.\(11\|10\|9\)'
      log "pyenv installed but no python 3.11, 3.10 or 3.9 versions found"
      log "Run 'pyenv install <version>' with a version listed above"
      exit 1
    fi
  fi
fi

if [ -z "${PYTHON-}" ]; then
  log "No usable python found"
  log "Please install python 3.11, 3.10 or 3.9 from your package manager or via pyenv"
  log "e.g apt install python3.11"
  log "    pacman -S pyenv"
  exit
fi

pushd "$(dirname "$0")/linux-client" > /dev/null
if [ -z "${DEVKIT_DEBUG-}" ]; then
  $PYTHON $PYZ &>/dev/null &
  disown %1
else
  $PYTHON $PYZ
fi
popd > /dev/null
