# NitroHSM Installer

This is an initial "installer" which can be used to install a NitroHSM image on actual hardware.

## Building

To build the ISO image on a Debian 10.x (buster) system with `live-build` installed, clone this repository and run:

```
sudo lb build
```

and then dump the resulting `live-image-amd64.hybrid.iso` to an USB stick.

## (Re-)Installing NitroHSM on the Supermicro

Rough notes, TBC:

1. You need two USB sticks. One with this installer on it, another with `obj/disk.img.system.cpio` built for `MUEN_TARGET=supermicro-x11ssh-tf` on it.
2. Power on the system with **only** the installer USB stick inserted and a serial console attached to COM1 (115200, N81).
3. Log in as `user` with a password of `live`.
4. Insert the USB stick with the Muen CPIO image on it and mount it on `/mnt`.
5. Run `sudo ~/bin/nitrohsm-install /dev/sda /mnt/disk.img.system.cpio`.
6. Unmount `/mnt`, remove both USB sticks and run `sudo systemctl reboot` to boot into the NitroHSM.
