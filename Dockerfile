# MingW64 + Qt5 (optionally) for cross-compiling to Windows
# Based on ArchLinux image
ARG DOCKER_TAG=qt

FROM archlinux:base-devel as base
MAINTAINER Jan-Kristian Mathisen <krestean@gmail.com>

# Create devel user...
RUN useradd -m -d /home/devel -u 1000 -U -G users,tty -s /bin/bash devel
RUN echo 'devel ALL=(ALL) NOPASSWD: /usr/sbin/pacman, /usr/sbin/makepkg' >> /etc/sudoers;

RUN mkdir -p /workdir && chown devel.users /workdir

#Workaround for the "setrlimit(RLIMIT_CORE): Operation not permitted" error
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

RUN pacman -Syyu --noconfirm --noprogressbar 

# Add packages to the base system
RUN pacman -S --noconfirm --noprogressbar \
        imagemagick git wget \
        pacman-contrib expac nano openssh python python-mako python-numpy

ENV EDITOR=nano

# Install yay
USER devel
ARG BUILDDIR=/tmp/tmp-build
RUN  mkdir "${BUILDDIR}" && cd "${BUILDDIR}" && \
     git clone https://aur.archlinux.org/yay.git && \
     cd yay && makepkg -si --noconfirm --rmdeps && \
     rm -rf "${BUILDDIR}"

USER root

# Add mingw-repo
RUN    echo "[ownstuff]" >> /etc/pacman.conf \
    && echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf \
    && echo "Server = https://martchus.no-ip.biz/repo/arch/\$repo/os/\$arch" >> /etc/pacman.conf \
    && echo "Server = https://ftp.f3l.de/~martchus/\$repo/os/\$arch" >> /etc/pacman.conf \
    && echo "keyserver hkp://pgp.mit.edu:11371" >> /etc/pacman.d/gnupg/gpg.conf \
    && echo "keyserver hkp://keyserver.ubuntu.com" >> /etc/pacman.d/gnupg/gpg.conf \
    && pacman-key --recv-keys B9E36A7275FC61B464B67907E06FE8F53CDC6A4C \
    && pacman -Sy 

# Install essential MingW packages (from ownstuff)
RUN pacman -S --noconfirm --noprogressbar \
        mingw-w64-binutils \
        mingw-w64-crt \
        mingw-w64-gcc \
        mingw-w64-headers \
        mingw-w64-winpthreads \
        mingw-w64-cmake \
        mingw-w64-tools \
        mingw-w64-zlib 

# Cleanup
USER root
RUN pacman -Scc --noconfirm
RUN paccache -r -k0; \
    rm -rf /usr/share/man/*; \
    rm -rf /tmp/*; \
    rm -rf /var/tmp/*;
USER devel
RUN yay -Scc

ENV HOME=/home/devel

WORKDIR /workdir
ONBUILD USER root
ONBUILD WORKDIR /


FROM base as qt

USER root
# Install Qt5 and some other MingW packages (from ownstuff)
RUN pacman -S --noconfirm --noprogressbar \        
        mingw-w64-bzip2 \
        mingw-w64-expat \
        mingw-w64-fontconfig \
        mingw-w64-freeglut \
        mingw-w64-freetype2 \
        mingw-w64-gettext \
        mingw-w64-libdbus \
        mingw-w64-libiconv \
        mingw-w64-libjpeg-turbo \
        mingw-w64-libpng \
        mingw-w64-libtiff \
        mingw-w64-libxml2 \
        mingw-w64-mariadb-connector-c \
        mingw-w64-openssl \
        mingw-w64-openjpeg \
        mingw-w64-openjpeg2 \
        mingw-w64-pcre \
        mingw-w64-pdcurses \
        mingw-w64-pkg-config \
        mingw-w64-readline \
        mingw-w64-sdl2 \
        mingw-w64-sqlite \
        mingw-w64-termcap

# Install AUR packages
USER devel
RUN yay -S --noconfirm --noprogressbar --needed \
        mingw-w64-boost \
        mingw-w64-eigen \
        mingw-w64-configure \
        mingw-w64-python-bin \
        #These are required by gnuradio 
        mingw-w64-pybind11 \
        mingw-w64-cblas \
        mingw-w64-gmp \
        mingw-w64-gsl \
        mingw-w64-qwt \
        mingw-w64-fftw

# Install qt packages

RUN yay -S --noconfirm --noprogressbar --needed \
        mingw-w64-qt5-base-static \
        mingw-w64-qt5-location-static \
        mingw-w64-qt5-quickcontrols-static \
        mingw-w64-qt5-quickcontrols2-static \
        mingw-w64-qt5-imageformats-static \
        mingw-w64-qt5-charts-static \
        mingw-w64-qt5-svg-static \
        mingw-w64-qt5-multimedia-static \
        mingw-w64-qt5-script-static \
        mingw-w64-qt5-winextras-static \
        mingw-w64-qt5-graphicaleffects-static \
        mingw-w64-qt5-tools-static \
        mingw-w64-qt5-translations \
        mingw-w64-qt5-websockets-static \
        mingw-w64-qt5-sensors-static

ENV CMAKE_PREFIX_PATH="/usr/x86_64-w64-mingw32/lib/qt"

# Cleanup
USER root

# Install gnuradio
COPY patches /opt/patches
RUN \
    cd /opt && \
    #Buld 'log4cpp'
    git clone https://git.code.sf.net/p/log4cpp/codegit log4cpp && \
    cd /opt/log4cpp && git apply /opt/patches/log4cpp.patch && \
    mkdir /opt/log4cpp/build && cd /opt/log4cpp/build && \
    x86_64-w64-mingw32-cmake .. && make -j$(nproc) && make install && cd /opt && \
    \
    # build libsndfile 
    git clone https://github.com/libsndfile/libsndfile.git && \
    mkdir /opt/libsndfile/build && cd /opt/libsndfile/build && \
    x86_64-w64-mingw32-cmake -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DENABLE_EXTERNAL_LIBS=OFF  -DBUILD_SHARED_LIBS=OFF .. && \
    make -j$(nproc) && make install && cd /opt && \
    \
    # Build Volk
    git clone --recurse-submodules https://github.com/gnuradio/volk.git && \
    mkdir /opt/volk/build && cd /opt/volk && \
    cd /opt/volk/build && \
    x86_64-w64-mingw32-cmake -DENABLE_TESTING=OFF -DENABLE_PROFILING=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_SHARED_LIBS=OFF .. && \
    make -j$(nproc) && make install && cd /opt && \
    \
    # Build Quazip
    git clone https://github.com/stachenov/quazip.git && \
    mkdir /opt/quazip/build/ && cd /opt/quazip/build && \
    x86_64-w64-mingw32-cmake -DBUILD_SHARED_LIBS=OFF .. && \
    make -j$(nproc) && make install && cd /opt && \
    \
    # Build GnuRadio
    git clone https://github.com/gnuradio/gnuradio.git && \
    mkdir /opt/gnuradio/build && cd /opt/gnuradio && \
    git apply /opt/patches/gnuradio.patch && \
    cd /opt/gnuradio/build && \
    x86_64-w64-mingw32-cmake -DENABLE_TESTING=OFF -DENABLE_GR_UTILS=OFF -DENABLE_PYTHON=OFF -DBUILD_SHARED_LIBS=OFF -DPYTHON_LIBRARY=/usr/x86_64-w64-mingw32/lib/libpython37.dll.a -DPYTHON_INCLUDE_DIR=/usr/x86_64-w64-mingw32/include/python37 .. && \
    make -j$(nproc) && make install && cd /opt

RUN pacman -Scc --noconfirm
RUN paccache -r -k0; \
    rm -rf /usr/share/man/*; \
    rm -rf /tmp/*; \
    rm -rf /var/tmp/*;
USER devel
RUN yay -Scc

WORKDIR /workdir
ONBUILD USER root
ONBUILD WORKDIR /


FROM ${DOCKER_TAG} as current
USER devel
WORKDIR /workdir
ONBUILD USER root
ONBUILD WORKDIR /
