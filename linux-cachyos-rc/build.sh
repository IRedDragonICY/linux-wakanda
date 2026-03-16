rm -rf src/ pkg/
makepkg -scf --noconfirm

# install package with pacman
sudo pacman -U --noconfirm *.pkg.tar.zst

