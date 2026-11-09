# Root filesystem for the test VMs, set up the way c-cpp.yml sets up its runner.
FROM docker.io/library/ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential autoconf automake libtool libtool-bin pkg-config git ca-certificates \
        libnl-3-dev libnl-genl-3-dev xfslibs-dev uuid-dev xfsprogs libgdbm-dev gawk fio attr \
        libattr1-dev libacl1-dev libaio-dev libgcrypt20-dev bc perl python3 psmisc kmod \
        util-linux e2fsprogs procps file sudo acl iproute2 \
    && rm -rf /var/lib/apt/lists/*
COPY src /src
RUN cd /src/ntfsprogs-plus && ./autogen.sh > /dev/null && ./configure > /dev/null \
    && make -j"$(nproc)" > /dev/null && make install > /dev/null && ldconfig \
    && cd /src/exfat-testsuites && tar xzf xfstests-exfat.tgz && rm xfstests-exfat.tgz \
    && cd xfstests-exfat && cp local.config.ntfs local.config && echo "" >> local.config \
    && echo 'MOUNT_OPTIONS="-osymlink=native,native_symlink=rel"' >> local.config \
    && make -j"$(nproc)" > /dev/null \
    && sed -i 's/^yes | \$LVM_PROG lvcreate /$LVM_PROG lvcreate -y /' tests/generic/108 \
    && echo 'FSTYP=ntfs' >> local.config \
    && useradd fsgqa && useradd 123456-fsgqa && mkdir -p /mnt/test /mnt/scratch \
    && ln -s /src/vm-init.sh /vmtest
