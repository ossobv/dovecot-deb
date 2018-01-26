OSSO build of dovecot 2.3.0
===========================

Get source::

    wget https://dovecot.org/releases/2.3/dovecot-2.3.0.tar.gz \
      -O dovecot_2.3.0.orig.tar.gz

    tar zxf dovecot_2.3.0.orig.tar.gz
    mv dovecot-ce-2.3.0 dovecot-2.3.0

Setup ``debian/`` dir::

    cd dovecot-2.3.0
    rm -rf debian
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

  - updating the pigeonhole.patch with the 0.5.0.1 source.

* Relevant changes in our case:

  - ``ssl_protocols`` had to be removed from the config (or replaced by
    ``ssl_min_protocol``);

  - ``lmtp`` is now found in a separate ``dovecot-lmtpd`` package,
    which also had to be installed.

  See also: https://wiki2.dovecot.org/Upgrading/2.3

* Changing from 2.2.22 to 2.3.0 fixed the ``imap`` crashes in
  ``libdovecot`` near ``i_stream_seek`` as discussed here:
  https://wjd.nu/notes/2018#dovecot-roundcube-mail-read-error