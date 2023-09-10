#! /bin/bash

# Find a suitable OS-level python interpreter
for p in python3.10 python3.9 python3 python; do
  if [ -n "$(which $p 2>/dev/null)" ]; then
    if $($p -c 'import sys; sys.exit(0) if sys.version_info.major == 3 and sys.version_info.minor == 9 else sys.exit(1)'); then
      PYTHON=$p
      PYZ=devkit-gui-cp39.pyz
      break
    fi
    if $($p -c 'import sys; sys.exit(0) if sys.version_info.major == 3 and sys.version_info.minor == 10 else sys.exit(1)'); then
      PYTHON=$p
      PYZ=devkit-gui-cp310.pyz
      break
    fi
  fi
done

# No suitable python found, check for a working pyenv
if [ -z "$PYTHON" ]; then
  if [ -n "$(which pyenv 2>/dev/null)" ]; then
    PYENV_VERSION="$(pyenv versions | grep -o '3\.10.*')"
    if [ -n "$PYENV_VERSION" ]; then
      export PYENV_VERSION="$PYENV_VERSION"
      PYTHON="pyenv exec python3.10"
      PYZ=devkit-gui-cp310.pyz
    else
      PYENV_VERSION="$(pyenv versions | grep -o '3\.9.*')"
      if [ -n "$PYENV_VERSION" ]; then
        export PYENV_VERSION="$PYENV_VERSION"
        PYTHON="pyenv exec python3.9"
        PYZ=devkit-gui-cp39.pyz
      fi
    fi


    if [ -z "$PYTHON" ]; then
      pyenv install -l | grep '^\s*(3\.\(9\|10\)'
      echo "pyenv installed but no python3.9 or python3.10 versions found"
      echo "Run 'pyenv install <version>' with a version listed above"
      exit 1
    fi
  fi
fi

if [ -z "$PYTHON" ]; then
  echo "No usable python found"
  echo "Please install python3.9, python3.10 or pyenv from your package manager"
  echo "e.g apt install python3.10"
  echo "    pacman -S pyenv"
  exit
fi

pushd "$(dirname "$0")/linux-client" > /dev/null
if [ -z "$DEVKIT_DEBUG" ]; then
  $PYTHON $PYZ &>/dev/null &
  disown %1
else
  $PYTHON $PYZ
fi
popd > /dev/null
