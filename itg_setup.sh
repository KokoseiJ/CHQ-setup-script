installs=()
configs=()


install_ITGmania () {
    if [ -d /mnt/stepmania/itgmania ]; then
        echo "Seems like ITGmania is already installed. Do you want to update it to newer version?"
        echo "WARNING: This will overwrite the directory with new version!"
        read -p "Proceed? (y/n): " -n1 ANSWER
        echo
        if [ $ANSWER = "n" -o  $ANSWER = "N" ]; then return 0; fi
    fi

    latest_tag=$(curl -Ls -o /dev/null -w %{url_effective}\\n https://github.com/itgmania/itgmania/releases/latest | grep -oE "([0-9]+\.?)+")
    ITGmania_url="https://github.com/itgmania/itgmania/releases/download/v${latest_tag}/ITGmania-${latest_tag}-Linux-no-songs.tar.gz"

    cd /tmp

    curl -L $ITGmania_url | tar -xzf -

    mkdir -p /mnt/stepmania/itgmania
    mv ITGmania-*/itgmania/* /mnt/stepmania/itgmania/
    rm -rf ITGmania-*
}
installs+=("install_ITGmania")


install_PIUIO () {
    mkdir -p /home/dance/src
    cd /home/dance/src

    if [ -d /home/dance/src/piuio ]; then
        chown -R root:root piuio
        cd piuio
        git pull
        cd mod
    else
        git clone --depth 1 https://github.com/DinsFire64/piuio
        cd piuio/mod
    fi

    make && make install
    depmod -a
}
installs+=("install_PIUIO")


install_evhz () {
    mkdir -p /home/dance/src
    cd /home/dance/src

    if [ -d /home/dance/src/evhz ]; then
        chown -R root:root evhz
        cd evhz
        git pull
    else
        git clone --depth 1 https://github.com/geefr/evhz
        cd evhz
    fi

    gcc -o evhz evhz.c

    mkdir -p /home/dance/tools
    mv evhz /home/dance/tools
}
installs+=("install_evhz")


install_scripts () {
    mkdir -p /home/dance/tools
    cd /home/dance/tools

    wget https://gist.githubusercontent.com/KokoseiJ/cbacf48bdc24e060386251a29aae4914/raw/usbprofileconfig.py
    chmod +x usbprofileconfig.py
}


install_sensord () {
    mkdir -p /home/dance/src
    cd /home/dance/src

    if [ -d /home/dance/src/lm-sensors ]; then
        chown -R root:root lm-sensors
        cd lm-sensors
        git pull
    else
        git clone --depth 1 https://github.com/lm-sensors/lm-sensors
        cd lm-sensors

    make PROG_EXTRA=sensord all-prog-sensord
    make PROG_EXTRA=sensord install-prog-sensord
    make PROG_EXTRA=sensord clean
}
installs+=("install_sensord")


config_ITGmania () {
    if [ -d /home/dance/itgmania ]; then rm -rf /home/dance/itgmania; done
    if [ -d /home/dance/.itgmania ]; then rm -rf /home/dance/.itgmania; done

    ln -s /mnt/stepmania/itgmania /home/dance/itgmania
    mkdir -p /mnt/stepmania/itgmania_saves
    ln -s /mnt/stepmania/itgmania_saves /home/dance/.itgmania

    mkdir -p /mnt/songs/Songs
    mkdir -p /mnt/songs/Courses
    rm -rf /home/dance/itgmania/Songs /home/dance/itgmania/Courses

    ln -s /mnt/songs/Songs /home/dance/itgmania/Songs
    ln -s /mnt/songs/Courses /home/dance/itgmania/Courses

    chown -R dance:dance /mnt/stepmania
    chown -R dance:dance /mnt/songs
}
configs+=("config_ITGmania")


config_pollingrate() {
    # https://github.com/geefr/stepmania-linux-goodies/wiki/So-You-Think-You-Have-Polling-Issues#polling-for-mice-and-joysticks

    if ! grep "usbhid" /etc/default/grub > /dev/null; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& usbhid.mousepoll=1 usbhid.jspoll=1 usbhid.kbpoll=1/" /etc/default/grub
    fi
}
configs+=("config_pollingrate")


config_CRT () {
    # Since dedicabs are usually running on CRT, there are some tricks needed to make the screen function properly
    # GFXMODE helps set the framebuffer resolution. This sets the resolution for GRUB and tty framebuffer until KMS kicks in.
    
    if grep "GRUB_GFXMODE=" /etc/default/grub > /dev/null; then
        sed -i "s/#\?GRUB_GFXMODE=.*/GRUB_GFXMODE=640x480/"
        tee -a /etc/default/grub <<EOF
GRUB_GFXPAYLOAD_LINUX=keep
EOF
    else
        tee -a /etc/default/grub <<EOF
GRUB_GFXMODE=640x480
GRUB_GFXPAYLOAD_LINUX=keep
EOF
    fi

    # video argument for linux cmdline overrides KMS config, which doesn't work since CRT obviously lacks EDID info.
    # This is effective until X11 kicks in, which requires its own config done in place.
    if ! grep "video=VGA-1:640x480" /etc/default/grub > /dev/null; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& video=VGA-1:640x480/" /etc/default/grub
    fi

    # Sets the X11 monitor config. This config is taken fron Kortek CRT's out of range message, and should work with other dedicabs
    tee /etc/X11/xorg.conf.d/10-kortekcrt.conf <<EOF
Section "Monitor"
    Identifier  "VGA-0"
    HorizSync   30.0-40.0
    VertRefresh     47.0-160.0
    Option      "PreferredMode" "640x480"
EndSection
EOF
}
configs+=("config_CRT")


config_grub() {
    sed -i "s/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=1/" /etc/default/grub
    sed -i "s/quiet \?//g" /etc/default/grub

    # Fun stuff: GRUB background as ITG2 :P

    if ! grep "GRUB_BACKGROUND=" /etc/default/grub > /dev/null; then
        curl -L "https://github.com/JoseVarelaP/In-The-Groove2-SM5/raw/master/Graphics/ITG2%20Common%20fallback%20background.png" > /boot/itg2.png
        tee -a /etc/default/grub <<EOF
GRUB_BACKGROUND=/boot/itg2.png
EOF
    fi

    update-grub
}
configs+=("config_grub")


config_autologin () {
    systemctl set-default multi-user.target

    # Configures logind to open only single virtual terminal on startup
    sed -i "s/#\?NAutoVTs=[0-9]\+/NAutoVTs=1/" /etc/systemd/logind.conf

    # Creates getty drop-in for autologin
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    tee /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear --autologin dance tty1 \$TERM
EOF

}
configs+=("config_autologin")


config_keybinds () {
    tee /home/dance/.xbindkeysrc <<EOF
"uxterm"
  Control+alt + t

"guake -t"
  Mod4 + Return

"uxterm -e sudo /home/dance/tools/evhz"
  Mod4 + e
  Control + e

"uxterm -e sudo /home/dance/tools/usbprofileconfig.py"
  Mod4 + u
  Control + u

"/home/dance/start.sh"
  Mod4 + s
  Control + s
EOF

}
configs+=("config_keybinds")


config_xinit () {
    tee /home/dance/.xserverrc <<EOF
#!/bin/sh

exec /usr/bin/X -nolisten tcp "\$@" vt\$XDG_VTNR
EOF

    tee /home/dance/.xinitrc <<EOF
#!/bin/sh

xsetroot -solid "#3A6EA5"
exec openbox-session
EOF

    chmod +x /home/dance/.xserverrc \
             /home/dance/.xinitrc

}
configs+=("config_xinit")


config_openbox () {
    # Autostart x11 on startup
    if [ -e /home/dance/.profile.bak ]; then
        cp /home/dance/.profile.bak /home/dance/.profile
    else
        cp /home/dance/.profile /home/dance/.profile.bak
    fi

    tee -a /home/dance/.profile <<EOF

# ===== Added by ITG setup script =====

if [ -z \$DISPLAY ] && [ \$(tty) = "/dev/tty1" ]; then
  echo "
                       **********************************
                       *       ITG Starting Up...       *
                       *                                *
                       * Barry & Koko & Vika was here!! *
                       *        VRG  2022 ~ 2023        *
                       **********************************
"
  sleep 3
  # Append exec to make the tty die when session dies.
  # Without it user gets kicked out to tty when xfce gets logged out
  xinit
fi
EOF

    # Setup stepmania autostart

    mkdir -p /home/dance/.config/openbox
    tee /home/dance/.config/openbox/autostart <<EOF
#!/bin/bash

tint2 &
guake &
exec ~/start.sh
EOF

    tee /home/dance/start.sh <<EOF
#!/bin/bash

while [ -z \$(xset q | grep -oE "Caps Lock:[[:space:]]+on") ]
do
    itgmania/itgmania
done

xdotool key Caps_Lock

thunar &
EOF

    chmod +x /home/dance/.profile \
             /home/dance/.config/openbox/autostart \
             /home/dance/start.sh
}
configs+=("config_openbox")


config_user() {
    usermod -aG sudo,adm,systemd-journal,audio dance

    tee -a <<EOF
dance ALL=(ALL) NOPASSWD: ALL
EOF

}
configs+=("config_user")


config_sensord () {
    curl https://gist.githubusercontent.com/KokoseiJ/1837ba17c954465575364a606fcc8d11/raw/setup.sh | bash
}
configs+=("config_sensord")


startup () {
    apt-mark hold linux-image-amd64 linux-headers-amd64 pulseaudio

    apt-get update && apt-get upgrade -y

    apt-get install -y \
        sudo vim curl wget python3 \
        openssh-server \
        linux-headers-$(uname -r) \
        git make gcc \
        xorg openbox tint2 thunar guake \
        libasound2 apulse \
        libopengl0 libpulse0 \
        xdotool xbindkeys \
        network-manager \
        lighttpd sensors \
        librrd-dev bison flex
}


cleanup () {
    apt autoremove -y
    chown -R dance:dance /home/dance
}


#memo: use xbindkeys config for shortcuts
#make a function for initializing each config
#xsetroot -solid "#3A6EA5"
#use openbox + tint2, install only thunar for file explorer
#use xterm fancy terminals don't work well on CRT
#libpulse0 and libopengl0 needed for barebone installation
#maybe setup NetworkManager wifi setting script?

clear
echo "
********************************
* ITG Setup Script by KokoseiJ *
*   Last Updated: 2023/05/25   *
********************************

Setup will start in 5 seconds.
Press Ctrl+C now to abort and return to shell.
"

sleep 5

startup

for i in "${!installs[@]}"; do
    printf "\\n[*] Running ${installs[$i]}...\\n\\n"

    ${installs[$i]}

    printf "\\n[*] Finished ${installs[$i]}\\n"
done


for i in "${!configs[@]}"; do
    printf "\\n[*] Running ${configs[$i]}...\\n\\n"

    ${configs[$i]}

    printf "\\n[*] Finished ${configs[$i]}\\n"
done

cleanup

echo
echo "Setup has been completed. The system will reboot in 10 seconds.
Press Ctrl+C now to return to shell and review changes.

Kernel is NOT update and WILL NOT BE updated until you manually do so!
If you update the kernel, DO RUN THE SCRIPT AGAIN! PIUIO needs to be reinstalled.

GLHF!
    -koko"
sleep 10
init 6
