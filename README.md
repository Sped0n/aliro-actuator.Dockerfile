# `aliro-actuator.Dockerfile`

Docker image for the [Aliro actuator](https://github.com/aliro-access-control/aliro-actuator).

## Usage

Use a Raspberry Pi with 64-bit Linux, Docker Engine, Docker Compose v2, and `curl`.

### Build

Read [NXP's license](https://github.com/NXP/aliro-th-additions/blob/e8db11cabcfe589993dbe6f2d0e288d75abe233b/LICENSE.txt), then stage the NXP files:

```sh
./prepare-vendor.sh --download
```

Pass the directory containing the NXP files instead of `--download` to use local copies.

Build one image for both services. Choose one command:

```sh
# Build from source.
docker build --tag aliro-actuator:local .

# Or reuse a published base that includes the PN7160 GPIO v2 patch.
# Run docker login ghcr.io first if the package is private.
docker build --tag aliro-actuator:local \
  --build-context base=docker-image://ghcr.io/sped0n/aliro-actuator:latest .
```

### Run

Stop any host process using the hardware. Choose a service:

| Service | Host setup |
| --- | --- |
| `nfc` | Enable `/dev/i2c-1`. Use a Pi 4 with GPIO character-device API v2 (Linux 5.10 or later). Wire PN7160 interrupt to GPIO 23, enable to GPIO 24, and firmware download to GPIO 25. If the header controller (`pinctrl-bcm2711`) is not at `/dev/gpiochip0`, change the host side of its mapping in `compose.yml`. |
| `ble-uwb` | Follow the [Murata board firmware setup](https://github.com/aliro-access-control/aliro-actuator/blob/4e501e6474be3be3b79be97295478eaedf35db3b/third_party/readme.md) before use. If the adapter is not at `/dev/ttyUSB0`, change the host path in `compose.yml`. Start a new container after reconnecting it. |

```sh
# PN7160
docker compose run --rm nfc

# Murata
docker compose run --rm ble-uwb
```

- If you previously exported the NFC pins through sysfs, reboot before switching to the new image so the driver can claim them. The driver can update PN7160 firmware on startup.
- To check the Murata serial link, run `docker compose run --rm ble-uwb -m examples.uwb.uci_example`. The example can upload SR150 firmware if the chip is not in UCI mode.

### Run your own script

Save `my_example.py` in this repository. Use `nfc` or `ble-uwb` for the hardware your script needs:

```sh
docker compose run --rm \
  --volume "$PWD/my_example.py:/opt/aliro-actuator/my_example.py:ro" \
  nfc my_example.py
```
