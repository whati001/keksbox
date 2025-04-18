# 🍪 Keksbox 🍪

A magic keksbox (cookie box) that conjures a smile into every child's face.

## Overview

The Keksbox is a homegrown music box that allows streaming of audiobooks from [kekz][kekz] tags to speakers. Streaming to a loudspeaker instead of a headset lets us share fun and experience the audiobooks together. 

The project aims to demonstrate that everybody with a basic background can develop nice products. Studying a programming language or software architecture for years is unnecessary. Instead, managing to empower Linux is sufficient to build starving products.

## Key Features

- **kekz audio playback**: [kekz][kekz] NFC tags combatible 
- **Minimal code approach**: Utilizes existing Linux tools instead of custom software.
- **Web-based file management**: Includes a web interface for uploading and managing custom NFC tag files.
- **Lightweight architecture**: Built entirely with standard Linux utilities.

## Usage

1. Place an NFC tag on the reader.
2. The system will:
    - Detect the tag using `libnfc`.
    - Look up the associated audio file.
    - Play the audio using `play` from SoX.
3. Use the Filebrowser web interface to:
    - Upload new audio files.
    - Associate files with specific NFC tags.
    - Manage your audio library.

## Hardware Components

- **[Raspberry Pi Zero 2W][rp_zero]**: Main processing unit
- **[PN 532 NFC Reader][PN532]**: Reading [kekz][kekz] NFC tags
- **[USB Audio][usb_audio]**: USB audio adatper
- **[USB-C Port][usb_c_breakout]**: Power delivery port (with resistors)
- **3D-Printed Case**: Case printed via 3d printer 

## Software Components

- **[Raspberry OS][rp_os]** - Operating system for [Raspberry Pi Zero 2 w][rp_zero]
- **[Sound eXchange][sox]** - Simple audio player framework for terminal use
- **[filebrowser][fb]** - Web-Based file browser (github project)
- **[libnfc][libnfc]** - Linux package to read NFC tag
- **[i2c-tools][i2c_tools]** - Linux package for [i2c][i2c] communication
- **[bash][bash]** - Scripting and automation

## Kekz Heatset

This project does not aim to reveal or exploit any internal system structure of the kekz product. However, a german security research has demystified the headset in his blog post: [https://nv1t.github.io/blog/kekz-headphones/][https://nv1t.github.io/blog/kekz-headphones/]. This project builds on top of his research. Following his research allows you to extract the audiobooks from a headset and decode them into mp3 files.


## Installation

If you want to have your own keksbox, please follow the steps below:

### Hardware Wiring

Before we start with the firmware, let's get the wiring done. At first, we will connect the NFC reader to the correct GPIO pins. By checking the [PI's pinout][rp_pinout] we can conclude the following connections:

```
# NFC module pin -> Pi GPIO physical pin #
GND -> 6
VCC -> 4
SDA -> 3
SCL -> 5
```

Next, we connect the USB Audio device to the PI through a micro USB to USB type A connector. The final wiring is shown in the image below.

\# TODO: image

### Raspberry Pi Zero 2 W Setup

Please install the [Raspberry OS][rp_os] as explained in the official [tutorial][rp_install]. This project used the `x64 bit lite version` of the os hidden behind the `Raspberry Pi Os (other)` option. Using the official image tool directly lets you set the hostname, user, and, most importantly, the wifi connection. This project used the following configuration:
* hostname: rehkakeks
* username: keksbox
* password: ks
* wifi: home specific

After flashing the image to the SD card, please insert it into the Raspberry Pi and try establishing an SSH connection from your host computer.
```bash
# the following code assumes that the keksbox owns the ip 192.168.0.101
$ ssh keksbox@192.168.0.101
Linux rehkakeks 6.12.20+rpt-rpi-v8 #1 SMP PREEMPT Debian 1:6.12.20-1+rpt1~bpo12+1 (2025-03-19) aarch64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Mon Apr 14 21:43:56 2025 from 192.168.0.122
keksbox@rehkakeks:~ $
```

Congratulations, you have managed the tricky part. 

### Update and install packages

Next, we will update the system and install all required packages. This is easy and should work like a charm. If you face any `unknown packages`, you properly use a different version of the Raspberry OS. This tutorial used `bookworm`. Please search the internet for the new name of the failed packages.

```bash
# Raspberry Os version check
keksbox@rehkakeks:~ $ lsb_release -a
No LSB modules are available.
Distributor ID: Debian
Description:    Debian GNU/Linux 12 (bookworm)
Release:        12
Codename:       bookworm

# upgarde system
keksbox@rehkakeks:~ $ sudo apt update && sudo apt upgrade

# install i2c and nfc tools
keksbox@rehkakeks:~ $ sudo apt install i2c-tools libnfc6 libnfc-bin libnfc-examples

# install tools needed of keksbox
keksbox@rehkakeks:~ $ sudo apt install sox tmux vim git

# install filebrowser (https://filebrowser.org/installation)
keksbox@rehkakeks:~ $ curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# clone the keksbox repository into home directory
keksbox@rehkakeks:~ $ cd ~ && git clone https://github.com/whati001/keksbox.git
```

### Install and configure keksbox

After installing all the necessary tools we can start to configure the system. There is little to configure here, except creating some directories and systemd files for autostartup.

```bash
# create home data directory with subfolders
keksbox@rehkakeks:~ $ cd ~ && mkdir data && mkdir data/{custom,filebrowser,tmp}

# create basic filebrowser configuration file
keksbox@rehkakeks:~ $ cat > data/filebrowser/.filebrowser.yaml <<EOF
# set listen address
address: "0.0.0.0"
# enable no authentication feature
noauth: true
EOF

# create system data direcotry with subfolders
keksbox@rehkakeks:~ $ cd /opt && sudo mkdir keksbox && sudo mkdir keksbox/{standard,system} && sudo ln -s /home/keksbox/data/custom /opt/keksbox/ && sudo chown -R keksbox:keksbox /opt/keksbox

# clone keksbox repository and distribute files
keksbox@rehkakeks:~ $ cd ~ && git clone git@github.com:whati001/keksbox.git && cp keksbox/keksbox.bash
keksbox@rehkakeks:~ $ sudo cp keksbox/unit_files/{filebrowser,keksbox}.service /etc/systemd/system/
keksbox@rehkakeks:~ $ sudo chown root:root /etc/systemd/system/filebrowser.service
keksbox@rehkakeks:~ $ sudo chown root:root /etc/systemd/system/keksbox.service

# reload systemd and enable new service
keksbox@rehkakeks:~ $ sudo systemctl daemon-reload
keksbox@rehkakeks:~ $ sudo systemctl enable keksbox.service
keksbox@rehkakeks:~ $ sudo systemctl enable filebrowser.service
```

Now we can veriy if everything works as expected by checking if both service are up and running:
```bash
# filebrowser service
keksbox@rehkakeks:~ $ sudo systemctl status filebrowser.service
● filebrowser.service - Keksbox FileBrowser
     Loaded: loaded (/etc/systemd/system/filebrowser.service; disabled; preset: enabled)
     Active: active (running) since Tue 2025-04-15 20:26:01 CEST; 3min 6s ago
       Docs: https://github.com/whati001/keksbox
   Main PID: 837 (filebrowser)
      Tasks: 9 (limit: 178)
        CPU: 222ms
     CGroup: /system.slice/filebrowser.service
             └─837 /usr/local/bin/filebrowser -r /home/keksbox/data/custom/

Apr 15 20:26:01 rehkakeks systemd[1]: Started filebrowser.service - Keksbox FileBrowser.
Apr 15 20:26:02 rehkakeks filebrowser[837]: 2025/04/15 20:26:02 Using database: /home/keksbox/data/filebrowser/filebrowser.db
Apr 15 20:26:02 rehkakeks filebrowser[837]: 2025/04/15 20:26:02 Using config file: /home/keksbox/data/filebrowser/.filebrowser.yaml
Apr 15 20:26:02 rehkakeks filebrowser[837]: 2025/04/15 20:26:02 Listening on [::]:8080

# keksbox service
keksbox@rehkakeks:~ $ sudo systemctl status keksbox
● keksbox.service - Keksbox Application
     Loaded: loaded (/etc/systemd/system/keksbox.service; disabled; preset: enabled)
     Active: active (running) since Tue 2025-04-15 20:29:34 CEST; 1s ago
       Docs: https://github.com/whati001/keksbox
   Main PID: 869 (keksbox.bash)
      Tasks: 5 (limit: 178)
        CPU: 114ms
     CGroup: /system.slice/keksbox.service
             ├─869 /bin/bash /home/keksbox/keksbox/keksbox.bash
             ├─876 tmux new -d -s effect "play /opt/keksbox/system/connect.mp3"
             ├─881 play /opt/keksbox/system/connect.mp3
             └─883 nfc-list -t 1

Apr 15 20:29:35 rehkakeks keksbox.bash[873]: nfc-poll uses libnfc 1.8.0
Apr 15 20:29:35 rehkakeks keksbox.bash[873]: NFC reader: PN532 over I2C opened
Apr 15 20:29:35 rehkakeks keksbox.bash[873]: NFC device will poll during 36000 ms (20 pollings of 300 ms for 6 modulations)
```

Finally, let's remove the keksbox repository because it's no longer needed.
```bash
keksbox@rehkakeks:~ $ rm -rf /home/keksbox/
```

### Upload audiobooks

Finally, we can upload the encrypted mp3 audiobook files you have extracted from the headset, as explained in the Kekz Heatset section.

### File Structure

The finally folder structure should look as follows:

```
/home/keksbox/
├── keksbox.bash                    # Keksbox application/script
└── data/                           # Keksbox data directory (custom songs)
    ├── filebrowser/                # Filebrowser data dir
    │   └── .filebrowser.yaml       # Filebrowser configuration file
    │   └── filebrowser.db          # Filebrowser database file (runtime data)
    └── custom/                     # Custom songs directory
        ├── 0001/                   # Custom song with id 0001
        └── XXXX/                   # Custom song with id XXXX

/opt/keksbox/
├── custom                          # Symlink to custom song directory
├── standard                        # Standard songs directory
│   ├── 0001/                       # Standard song with id 0001
│   └── XXXX/                       # Standard song with id XXXX
└── system                          # System songs directory
```

## License

[Specify your license here, e.g., MIT, GPL, etc.]

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for any improvements or suggestions.

## Acknowledgments

- The developers of `libnfc`.
- The SoX audio tools team.
- The Filebrowser project.
- The Linux community for providing robust tools and utilities.
- nv1t for his amazing research

[kekz]: https://kekz.com/
[rp_zero]: https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/
[pn532]: https://www.amazon.de/Nahfeldkommunikationsleser-Schl%C3%BCsselkarte-Arduino-Raspberry-Smartphone/dp/B07YDG6X2V/ref=sr_1_3?__mk_de_DE=%C3%85M%C3%85%C5%BD%C3%95%C3%91&crid=1JQF1X0WB120P&dib=eyJ2IjoiMSJ9.bqcGPIA9XjUus6gB18y8H4UmnDixitZrsmUUJ-GPnPdPr7VfOXU2KSzpHzdhoVDmYHiN3G-NfFSKRZAzxIOEvLvGL4hjB50iYuhOPFIMaiAZn4_L0-vMUWcaq0l_bvPxxesfgS5l4ao88ue7M6e5AcUnCNf4EVFCH9PLzhICIjonvK8bMrCSxVDzZoE7MJwibG10vAuDymA30XFjn4TWnFzocYmupFvnZMgh4OmgENY.QOW2AFNcjpBZfwHRLrrX5nGBT0LmzXmFd2QSb5XBUy0&dib_tag=se&keywords=nfc+reader+raspberry+pi+pn532&qid=1744658596&sprefix=nfc+reader+raspberry+pi+pn53%2Caps%2C126&sr=8-3
[usb_audio]: https://www.amazon.de/MOSWAG-Soundkarte-Konverter-kompatibel-Kopfh%C3%B6rer/dp/B09874Q33W/ref=sr_1_7?__mk_de_DE=%C3%85M%C3%85%C5%BD%C3%95%C3%91&crid=PQ5F2E7Y2C7C&dib=eyJ2IjoiMSJ9.j1ivzsDjj7rG81G-UgBp26DKemaqjIJEM1-uHumZ6S5NC02ek1Os9-e1Vjh-46Zz7ennVCvNdBtaceaiq8eBD0KVt17MLWgi7gENIjzmLw4Z1tcZpbMEZ9_rOy1acqsrAwjvBYpdn6Fm1905yWC5eVW8ZYY5RaDO5WR_PnZeyQ9e-dWZUOJUPOCvE7W_vzS3S_CGlaSBj1Ti5Pno6xoRMG3Wm28PM3KRbzvyEAQX_odmjDHiazpO08T16VH1Rlhfl13d7BLL_tiSr7n7IME_gio5M_AVT00B-O2CBrjDi0k.7oMTovg23zvNsmDd8lE94VkEeWx9Ye9I1HzsgvK8fmc&dib_tag=se&keywords=usb+audio&qid=1744658869&s=ce-de&sprefix=usb+audio%2Celectronics%2C150&sr=1-7
[usb_c_breakout]: https://www.amazon.de/dp/B0DPF59D7X?ref=nb_sb_ss_w_as-reorder_k0_1_14&amp=&crid=38Z6Q1U5FI02O&sprefix=usb%2Bc%2Bbreakout&th=1
[rp_os]: https://www.raspberrypi.com/software/
[sox]: https://sourceforge.net/projects/sox/
[fb]: https://filebrowser.org/
[libnfc]: https://www.kali.org/tools/libnfc/
[i2c_tools]: https://www.kali.org/tools/i2c-tools/
[i2c]: https://en.wikipedia.org/wiki/I%C2%B2C
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[rp_install]: https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager
[rp_pinout]: https://pinout.xyz/pinout/i2c
