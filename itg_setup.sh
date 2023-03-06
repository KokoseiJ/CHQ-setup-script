#!/bin/bash

## ITG Setup Script, written by KokoseiJ (Wonjun Jung)
##
##    This is a test script, will prepare system to be up and running
##  state but not quite enough for production run.
##    This script assumes that the system is freshly installed debian,
##  with `dance` user for running ITG and `/mnt/stepmania` with
##  `/mnt/songs` partitions mounted.
##
## TODO: USB profile setup, polling rate, x11 shortcuts for maintenance

# Erase CD-ROM source and install packages
sed -i "s/#\? \?deb cdrom\:.*//" /etc/apt/sources.list
apt update && apt upgrade -y

# No pulseaudio!
apt-mark hold pulseaudio pulseaudio-utils pavucontrol
apt install -y vim curl wget git sudo libasound2 libasound2-plugins apulse alsa-utils xorg xfce4 openbox gcc make xz-utils

# apt install -y openssl-server
# apt install -y vim curl wget git sudo
usermod -aG sudo,adm,systemd-journal dance

# Installs a kernel and sets up GRUB for maintenance
curl 'https://liquorix.net/install-liquorix.sh' | bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"video=VGA-1:640x480\"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=1/' /etc/default/grub


# Fun stuff- grub background as ITG2 :P
curl -L "https://github.com/JoseVarelaP/In-The-Groove2-SM5/raw/master/Graphics/ITG2%20Common%20fallback%20background.png" > /boot/itg2.png
tee -a /etc/default/grub <<EOF
GRUB_BACKGROUND=/boot/itg2.png
GRUB_GFXMODE=640x480
GRUB_GFXPAYLOAD_LINUX=keep
EOF

update-grub

# Install PIUIO
# apt install gcc make xz-tools
cd /home/dance
mkdir -p src && cd src
git clone https://github.com/DinsFire64/piuio && cd piuio/mod
make KDIR=/usr/src/linux-headers-*liquorix*
# Since we're not yet running on liquorix kernel we have to juggle around
# you MUST run depmod -a at least once after rebooting!
make KDIR=/usr/src/linux-headers-*liquorix* DESTDIR=/home/dance/src/piuio/install install
mv $(find /home/dance/src/piuio -name "updates") /lib/modules/*liquorix*
rm -rf /home/dance/src/piuio/install
tee -a /etc/modules <<EOF
piuio
EOF

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
# apt install -y libasound2 libasound2-plugins alsa-utils apulse
usermod -aG audio dance

# Setup Xserver, full installation of xfce4 might be changed to something else
# apt install -y xorg xfce4 openbox
systemctl set-default multi-user.target

tee /etc/X11/xorg.conf.d/10-kortekcrt.conf <<EOF
Section "Monitor"
	Identifier 	"VGA-0"
	HorizSync 	30.0-40.0
	VertRefresh 	47.0-160.0
	Option 		"PreferredMode" "640x480"
EndSection
EOF

tee /home/dance/.xserverrc <<EOF
#!/bin/sh

exec /usr/bin/X -nolisten tcp "\$@" vt\$XDG_VTNR
EOF
chmod +x /home/dance/.xserverrc

# Setup ITGMania!
cd /mnt/stepmania
curl -L https://github.com/itgmania/itgmania/releases/download/v0.5.1/ITGmania-0.5.1-Linux-no-songs.tar.gz | tar -xzf -
mv ITGmania-*/itgmania .
rm -rf ITGmania-*
ln -s /mnt/stepmania/itgmania /home/dance/itgmania
mkdir -p /mnt/stepmania/itgmania_saves
ln -s /mnt/stepmania/itgmania_saves /home/dance/.itgmania

# Link songs folders to /home
mkdir -p /mnt/songs/Songs
mkdir -p /mnt/songs/Courses
rm -rf /home/dance/itgmania/Songs /home/dance/itgmania/Courses
ln -s /mnt/songs/Songs /home/dance/itgmania/Songs
ln -s /mnt/songs/Courses /home/dance/itgmania/Courses

# Setup stepmania autostart
tee /home/dance/start.sh <<EOF
#!/bin/bash
while [ -z $(xset q | grep -oE "Caps Lock:[[:space:]]+on") ]
do
	itgmania/itgmania
done

xdotool key Caps_Lock

xfdesktop &
xfce4-panel &
exec thunar
EOF

tee /home/dance/.xinitrc <<EOF
#!/bin/sh
exec openbox-session
EOF

mkdir -p /home/dance/.config/openbox
tee /home/dance/.config/openbox/autostart <<EOF
#!/bin/bash
exec ~/start.sh
EOF

cp /home/dance/.profile /home/dance/.profile.bak

tee -a /home/dance/.profile <<EOF

# ===== Added by ITG setup script =====

if [ -z $DISPLAY ] && [ $(tty) = "/dev/tty1" ]; then
  echo "

	*********************************
	*      ITG Starting Up....      *
	*                               *
	* Barry & Koko & Vika was here! *
	*        VRG 2022 ~ 2023        *
	*********************************

  "
  sleep 3
  # Append exec to make the tty die when session dies.
  # Without it user gets kicked out to tty when xfce gets logged out
  xinit
fi
EOF

chmod +x /home/dance/.xinitrc
chmod +x /home/dance/.profile
chmod +x /home/dance/start.sh
chmod +x /home/dance/.config/openbox/autostart

# Time to see if everything went to plan!
apt autoremove -y
chown -R dance:dance /home/dance
chown -R dance:dance /mnt/songs
chown -R dance:dance /mnt/stepmania

echo "Setup has been completed. The system will reboot in 10 seconds.
Press Ctrl+C now to return to shell and review changes.

!!! PIUIO driver installation is not done yet !!!
You MUST run \`depmod -a\` and \`modprobe piuio\` to
load the driver at least once.
After running depmod, it should load on boot automatically.

GLHF!
    -koko"
sleep 10
init 6
