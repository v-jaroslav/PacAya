# PacAya

This repository contains a small shell script that wraps already existing tools `pacman` and `yay` on Arch based Linux Distributions.

The purpose of this script is to simplify the usage of the `pacman` and `yay` tools, such that you don't have to remember what flags do these command line tools accept, and what do they mean.


This script does have one more purpose however. And that is to protect you from malicious orphaned [AUR](https://wiki.archlinux.org/title/Arch_User_Repository) packages.
AUR is powerful, but when package that you installed becomes orphaned, anyone can hijack it, and turn it into malicious piece of software.
When that happens, when you blindly run `yay -Syu` command to update all of your AUR packages, you can get hacked. This script attempts to solve this problem.

This script fixes this problem, by simply halting the installation process of AUR packages that don't have maintainer and that are orphaned. 
And when you do install a legitimate new AUR package, its maintainer is remembered in `~/.aya/maintainers`.

Then the next time you try to update AUR packages, in case there is a new maintainer, or in case the package got orphaned, the update process will be halted!
Now you might wonder, what about AUR packages that you installed before using this script? Well, their maintainers will be saved in `~/.aya/maintainers` on the next update you perform with this script!

> [!WARNING]
> It is not guaranteed that this script will 100% protect you, as always even with this simple tool do use common sense, and check before you download and install anything if it is safe, read reviews, etc.

# Installation

To install this scrpit, download it from [here](https://raw.githubusercontent.com/v-jaroslav/PacAya/refs/heads/main/pac-aya.sh), and save it to your home directory.
After that add the following to your `.bashrc` or `.zshrc` (depending on what you use): `[ -f $HOME/pac-aya.sh ] && source $HOME/pac-aya.sh`.
After that, you are ready to use it!

# Usage
```text
$ pac
pac install <pkg>      → sudo pacman -S                       Install a package
pac remove <pkg>       → sudo pacman -Rcns                    Remove package + deps + config
pac remove-orphans     → sudo pacman -Rcns $(pacman -Qdtq)    Remove all orphans
pac update             → sudo pacman -Syu                     Sync & upgrade all

pac search <term>      → pacman -Ss                           Search repos
pac remote-info <pkg>  → pacman -Si                           Show repo package info
pac local-info <pkg>   → pacman -Qi                           Show installed package info

pac list-all           → pacman -Q                            List all installed
pac list-explicit      → pacman -Qe                           List explicitly installed
pac list-orphans       → pacman -Qdt                          List orphaned packages

pac owns <file>        → pacman -Qo                           Which package owns a file
pac files <pkg>        → pacman -Ql                           List files from a package

pac clean              → sudo pacman -Sc                      Clean old cache
pac clean-all          → sudo pacman -Scc                     Wipe entire cache
```

```text
$ aya                                                                                                                                                                                      ⏎
aya install <pkg>           → yay -S                               Install a package
aya remove <pkg>            → yay -Rcns                            Remove package + deps + config
aya remove-orphans          → yay -Rcns $(yay -Qdtq)               Remove all orphaned packages
aya get-pkgbuild <pkg>      → yay -G                               Download PKGBUILD script
aya install-from-pkgbuild   → makepkg -si                          Build & install from local PKGBUILD in the current working directory
aya update                  → yay -Syu                             Sync & upgrade all + AUR

aya search <term>           → yay -Ss                              Search repos + AUR
aya remote-info <pkg>       → yay -Si                              Show repo/AUR package info
aya local-info <pkg>        → yay -Qi                              Show installed package info

aya list-all                → yay -Q                               List all installed
aya list-aur                → yay -Qm                              List AUR-installed packages
aya list-explicit           → yay -Qe                              List explicitly installed
aya list-orphans            → yay -Qdt                             List orphaned packages

aya owns <file>             → yay -Qo                              Which package owns a file
aya files <pkg>             → yay -Ql                              List files from a package

aya clean                   → yay -Sc                              Clean old cache
aya clean-all               → yay -Scc                             Wipe entire cache
```
