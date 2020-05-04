#!/bin/bash

install_dotfiles() {
    REPO="https://github.com/khuedoan98/dotfiles.git"
    GITDIR=$HOME/.dotfiles/

    git clone --bare $REPO $GITDIR

    dotfiles() {
        /usr/bin/git --git-dir=$GITDIR --work-tree=$HOME $@
    }

    if ! dotfiles checkout; then
        echo "All of the above files will be deleted, are you sure? (y/N) "
        read -r response
        if [ "$response" = "y" ] || [[ "$@" == *"-y"* ]]; then
            dotfiles checkout 2>&1 | grep -E "^\s+" | sed -e 's/^[ \t]*//' | xargs -d "\n" -I {} rm -v {}
            dotfiles checkout
            dotfiles config status.showUntrackedFiles no
        else
            rm -rf $GITDIR
            echo "Installation cancelled"
            exit 1
        fi
    else
        dotfiles config status.showUntrackedFiles no
    fi

    wallpapers_dir=$HOME/Pictures/Wallpapers
    mkdir -p $wallpapers_dir
    curl https://i.redd.it/v1lgvqk9lxn31.jpg > $wallpapers_dir/Waterfall.jpg
}

install_aur_helper() {
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
}

install_core_packages() {
    sudo pacman --noconfirm --needed -S zsh wget alsa-utils bc dunst feh fzf git libnotify maim npm playerctl translate-shell ttf-dejavu wmctrl xautolock xcape xclip xdotool xorg-server xorg-setxkbmap xorg-xbacklight xorg-xinit xorg-xrandr xorg-xsetroot xss-lock
    yay --noconfirm --needed -S mons nerd-fonts-source-code-pro polybar-git sxhkd-git bspwm-git

    # zsh plugins
    sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
    chsh -s /bin/zsh kernel
    systemctl mask systemd-backlight@backlight:acpi_video0 systemd-backlight@backlight:acpi_video1
    git clone https://github.com/Zay4ik/configs.git
    cd configs
    sudo cp neofetch/neofetch /usr/bin/neofetch
    sudo cp neofetch/config.conf ~/.config/neofetch/
    cp .zshrc ~/.zshrc
    cp .vimrc ~/.vimrc
    cd ..
    rm -rf configs
    git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time
    sudo mkdir /usr/share/zsh/plugins
    cd /usr/share/zsh/plugins
    sudo git clone https://github.com/zsh-users/zsh-autosuggestions
    sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting
    sudo pacman -S pkgfile
    sudo pkgfile --update
    cd 

    # compton
    sudo pacman --noconfirm --needed -S asciidoc libconfig
    git clone https://github.com/tryone144/compton.git
    cd compton
    make PREFIX=/usr/local
    make docs
    sudo make PREFIX=/usr/local install
    cd ..
    rm -rf compton

    # alacritty
    sudo pacman --noconfirm --needed -S alacritty

    # dmenu
    git clone https://github.com/khuedoan98/dmenu
    cd dmenu
    sudo make clean install && sudo make clean
    cd ..
    rm -rf dmenu

    # slock
    git clone https://github.com/khuedoan98/slock
    cd slock
    sudo make clean install && sudo make clean
    cd ..
    rm -rf slock

    # pfetch
    yay --noconfirm --needed -S pfetch-git

    # lxdm
    sudo pacman --noconfirm --needed -S lxdm
    sudo systemctl enable lxdm
}

install_extra_packages() {
    sudo pacman --noconfirm --needed -S lxappearance arc-gtk-theme aria2 glances gvfs htop man mpv noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ntfs-3g papirus-icon-theme pcmanfm-gtk3 firefox ranger tmux tree unrar unzip w3m xarchiver xdg-user-dirs-gtk youtube-dl zathura zathura-pdf-mupdf zip
    gpg --recv-keys EB4F9E5A60D32232BB52150C12C87A28FEAC6B20
    yay --noconfirm --needed -S chromium-widevine ttf-ms-fonts xdg-user-dirs-update
}

install_intel_graphics() {
    sudo pacman --noconfirm --needed -S xf86-video-intel libva-intel-driver
}


install_unikey() {
    sudo pacman --noconfirm --needed -S ibus-unikey
}

install_system_config() {
    sed -i "s/khuedoan/$USER/g" .root/etc/systemd/system/getty@tty1.service.d/override.conf
    sudo cp -rv .root/* /
}

install_battery_saver() {
    sudo pacman --noconfirm --needed -S tlp powertop
    yay --noconfirm --needed -S intel-undervolt
    sudo systemctl enable tlp.service
    sudo systemctl enable tlp-sleep.service
    sudo intel-undervolt apply
    sudo systemctl enable intel-undervolt.service
}

create_ssh_key() {
    email=$(whiptail --inputbox "Enter email for SSH key" 10 20 3>&1 1>&2 2>&3)
    ssh-keygen -t rsa -b 4096 -C "${email}"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    # dotfiles remote set-url origin git@github.com:khuedoan98/dotfiles.git
}

install_dev_tools() {
    # Docker
    sudo pacman --noconfirm --needed -S docker-compose
    sudo usermod -aG docker $USER
    # Python
    sudo pacman --noconfirm --needed -S python-pipenv
    # Markdown to PDF
    sudo pacman --noconfirm --needed -S wkhtmltopd
    curl -s https://raw.githubusercontent.com/khuedoan98/mdtopdf/master/mdtopdf > $HOME/.local/bin/mdtopdf
    chmod +x $HOME/.local/bin/mdtopdf
}

# TUI
if [ "$#" -eq 0 ]; then
    install_list=( $(whiptail --notags --title "Dotfiles" --checklist "Install list" 20 45 11 \
        install_dotfiles "All config files" on \
        install_aur_helper "AUR helper (trizen)" on \
        install_core_packages "Recommended packages" on \
        install_extra_packages "Extra packages" on \
        3>&1 1>&2 2>&3 | sed 's/"//g') )

    for install_function in "${install_list[@]}"; do
        $install_function
    done
# CLI
else
    if [ "$1" = "--minimal" ]; then
        cli_config_files=".aliases .config/nvim/init.vim .tmux.conf .zshrc"

        for file in $cli_config_files; do
            curl https://raw.githubusercontent.com/khuedoan98/dotfiles/master/$file > $HOME/$file
        done
    elif [ "$1" = "--all" ]; then
        install_dotfiles
        install_aur_helper
        install_core_packages
        install_extra_packages
        install_intel_graphics
        install_unikey
        install_system_config
        install_battery_saver
        install_dev_tools
        create_ssh_key
    else
        if [[ "$@" == *"--dotfiles"* ]]; then
            install_dotfiles
        fi
        if [[ "$@" == *"--aur-helper"* ]]; then
            install_aur_helper
        fi
        if [[ "$@" == *"--packages"* ]]; then
            install_core_packages
        fi
        if [[ "$@" == *"--extra-packages"* ]]; then
            install_extra_packages
        fi
        if [[ "$@" == *"--graphics-driver"* ]]; then
            install_intel_graphics
        fi
        if [[ "$@" == *"--unikey"* ]]; then
            install_unikey
        fi
        if [[ "$@" == *"--system-config"* ]]; then
            install_system_config
        fi
        if [[ "$@" == *"--battery-saver"* ]]; then
            install_battery_saver
        fi
        if [[ "$@" == *"--dev-tools"* ]]; then
            install_dev_tools
        fi
        if [[ "$@" == *"--ssh-key"* ]]; then
            create_ssh_key
        fi
    fi
fi
