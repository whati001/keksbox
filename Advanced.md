# Advanced Keksbox Setup
This page illustrates how to boost the keksbox, support Bluetooth speakers, and enable remote system configuration. The current approach is hacky because we expose an entire SSH client. This approach could and should be replaced with a secure option once the device is turned into a commercial product :p.

## Install more tools
First, we must install more packages that enable smooth Bluetooth configuration, remote SSH access, and a proper audio server. Because SSH is the main communication channel, the Bluetooth configuration leverages a Terminal User Interface (TUI). The basic setup directly streams the audio file via `alsa` to the USB audio device. The advanced setup leverages an audio server (like pipewire or PulseAudio) for simplification and robustness. 

```bash
# install audio server (pipewire)
keksbox@rehkakeks:~ $ sudo apt install pipewire pipewire-pulse
# at the point of writing, also the package `pulseaudio-module-bluetooth` is desired to establish a ble speaker connection
# this may change in the future
keksbox@rehkakeks:~ $ sudo apt install pulseaudio-module-bluetooth

# install bluetuith (bl tui manager)
# https://github.com/bluetuith-org/bluetuith/releases
keksbox@rehkakeks:~ $ cd ~ && mkdir ./bin && cd bin && wget -qO- https://github.com/bluetuith-org/bluetuith/releases/download/v0.2.3/bluetuith_0.2.3_Linux_arm64.tar.gz | tar -xzv
# add ~/.bin to PATH
keksbox@rehkakeks:~ $ echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
keksbox@rehkakeks:~ $ source ~/.bashrc
```

## Install sshwifty (web ssh client)
Next, we install a web ssh client, which allows us to connect and configure the keksbox remotely. Configuration via SSH lacks user ability but is a straightforward approach. I have also used X11 forwarding or Xpra to enable Windows to stream (such as a settings panel) to a web page. Unfortunately, the Raspberry Pi is too weak. In addition, I have not found a slim settings panel combining audio and Bluetooth configuration except the one from KDE Plasma (which is way too heavy for the pi).

```bash
keksbox@rehkakeks:~ $ cd /opt && sudo mkdir -p sshwifty && cd sshwifty && wget -qO- https://github.com/nirui/sshwifty/releases/download/0.3.21-beta-release-prebuild/sshwifty_0.3.21-beta-release_linux_arm.tar.gz | sudo tar -xzv
```

### Self Signed SSL Certificate
SSHwifty requires a TLS connection to work correctly. Because the webpage is not exposed to the internet, we will create a self-signed certificate.

```bash
keksbox@rehkakeks:~ $ cd /opt/sshwifty/ && sudo openssl req -newkey rsa:4096  -x509  -sha512  -days 365 -nodes -out certificate.pem -keyout privatekey.pem && sudo chmod 644 privatekey.pem

# enable sshwifty and configure to use the generated certificate
keksbox@rehkakeks:~ $ sudo cp ~/keksbox/config/sshwifty.conf.json ./sshwifty.conf.json

# copy unit file and enable it
keksbox@rehkakeks:~ $ sudo cp ~/keksbox/unit_files/sshwifty.service /etc/systemd/system/
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

## Enable WiFi AP
Finally, we transform the device into an autonomous device by enabling the WiFi AP feature of the NetworkManager.
To enable the WiFi Access Point (AP) feature using NetworkManager on the Raspberry Pi, follow these steps:

Ensure NetworkManager is installed on your Raspberry Pi. If not, install it using the following command:
```bash
keksbox@rehkakeks:~ $ sudo apt update
keksbox@rehkakeks:~ $ sudo apt install network-manager
```

The default `dhcpcd` service conflicts with NetworkManager. Stop and disable it:
```bash
keksbox@rehkakeks:~ $ sudo systemctl stop dhcpcd
keksbox@rehkakeks:~ $ sudo systemctl disable dhcpcd
```

Enable and start the NetworkManager service:
```bash
keksbox@rehkakeks:~ $ sudo systemctl enable NetworkManager
keksbox@rehkakeks:~ $ sudo systemctl start NetworkManager
```

Use the `nmcli` command to create a new WiFi AP profile:
```bash
keksbox@rehkakeks:~ $ sudo nmcli dev wifi hotspot ifname wlan0 ssid KeksboxAP password "123345678"
```

If you setup the device via ssh over wifi, the command above will kill the connection.
Please wait some time and connect to crated access point `KeksboxAP` with the password `12345678`.

To keep the AP active after a restart, either change the priority of it or remove the WiFi configuration and set the AP configuration to autostart.
Removing is simply done by deleting the correct file in `/etc/NetworkManager/system-connections`.
In my case, it's called `preconfigured.nmconnection`. Please ensure to add the configuration `autoconnect=true` to the `[connection]` section, otherwise the AP will not get started.

Restart NetworkManager to apply the changes:
```bash
keksbox@rehkakeks:~ $ sudo systemctl restart NetworkManager
```
Check if the AP is active and broadcasting:
```bash
keksbox@rehkakeks:~ $ nmcli dev status
DEVICE         TYPE      STATE                   CONNECTION 
wlan0          wifi      connected               Hotspot    
lo             loopback  connected (externally)  lo         
p2p-dev-wlan0  wifi-p2p  disconnected            --      
```
You should see `wlan0` listed as a hotspot.

Use another device to search for the `KeksboxAP` SSID and connect using the password you set earlier.
Your Raspberry Pi is now configured as a WiFi Access Point!

## Access Web Portal
After turing the keksbox into an WiFi AP, you should be able to connect to the device via the following addresses:
* File Browser: [http://10.42.0.1:8080](http://10.42.0.1:8080)
* SSH Web Client: [https://10.42.0.1:8182](https://10.42.0.1:8182)
* SSH Client: [ssh://keksbox:kb@10.42.0.1](ssh://keksbox:kb@10.42.0.1)