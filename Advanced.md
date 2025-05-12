# Advanced Keksbox Setup
This page illustrates how to boost the keksbox, support Bluetooth speakers, and enable remote system configuration. The current approach is hacky because we expose an entire SSH client. This approach could and should be replaced with a secure option once the device is turned into a commercial product :p.

## Install more tools
First, we must install more packages that enable smooth Bluetooth configuration, remote SSH access, and a proper audio server. Because SSH is the main communication channel, the Bluetooth configuration leverages a Terminal User Interface (TUI). The basic setup directly streams the audio file via `alsa` to the USB audio device. The advanced setup leverages an audio server (like pipewire or PulseAudio) for simplification and robustness. 

```bash
# install audio server (pipewire)
keksbox@rehkakeks:~ $ sudo apt install pipewire pipewire-pulse

# install bluetuith (bl tui manager)
# https://github.com/bluetuith-org/bluetuith/releases
keksbox@rehkakeks:~ $ cd ~ && mkdir ./bin && cd bin && wget -qO- https://github.com/bluetuith-org/bluetuith/releases/download/v0.2.3/bluetuith_0.2.3_Linux_arm64.tar.gz | tar -xzv
# add ~/.bin to PATH
```bash
# add ~/.bin to PATH
keksbox@rehkakeks:~ $ echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
keksbox@rehkakeks:~ $ source ~/.bashrc
```

# install sshwifty (web ssh client)
keksbox@rehkakeks:~ $ cd /opt && sudo mkdir -p sshwifty && cd sshwifty && wget -qO- https://github.com/nirui/sshwifty/releases/download/0.3.21-beta-release-prebuild/sshwifty_0.3.21-beta-release_linux_arm.tar.gz | sudo tar -xzv

# generate self signed certificate
keksbox@rehkakeks:~ $ cd /opt/sshwifty/ && sudo openssl req -newkey rsa:4096  -x509  -sha512  -days 365 -nodes -out certificate.pem -keyout privatekey.pem

# enable sshwifty and configure to use the generated certificate
keksbox@rehkakeks:~ $ sudo cp ~/keksbox/config/sshwifty.conf.template.json ./sshwifty.conf.json
# copy unit file and enable it
keksbox@rehkakeks:~ $ sudo cp keksbox/unit_files/sshwifty.service /etc/systemd/system/
keksbox@rehkakeks:~ $ sudo chown root:root /etc/systemd/system/sshwifty.service
keksbox@rehkakeks:~ $ sudo systemctl enable sshwifty.service
keksbox@rehkakeks:~ $ sudo systemctl daemon-reload
```

## Enable User Autologin
In the next step, we will enable the auto-login feature of the Raspberry Pi OS. By logging in, systemd will automatically start the audio server and initiate it properly. Without this, we need to hack around with the environment variables to "emulate" a valid user session or change the audio server to work without a user session.

```bash
# raspi-config -> System Options -> Auto Login -> YES
keksbox@rehkakeks:~ $ sudo raspi-config

# systemd should now show a user session with pipewire running
keksbox@rehkakeks:~ $ systemctl --user status
● rehkakeks
    State: running
    Units: 126 loaded (incl. loaded aliases)
     Jobs: 0 queued
   Failed: 0 units
    Since: Fri 2025-05-09 17:13:29 CEST; 57s ago
  systemd: 252.36-1~deb12u1
   CGroup: /user.slice/user-1000.slice/user@1000.service
           ├─init.scope
           │ ├─594 /lib/systemd/systemd --user
           │ └─595 "(sd-pam)"
           └─session.slice
             ├─dbus.service
             │ └─616 /usr/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation -->
             ├─filter-chain.service
             │ └─611 /usr/bin/pipewire -c filter-chain.conf
             ├─pipewire-pulse.service
             │ └─613 /usr/bin/pipewire-pulse
             ├─pipewire.service
             │ └─610 /usr/bin/pipewire
             ├─wireplumber.service
             │ └─612 /usr/bin/wireplumber
             └─xdg-permission-store.service
               └─663 /usr/libexec/xdg-permission-store
```

## Reboot and validate
Finally, we can reboot the device and verify that everything is working.
If everything worked fine, you should be able to access:
* http://<KEKSBOX_IP>:8080 -> filebrowser to update custom sounds
* https://<KEKSBOX_IP>:8182 -> sshwifty for configuration