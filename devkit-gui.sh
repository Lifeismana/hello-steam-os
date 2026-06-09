#! /bin/bash

# verbose
#export PS4='${LINENO}: '
#set -x

set -uo pipefail
shopt -s failglob

SUPPORTED_PYTHON_VERSIONS=(14 13 12 11)

PYTHON_BINARIES=()
PYTHON_VERSIONS_LIST=""
for v in "${SUPPORTED_PYTHON_VERSIONS[@]}"; do
  PYTHON_BINARIES+=("python3.$v")
  if [ -z "$PYTHON_VERSIONS_LIST" ]; then
    PYTHON_VERSIONS_LIST="3.$v"
  else
    PYTHON_VERSIONS_LIST="$PYTHON_VERSIONS_LIST, 3.$v"
  fi
done
PYTHON_BINARIES+=(python3 python)
PYTHON_VERSIONS_LIST=$(echo "$PYTHON_VERSIONS_LIST" | sed 's/\(.*\), /\1 or /')
PYTHON_GREP_PATTERN=$(IFS='|'; echo "${SUPPORTED_PYTHON_VERSIONS[*]}")

me=$(basename "$(readlink -f "$0")")
log () {
    echo "${me}[$$]: $*" >&2 || :
}

# There's no good way to show an error dialog in a portable way from shell on Linux...
show_error() {
    local message="$1"
    local title="${2:-Error}"

    echo "ERROR: $message" >&2

    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || [[ "$DESKTOP_SESSION" == *"kde"* ]] || [[ "$DESKTOP_SESSION" == *"plasma"* ]]; then
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --error "$message" --title "$title"
            return 0
        fi
    fi

    if command -v zenity >/dev/null 2>&1; then
        zenity --error --text="$message" --title="$title"
        return 0
    fi

    # Is not modal, which is not ideal, but a fallback that should be broadly available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "$title" "$message"
        return 0
    fi

    return 1
}

if [ -n "${STEAM_RUNTIME-}" ]; then
  # The devkit tool is setup to run at host level, possibly started from the CLI
  # The tool expects a suitable version of python installed
  if [ -n "${SRT_LAUNCHER_SERVICE_ALONGSIDE_STEAM-}" ]; then
    log 'Running in SLR environment, relaunching at host level'
    log "${STEAM_RUNTIME}/amd64/usr/bin/steam-runtime-launch-client" --alongside-steam --host -- "$0" "$@"
    exec "${STEAM_RUNTIME}/amd64/usr/bin/steam-runtime-launch-client" --alongside-steam --host -- "$0" "$@"
    # unreachable
  fi
  log 'Running in LDLP environment, relaunching with runtime disabled'
  log "${STEAM_RUNTIME}/scripts/switch-runtime.sh" --runtime="" -- "$0" "$@"
  exec "${STEAM_RUNTIME}/scripts/switch-runtime.sh" --runtime="" -- "$0" "$@"
  # unreachable
fi

# Find a suitable OS-level python interpreter
for p in "${PYTHON_BINARIES[@]}"; do
  if which "$p" &>/dev/null; then
    VERS=$("$p" 2>/dev/null -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    for v in "${SUPPORTED_PYTHON_VERSIONS[@]}"; do
      if [ "$VERS" == "3.$v" ]; then
        PYTHON=( "$p" )
        PYZ=devkit-gui-cp3${v}.pyz
        break 2
      fi
    done
  fi
done

# No suitable python found, check for a working pyenv
if [ -z "${PYTHON-}" ]; then
  if which pyenv >/dev/null; then
    for v in "${SUPPORTED_PYTHON_VERSIONS[@]}"; do
      PYENV_VERSION=$(pyenv versions | grep -o -m1 "3\.${v}\.[0-9]*")
      if [ -n "${PYENV_VERSION-}" ]; then
        export PYENV_VERSION
        PYTHON=( pyenv exec "python3.${v}" )
        PYZ=devkit-gui-cp3${v}.pyz
        break
      fi
    done

    if [ -z "${PYTHON-}" ]; then
      pyenv versions | grep "^\s*3\.\(${PYTHON_GREP_PATTERN}\)"
      show_error "pyenv installed but no python ${PYTHON_VERSIONS_LIST} versions found\n"\
"Run 'pyenv install <version>' with a version listed above" \
                 "No usable python found"
      exit 1
    fi
  fi
fi

if [ -z "${PYTHON-}" ]; then
  show_error "Please install python ${PYTHON_VERSIONS_LIST} from your package manager or via pyenv\n"\
"e.g apt install python3\n"\
"    pacman -S pyenv" \
    "No usable python found"
  exit 1
fi

pushd "$(dirname "$0")/linux-client" > /dev/null || exit 1
if [ -z "${DEVKIT_DEBUG-}" ]; then
  log "${PYTHON[@]}" "$PYZ" "$@"
  "${PYTHON[@]}" "$PYZ" "$@" &>/dev/null &
  disown %1
else
  log "${PYTHON[@]}" "$PYZ" "$@"
  "${PYTHON[@]}" "$PYZ" "$@"
fi
popd > /dev/null || exit 1
