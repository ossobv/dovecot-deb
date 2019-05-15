FROM ubuntu:xenial
MAINTAINER Walter Doekes <wjdoekes+dovecot@osso.nl>

# This one should be before the From, but it's not legal for Docker 1.13
# yet. Use a hack to s/debian:stretch/debian:OTHER/g above instead.
ARG oscodename=xenial
ARG upname=dovecot
ARG upversion=2.3.6
ARG debepoch=1:
ARG debversion=0osso1

ARG pigeonholeversion=0.5.5

ENV DEBIAN_FRONTEND noninteractive

# Copy debian dir, check version
RUN mkdir -p /build/debian
COPY ./changelog /build/debian/changelog
RUN . /etc/os-release && \
    fullversion="${upversion}-${debversion}+${ID%%[be]*}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=medium" && \
    head -n1 /build/debian/changelog && \
    if test "$(head -n1 /build/debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
#RUN sed -i -e 's:deb.debian.org:apt.osso.nl:;s:security.debian.org:apt.osso.nl/debian-security:' /etc/apt/sources.list
#RUN sed -i -e 's:security.ubuntu.com:apt.osso.nl:;s:archive.ubuntu.com:apt.osso.nl:' /etc/apt/sources.list
#RUN printf 'deb http://ppa.osso.nl/ubuntu xenial acos\n\
#deb-src http://ppa.osso.nl/ubuntu xenial acos\r\n' >/etc/apt/sources.list.d/osso-ppa.list
#RUN apt-key adv --keyserver pgp.mit.edu --recv-keys 0xBEAD51B6B36530F5
RUN apt-get update -q
RUN apt-get install -y apt-utils
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
    bzip2 ca-certificates curl git \
    build-essential dh-autoreconf devscripts dpkg-dev equivs quilt

# Hardcode sha512sums. You may pass these as build-arg too though.
ARG upsha512=\
ec28af2efcbd4ab534298c3342709251074dcdb0f0f4bcad0d24b996b273387e\
2ce557d7ab54abafb69be3ed7dd61f25c82b9710d78156932e2eff7f941c9eb2
ARG pigeonholesha512=\
21519fc9b1152a947b64ce4251e1a4bdbe003b48233b1856a32696f9c1e29f73\
0268c56eb38f9431bbfac345e6cd42e8c78c87d0702f39ebf20c6d326dcdbb94

# Set up upstream source, move debian dir and jump into dir.
#
# Trick to allow caching of asterisk*.tar.gz files. Download them
# once using the curl command below into .cache/* if you want. The COPY
# is made conditional by the "[2]" "wildcard". (We need one existing
# file (README.rst) so the COPY doesn't fail.)
COPY ./README.rst .cache/${upname}_${upversion}.orig.tar.g[z] /build/
RUN if ! test -s /build/${upname}_${upversion}.orig.tar.gz; then \
    url="https://dovecot.org/releases/2.3/${upname}-${upversion}.tar.gz" && \
    echo "Fetching: ${url}" >&2 && \
    curl --fail "${url}" >/build/${upname}_${upversion}.orig.tar.gz; fi
RUN sha512sum /build/${upname}_${upversion}.orig.tar.gz && \
    echo "$upsha512  /build/${upname}_${upversion}.orig.tar.gz" | sha512sum -c - && \
    cd /build && tar zxf "${upname}_${upversion}.orig.tar.gz" && \
    mv debian "${upname}-${upversion}/"

# Special tricks: fetch and update pigeonhole/sieve/managesieve patch.
COPY ./README.rst .cache/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.g[z] /build/
RUN if ! test -s /build/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz; then \
    url="https://pigeonhole.dovecot.org/releases/2.3/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz" && \
    echo "Fetching: ${url}" >&2 && \
    curl --fail "${url}" >/build/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz; fi
RUN sha512sum /build/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz && \
    echo "$pigeonholesha512  /build/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz" | sha512sum -c - && \
    mkdir /build/pigeonhole /tmp/pigeonhole && \
    tar -zx --strip-components=1 -C /build/pigeonhole -f /build/dovecot-2.3-pigeonhole-$pigeonholeversion.tar.gz && \
    cd / && ( diff -uNr tmp/pigeonhole build/pigeonhole >build/pigeonhole.patch || true ) && \
    rmdir /tmp/pigeonhole

WORKDIR "/build/${upname}-${upversion}"

# Apt-get prerequisites according to control file.
COPY ./control debian/control
RUN mk-build-deps --install --remove --tool "apt-get -y" debian/control

# Set up build env
RUN printf "%s\n" \
    QUILT_PATCHES=debian/patches \
    QUILT_NO_DIFF_INDEX=1 \
    QUILT_NO_DIFF_TIMESTAMPS=1 \
    'QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"' \
    'QUILT_DIFF_OPTS="--show-c-function"' \
    >/root/.quiltrc && \
    cp /root/.quiltrc /bin/.quiltrc
COPY . debian/
# .. and remove .cache which we unfortunately added because of "COPY .".
RUN rm -rf debian/.cache

RUN mv /build/pigeonhole.patch debian/patches/pigeonhole.patch

# Build, but become 'bin' before we do, because the next postfix tests
# refuse to run as 'root'. And yes, we chown '..' because
# dpkg-buildpackage touches some files there too.
RUN chown -R bin ..
USER bin
RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc -sa
USER root

# TODO: for bonus points, we could run quick tests here;
# for starters dpkg -i tests?

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename \
    upname=$upname upversion=$upversion debversion=$debversion
CMD . /etc/os-release && fullversion=${upversion}-${debversion}+${ID%%[be]*}${VERSION_ID} && \
    dist=Docker.out && \
    if ! test -d "/${dist}"; then echo "Please mount ./${dist} for output" >&2; false; fi && \
    echo && . /etc/os-release && mkdir "/${dist}/${oscodename}/${upname}_${fullversion}" && \
    mv /build/*${fullversion}* "/${dist}/${oscodename}/${upname}_${fullversion}/" && \
    mv /build/${upname}_${upversion}.orig.tar.gz "/${dist}/${oscodename}/${upname}_${fullversion}/" && \
    chown -R ${UID}:root "/${dist}/${oscodename}" && \
    cd / && find "${dist}/${oscodename}/${upname}_${fullversion}" -type f && \
    echo && echo 'Output files created succesfully'
