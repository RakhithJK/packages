#!/bin/bash -e

function do_Install_Base_Dependencies(){
    echo
    echo '-- Installing Base Dependencies --'

    if [[ $BASE == "debian" ]]; then
        apt-get update -qq

        # Base dependencies
        apt-get -y -qq install build-essential git clang patch bison flex \
                               python-dev python3-dev \
                               autotools-dev autoconf gettext pkgconf autopoint yelp-tools \
                               docbook docbook-xsl libtext-csv-perl \
                               zlib1g-dev libdbus-glib-1-dev \
                               libtool libicu-dev libnspr4-dev \
                               policykit-1 cppcheck > /dev/null

    elif [[ $BASE == "fedora" ]]; then
        dnf -y -q upgrade

        # Base dependencies
        dnf -y -q install @c-development @development-tools clang redhat-rpm-config gnome-common python-devel \
                          pygobject2 dbus-python perl-Text-CSV perl-XML-Parser gettext-devel gtk-doc ninja-build \
                          zlib-devel libffi-devel \
                          libtool libicu-devel nspr-devel cppcheck
    else
        echo
        echo '-- Error: invalid BASE code --'
        exit 1
    fi
}

function do_Install_Dependencies(){
    echo
    echo '-- Installing Dependencies --'

    if [[ $BASE == "debian" ]]; then
        # Testing dependencies
        apt-get -y -qq install libgtk-3-dev gir1.2-gtk-3.0 xvfb gnome-desktop-testing dbus-x11 dbus \
                               libedit-dev > /dev/null

    elif [[ $BASE == "fedora" ]]; then
        # Testing dependencies
        dnf -y -q install gtk3 gtk3-devel gobject-introspection Xvfb gnome-desktop-testing dbus-x11 dbus \
                          cairo intltool libxslt bison nspr zlib python3-devel dbus-glib libicu libffi pcre libxml2 libxslt libtool flex \
                          cairo-devel zlib-devel libffi-devel pcre-devel libxml2-devel libxslt-devel \
                          libedit-devel libasan libubsan lcov mesa-libGL-devel
    fi
}

function do_Install_Extras(){
    echo
    echo '-- Installing Extra Dependencies --'

    if [[ $BASE == "debian" ]]; then
        # Distros development versions of needed libraries
        apt-get -y -qq install libgirepository1.0-dev > /dev/null

    elif [[ $BASE == "fedora" ]]; then
        # Distros development versions of needed libraries
        dnf -y -q install gobject-introspection-devel
    fi
}
