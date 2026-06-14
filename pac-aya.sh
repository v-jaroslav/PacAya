pac() {
  case "$1" in
  install)
    shift
    sudo /usr/bin/pacman -S "$@"
    ;;
  remove)
    shift
    sudo /usr/bin/pacman -Rcns "$@"
    ;;
  remove-orphans)
    if [ -n "$(/usr/bin/pacman -Qdtq)" ]; then
      /usr/bin/pacman -Qdtq | xargs sudo /usr/bin/pacman -Rcns
    else
      echo "No orphan packages to remove."
    fi
    ;;
  update)
    sudo /usr/bin/pacman -Syu
    ;;
  search)
    shift
    /usr/bin/pacman -Ss "$@"
    ;;
  remote-info)
    shift
    /usr/bin/pacman -Si "$@"
    ;;
  local-info)
    shift
    /usr/bin/pacman -Qi "$@"
    ;;
  list-all)
    /usr/bin/pacman -Q
    ;;
  list-explicit)
    /usr/bin/pacman -Qe
    ;;
  list-orphans)
    /usr/bin/pacman -Qdt
    ;;
  owns)
    shift
    /usr/bin/pacman -Qo "$@"
    ;;
  files)
    shift
    /usr/bin/pacman -Ql "$@"
    ;;
  clean)
    sudo /usr/bin/pacman -Sc
    ;;
  clean-all)
    sudo /usr/bin/pacman -Scc
    ;;
  help | *)
    echo "pac install <pkg>      → sudo pacman -S                       Install a package"
    echo "pac remove <pkg>       → sudo pacman -Rcns                    Remove package + deps + config"
    echo "pac remove-orphans     → sudo pacman -Rcns \$(pacman -Qdtq)    Remove all orphans"
    echo "pac update             → sudo pacman -Syu                     Sync & upgrade all"
    echo ""
    echo "pac search <term>      → pacman -Ss                           Search repos"
    echo "pac remote-info <pkg>  → pacman -Si                           Show repo package info"
    echo "pac local-info <pkg>   → pacman -Qi                           Show installed package info"
    echo ""
    echo "pac list-all           → pacman -Q                            List all installed"
    echo "pac list-explicit      → pacman -Qe                           List explicitly installed"
    echo "pac list-orphans       → pacman -Qdt                          List orphaned packages"
    echo ""
    echo "pac owns <file>        → pacman -Qo                           Which package owns a file"
    echo "pac files <pkg>        → pacman -Ql                           List files from a package"
    echo ""
    echo "pac clean              → sudo pacman -Sc                      Clean old cache"
    echo "pac clean-all          → sudo pacman -Scc                     Wipe entire cache"
    ;;
  esac
}

_AYA_DIR="$HOME/.aya"
_AYA_CACHE="$_AYA_DIR/maintainers"

_aya_warn() { echo -e "\e[33m$*\e[0m"; }
_aya_error() { echo -e "\e[31m$*\e[0m"; }

_aya_is_from_official_repo() {
  ! yay -Si "$1" 2>/dev/null | grep -q '^Repository.*: aur'
}

_aya_get_remote_maintainer() {
  yay -Si "$1" 2>/dev/null | awk -F': ' '/^Maintainer/ { print $2 }' | xargs
}

_aya_get_cached_maintainer() {
  [[ -f "$_AYA_CACHE" ]] && awk -F'|' -v pkg="$1" '$1 == pkg { print $2; exit }' "$_AYA_CACHE" 2>/dev/null
}

_aya_cache_write() {
  mkdir -p "$_AYA_DIR"
  touch "$_AYA_CACHE"

  local pkg="$1" maintainer="$2"
  local tmp_cache=$(mktemp)
  awk -F'|' -v pkg="$pkg" '$1 != pkg' "$_AYA_CACHE" >"$tmp_cache" 2>/dev/null && mv "$tmp_cache" "$_AYA_CACHE"
  echo "$pkg|$maintainer" >>"$_AYA_CACHE"
}

_aya_cache_remove() {
  if [[ -f "$_AYA_CACHE" ]]; then
    local tmp_cache=$(mktemp)
    awk -F'|' -v pkg="$1" '$1 != pkg' "$_AYA_CACHE" >"$tmp_cache" 2>/dev/null && mv "$tmp_cache" "$_AYA_CACHE"
  fi
}

_aya_install() {
  local pkg maintainer
  local -a safe=() risky=() maintainers=()

  for pkg in "$@"; do
    if _aya_is_from_official_repo $pkg; then
      continue
    fi

    maintainer=$(_aya_get_remote_maintainer "$pkg")
    if [[ -z "$maintainer" || "$maintainer" == "None" ]]; then
      risky+=("$pkg")
    else
      safe+=("$pkg")
      maintainers+=("$maintainer")
    fi
  done

  if [[ ${#risky[@]} -gt 0 ]]; then
    _aya_error "Install halted. The following packages are orphaned (they don't have maintainer):"
    for pkg in "${risky[@]}"; do
      _aya_error "  • $pkg"
    done
    echo ""
    echo "  To install them anyway (NOT recommended): run 'yay -S <pkgname>' directly."
    return 1
  fi

  /usr/bin/yay -S "${safe[@]}" || return $?

  local i
  for ((i = 0; i < ${#safe[@]}; i++)); do
    _aya_cache_write "${safe[i]}" "${maintainers[i]}"
  done
}

_aya_remove() {
  local pkg
  /usr/bin/yay -Rcns "$@" || return $?
  for pkg in "$@"; do
    _aya_cache_remove "$pkg"
  done
}

_aya_update() {
  echo "==> Checking AUR packages for maintainer changes or orphaning..."

  local pkg remote_maintainer cached_maintainer reason
  local -a safe=() suspicious=() maintainers=()

  while IFS= read -r pkg; do
    remote_maintainer=$(_aya_get_remote_maintainer "$pkg")
    reason=""

    if [[ -z "$remote_maintainer" || "$remote_maintainer" == "None" ]]; then
      reason="orphaned (no maintainer)"
    else
      cached_maintainer=$(_aya_get_cached_maintainer "$pkg")
      if [[ -n "$cached_maintainer" && "$cached_maintainer" != "$remote_maintainer" ]]; then
        reason="maintainer changed: was '$cached_maintainer' → now '$remote_maintainer'"
      fi
    fi

    if [[ -n "$reason" ]]; then
      suspicious+=("$pkg|$reason")
    else
      safe+=("$pkg")
      maintainers+=("$remote_maintainer")
    fi
  done < <(/usr/bin/yay -Qmq)

  if [[ ${#suspicious[@]} -gt 0 ]]; then
    _aya_error "Warning. The following AUR packages may have been compromised. The update is halted!"
    local entry
    for entry in "${suspicious[@]}"; do
      _aya_error "  • ${entry%%|*} - ${entry##*|}"
    done
    echo ""
    echo "  To update things anyway (NOT recommended): run 'yay -Syu' directly."
    return 1
  fi

  echo "==> All AUR packages look okay. Proceeding with update..."
  /usr/bin/yay -Syu || return $?

  local i
  for ((i = 0; i < ${#safe[@]}; i++)); do
    if [[ -n "${maintainers[i]}" ]]; then
      _aya_cache_write "${safe[i]}" "${maintainers[i]}"
    fi
  done
}

_aya_remove_orphans() {
  local orphans
  orphans=$(/usr/bin/yay -Qdtq)

  if [[ -z "$orphans" ]]; then
    echo "No orphan packages to remove."
    return 0
  fi

  /usr/bin/yay -Rcns $orphans || return $?

  local pkg
  while IFS= read -r pkg; do
    _aya_cache_remove "$pkg"
  done <<<"$orphans"
}

_aya_help() {
  echo "aya install <pkg>           → yay -S                               Install a package"
  echo "aya remove <pkg>            → yay -Rcns                            Remove package + deps + config"
  echo "aya remove-orphans          → yay -Rcns \$(yay -Qdtq)               Remove all orphaned packages"
  echo "aya get-pkgbuild <pkg>      → yay -G                               Download PKGBUILD script"
  echo "aya install-from-pkgbuild   → makepkg -si                          Build & install from local PKGBUILD in the current working directory"
  echo "aya update                  → yay -Syu                             Sync & upgrade all + AUR"
  echo ""
  echo "aya search <term>           → yay -Ss                              Search repos + AUR"
  echo "aya remote-info <pkg>       → yay -Si                              Show repo/AUR package info"
  echo "aya local-info <pkg>        → yay -Qi                              Show installed package info"
  echo ""
  echo "aya list-all                → yay -Q                               List all installed"
  echo "aya list-aur                → yay -Qm                              List AUR-installed packages"
  echo "aya list-explicit           → yay -Qe                              List explicitly installed"
  echo "aya list-orphans            → yay -Qdt                             List orphaned packages"
  echo ""
  echo "aya owns <file>             → yay -Qo                              Which package owns a file"
  echo "aya files <pkg>             → yay -Ql                              List files from a package"
  echo ""
  echo "aya clean                   → yay -Sc                              Clean old cache"
  echo "aya clean-all               → yay -Scc                             Wipe entire cache"
}

aya() {
  case "$1" in
  install)
    shift
    _aya_install "$@"
    ;;
  remove)
    shift
    _aya_remove "$@"
    ;;
  remove-orphans)
    _aya_remove_orphans
    ;;
  get-pkgbuild)
    shift
    /usr/bin/yay -G "$@"
    ;;
  install-from-pkgbuild)
    makepkg -si
    ;;
  update)
    _aya_update
    ;;
  search)
    shift
    /usr/bin/yay -Ss "$@"
    ;;
  remote-info)
    shift
    /usr/bin/yay -Si "$@"
    ;;
  local-info)
    shift
    /usr/bin/yay -Qi "$@"
    ;;
  list-all)
    /usr/bin/yay -Q
    ;;
  list-aur)
    /usr/bin/yay -Qm
    ;;
  list-explicit)
    /usr/bin/yay -Qe
    ;;
  list-orphans)
    /usr/bin/yay -Qdt
    ;;
  owns)
    shift
    /usr/bin/yay -Qo "$@"
    ;;
  files)
    shift
    /usr/bin/yay -Ql "$@"
    ;;
  clean)
    /usr/bin/yay -Sc
    ;;
  clean-all)
    /usr/bin/yay -Scc
    ;;
  help | *)
    _aya_help
    ;;
  esac
}
