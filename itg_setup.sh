#!/bin/bash

## ITG Setup Script, written by KokoseiJ (Wonjun Jung)
##
##    This is a test script, will prepare system to be up and running
##  state but not quite enough for production run.
##    This script assumes that the system is freshly installed debian,
##  with `dance` user for running ITG and `/songs` folder mounted to
##  a partition with songs.
##
## TODO: USB profile setup, polling rate, x11 shortcuts for maintenance

# Erase CD-ROM source and install packages
sed -i "s/#\? \?deb cdrom\:.*//" /etc/apt/sources.list
apt update && apt upgrade -y

# No pulseaudio!
apt-mark hold pulseaudio pulseaudio-utils pavucontrol
apt install -y vim curl wget git sudo libasound2 libasound2-plugins alsa-utils apulse xorg xfce4 gcc make xz-utils

# apt install -y openssl-server
# apt install -y vim curl wget git sudo
usermod -a -G sudo -G adm -G systemd-journal dance

# Installs a kernel and sets up GRUB for maintenance
curl 'https://liquorix.net/install-liquorix.sh' | bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAILT=\"\"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub

# Install PIUIO
# apt install gcc make xz-tools
cd /home/dance
mkdir -p src && cd src
git clone https://github.com/DinsFire64/piuio && cd piuio/mod
make KDIR=/usr/src/linux-headers-*liquorix* KVER=$(echo /usr/src/linux-headers-*liquorix* | sed "s/\/usr\/src\/linux-headers-//")
make KDIR=/usr/src/linux-headers-*liquorix* KVER=$(echo /usr/src/linux-headers-*liquorix* | sed "s/\/usr\/src\/linux-headers-//") install
cd /home/dance

# Setup autologin
sed -i "s/#\?NAutoVTs=[0-9]\+/NAutoVTs=1/" /etc/systemd/logind.conf
# /etc/systemd/system/getty@tty1.service.d/override.conf
mkdir -p /etc/systemd/system/getty@tty1.service.d

tee /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear --autologin dance %I \$TERM
EOF

systemctl daemon-reload && systemctl enable getty@tty1.service

# Setup ALSA, some systems (Including CHQ cab) have a main device that is not
# what the speaker is connected to, like graphics card
# This can be corrected by either specifying the correct device to be default,
# or changing modprobe.d/sound to force the correct device driver to load first
# apt install -y libasound2 libasound2-plugins alsa-utils
usermod -aG audio dance

# Setup Xserver, full installation of xfce4 might be changed to something else
# apt install -y xorg xfce4
systemctl set-default multi-user.target

tee /home/dance/.xserverrc <<EOF
#!/bin/sh

exec /usr/bin/X -nolisten tcp "\$@" vt\$XDG_VTNR
EOF
chmod +x /home/dance/.xserverrc

# Setup ITGMania!
cd /home/dance
curl -L https://github.com/itgmania/itgmania/releases/download/v0.5.1/ITGmania-0.5.1-Linux-no-songs.tar.gz | tar -xzf -
mv ITGmania-*/itgmania .
rm -rf ITGmania-*
cd /home/dance

# Setup stepmania autostart
# TODO: Add Caps lock check

tee /home/dance/.xinitrc <<EOF
#!/bin/sh
itgmania/itgmania
thunar &
exec startxfce4
EOF

cp /home/dance/.profile /home/dance/.profile.bak
tee -a /home/dance/.profile <<EOF
if [ -z "\${DISPLAY}" ] && [ "\${XDG_VTNR}" -eq 1 ]; then
  exec startx
fi
EOF

chmod +x /home/dance/.xinitrc
chmod +x /home/dance/.profile

# Time to see if everything went to plan!
apt autoremove -y
chown -R dance:dance /home/dance
init 6
