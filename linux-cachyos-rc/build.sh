rm -rf src/ pkg/
updpkgsums
makepkg -scf --noconfirm

# install package with pacman
sudo pacman -U --noconfirm *.pkg.tar.zst

