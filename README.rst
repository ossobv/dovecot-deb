OSSO build of dovecot 2.3.2.1
=============================

⚠️ WARNING ⚠️ This package is obsolete❗

*Instead, see:* https://repo.dovecot.org/

----

Using Docker::

    ./Docker.build

If the build succeeds, the built Debian packages are placed inside (a
subdirectory of) ``Docker.out/``.


------------
Manual build
------------

You could do things manually without Docker. In that case it would look
somewhat like this.

Note that you may have to peek inside the Dockerfile for some extra
steps to perform.

Get source::

    wget https://www.dovecot.org/releases/2.3/dovecot-2.3.1.tar.gz \
      -O dovecot_2.3.1.orig.tar.gz

    tar zxf dovecot_2.3.1.orig.tar.gz

Setup ``debian/`` dir::

    cd dovecot-2.3.1
    git clone https://github.com/ossobv/dovecot-deb.git debian

Optionally alter ``debian/changelog`` and then build::

    dpkg-buildpackage -us -uc -sa
    # skip -us and -uc if you have GPG set up properly
    # for *exactly* the identifier in the changelog


--------------------------------
Changes from Ubuntu 2.2.22 build
--------------------------------

* Assembled by:

  - taking the dovecot-ce-2.3.0 debian dir;

  - mixing it with the dovecot-2.2.22 Ubuntu/Xenial debian dir;

  - updating the pigeonhole.patch with the 0.5.0.1 source;

  - updating everything with the Debian 2.3.1-2 patches.

* Relevant changes in our case:

  - ``ssl_protocols`` had to be removed from the config (or replaced by
    ``ssl_min_protocol``);

  - ``lmtp`` is now found in a separate ``dovecot-lmtpd`` package,
    which also had to be installed.

  See also: https://wiki2.dovecot.org/Upgrading/2.3

* Changing from 2.2.22 to 2.3.0 fixed the ``imap`` crashes in
  ``libdovecot`` near ``i_stream_seek`` as discussed here:
  https://wjd.nu/notes/2018#dovecot-roundcube-mail-read-error
