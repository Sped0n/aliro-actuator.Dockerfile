import argparse
import ctypes
import subprocess
import sys
from importlib.util import find_spec
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Check actuator image contents.")
    parser.add_argument("target", choices=("base", "hardware"))
    target = parser.parse_args().target

    subprocess.run([sys.executable, "-m", "pip", "check"], check=True)
    if find_spec("aliro_actuator") is None:
        raise SystemExit("The actuator package is missing")

    pn7160_driver = Path("third_party/nxp_nfc/lib/libnfc_nci_linux-1.so.0.0.0")
    ctypes.CDLL(str(pn7160_driver))

    pn7160_firmware = Path("/usr/local/lib/libpn7160_fw.so")
    sr150_firmware = Path("third_party/aliro-th-additions/ALIRO_IOT_SR150_FW_v46.43.14.bin")
    if target == "base":
        if (
            find_spec("ucitool") is not None
            or sr150_firmware.exists()
            or pn7160_firmware.exists()
        ):
            raise SystemExit("The public base image contains the NXP wheel or firmware")
        return

    from aliro_actuator.access_protocol import user_device

    ctypes.CDLL(str(pn7160_firmware))
    if not sr150_firmware.is_file():
        raise SystemExit("The SR150 firmware is missing")
    print(f"{user_device.UserDevice.__name__} and both PN7160 libraries loaded")


if __name__ == "__main__":
    main()
