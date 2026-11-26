FROM python:3.10-slim-bookworm@sha256:5be5aaecb962a41567bc8041f1e9e3432cb085b037fe057f9a562630b2e4b370 AS python-runtime

FROM python-runtime AS git-tools
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git

FROM git-tools AS source
ARG ACTUATOR_REV=4e501e6474be3be3b79be97295478eaedf35db3b
RUN git init /actuator \
    && git -C /actuator fetch --depth=1 https://github.com/aliro-access-control/aliro-actuator.git "$ACTUATOR_REV" \
    && git -C /actuator checkout --detach FETCH_HEAD

FROM git-tools AS pn7160-source
ARG PN7160_REV=d5af4ef88244b9f962986b39eb4126a8c1c0aead
WORKDIR /pn7160
RUN apt-get update && apt-get install -y --no-install-recommends autoconf automake build-essential libtool \
    && git init \
    && git fetch --depth=1 https://github.com/NXPNFCLinux/linux_libnfc-nci.git "$PN7160_REV" \
    && git checkout --detach FETCH_HEAD
# The upstream patch uses LF, but strings.cpp has CRLF line endings.
RUN --mount=type=bind,source=patches,target=/patches \
    git -c core.whitespace=cr-at-eol apply --ignore-space-change --whitespace=fix \
        64bit_patch/ROOT_src.patch /patches/*.patch \
    && ./bootstrap \
    && ./configure --disable-static

FROM pn7160-source AS pn7160-driver
# Build the public driver without the firmware or confidential config provider.
RUN rm -r firmware \
    && rm src/libnfc-utils/src/ConfigPathProvider.cc src/libnfc-utils/inc/configPathProvider.h \
    && make -j libnfc_nci_linux.la

FROM pn7160-source AS pn7160-firmware
RUN make -j libpn7160_fw.la

FROM python-runtime AS base
ENV PYTHONPATH=/opt/aliro-actuator/src \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /opt/aliro-actuator
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt
COPY --from=source /actuator/src ./src
COPY --from=source /actuator/examples ./examples
COPY --from=source /actuator/LICENSE ./LICENSE
COPY --from=pn7160-driver /pn7160/.libs/libnfc_nci_linux-1.so.0.0.0 ./third_party/nxp_nfc/lib/
COPY --from=pn7160-source /pn7160/conf/libnfc-nci.conf /pn7160/conf/libnfc-nxp.conf /usr/local/etc/
COPY --from=pn7160-source /pn7160/conf/libnfc-nci.conf /pn7160/conf/libnfc-nxp.conf /etc/
COPY --from=pn7160-source /pn7160/LICENSE.txt /usr/share/doc/libnfc-nci/copyright
RUN --mount=type=bind,source=check_image.py,target=/tmp/check_image.py \
    python3 /tmp/check_image.py base
ENTRYPOINT ["python3"]

# Build this target locally. Publish only the base target.
FROM base AS hardware
COPY --from=pn7160-firmware /pn7160/.libs/libpn7160_fw.so.0.0.0 /usr/local/lib/libpn7160_fw.so
COPY vendor/ALIRO_IOT_SR150_FW_v46.43.14.bin ./third_party/aliro-th-additions/
RUN --mount=type=bind,source=vendor/ucitool-2.0.4-py3-none-any.whl,target=/tmp/ucitool-2.0.4-py3-none-any.whl \
    echo 'ff64a741b743b382341896668ed2f08a73298ef958bc869bbd1b67f40c7c2453  /tmp/ucitool-2.0.4-py3-none-any.whl' | sha256sum -c - \
    && echo '02d8dcb8a8fc584d502e6dabf87ed2318d1940d4df54fef46297fd9009ad2d93  third_party/aliro-th-additions/ALIRO_IOT_SR150_FW_v46.43.14.bin' | sha256sum -c - \
    && pip install --no-cache-dir --no-deps /tmp/ucitool-2.0.4-py3-none-any.whl
RUN --mount=type=bind,source=check_image.py,target=/tmp/check_image.py \
    python3 /tmp/check_image.py hardware
