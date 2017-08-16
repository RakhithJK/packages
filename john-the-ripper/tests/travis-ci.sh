#!/bin/bash

function do_Install_Dependencies(){
    echo
    echo '-- Installing Base Dependencies --'

    # Prepare environment
    sudo apt-get update -qq
    sudo apt-get -y -qq install \
        build-essential libssl-dev yasm libgmp-dev libpcap-dev pkg-config \
        debhelper libnet1-dev libbz2-dev wget clang zzuf libiomp-dev

    if [[ ! -f /usr/lib/x86_64-linux-gnu/libomp.so ]]; then
        # A bug somewhere?
        sudo ln -sf /usr/lib/libiomp5.so /usr/lib/x86_64-linux-gnu/libomp.so
    fi

    if [[ "$OPENCL" == "yes" ]]; then
        sudo apt-get -y -qq install fglrx-dev opencl-headers || true

        # Fix the OpenCL stuff
        mkdir -p /etc/OpenCL
        mkdir -p /etc/OpenCL/vendors
        sudo ln -sf /usr/lib/fglrx/etc/OpenCL/vendors/amdocl64.icd /etc/OpenCL/vendors/amd.icd
    fi
}

function do_Show_Compiler(){

    if [[ ! -z $CC ]]; then
        echo
        echo '-- Compiler in use --'
        $CC --version
    fi
}

function do_Build(){
    echo
    echo '-- Building JtR --'

    do_Show_Compiler

    # Configure and build
    cd src || exit 1
    eval ./configure "$ASAN_OPT $BUILD_OPTS"
    make -sj4
}

function do_Prepare_To_Test(){
    echo
    echo '-- Preparing to test --'

    # Environmnet
    do_Install_Dependencies

    # Configure and build
    do_Build
}

function do_TS_Setup(){
    echo
    echo '-- Test Suite set up --'

    # Prepare environment
    cd .. || exit 1
    git clone --depth 1 https://github.com/magnumripper/jtrTestSuite.git tests
    cd tests || exit 1
    #export PERL_MM_USE_DEFAULT=1
    (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan
    cpan install Digest::MD5
}

function do_Build_Docker_Command(){
    echo
    echo '-- Build Docker command --'

    docker_command=" \
      cd /cwd/src; \
      apt-get update -qq; \
      apt-get install -y build-essential libssl-dev yasm libgmp-dev libpcap-dev pkg-config debhelper libnet1-dev libbz2-dev wget clang $1; \
      export OPENCL=$OPENCL; \
      export CC=$CCO; \
      export EXTRAS=$EXTRAS; \
      export FUZZ=$FUZZ; \
      export AFL_HARDEN=1; \
      ./configure $ASAN_OPT $BUILD_OPTS; \
      make -sj4; \
      $2 ../.travis/tests.sh
   "
}

# Set up ASAN
if [[ "$ASAN" == "yes" ]]; then
    export ASAN_OPT="--enable-asan"
fi

# Disable buggy formats. If a formats fails its tests on super, I will burn it.
(
  cd src || exit 1
  ./buggy.sh disable
  cd .. || exit 1
)

# Apply all needed patches
wget https://raw.githubusercontent.com/claudioandre/packages/master/patches/0002-maintenance-fix-the-expected-data-type-size.patch
git apply 0002-maintenance-fix-the-expected-data-type-size.patch

if [[ "$TEST" == "usual" ]]; then
    # Needed on ancient ASAN
    export ASAN_OPTIONS=symbolize=1
    export ASAN_SYMBOLIZER_PATH
    ASAN_SYMBOLIZER_PATH=$(which llvm-symbolizer)

    # Configure and build
    do_Prepare_To_Test

    # Run the test: --test-full=0
    ../.travis/tests.sh

elif [[ "$TEST" == "ztex" ]]; then
    # ASAN using a 'recent' environment (compiler/OS)
    # clang 4 + ASAN + libOpenMP are not working on CI.

    # Build the docker command line
    do_Build_Docker_Command "libusb-1.0-0-dev" "PROBLEM='ztex'"

    # Run docker
    docker run -v "$HOME":/root -v "$(pwd)":/cwd ubuntu:devel sh -c "$docker_command"

elif [[ "$TEST" == "fresh" ]]; then
    # ASAN using a 'recent' environment (compiler/OS)
    # clang 4 + ASAN + libOpenMP are not working on CI.

    # Build the docker command line
    do_Build_Docker_Command "afl" "PROBLEM='slow'"

    # Run docker
    docker run -v "$HOME":/root -v "$(pwd)":/cwd ubuntu:devel sh -c "$docker_command"

elif [[ "$TEST" == "stable" ]]; then
    # Stable environment (compiler/OS)
    docker run -v "$HOME":/root -v "$(pwd)":/cwd centos:centos6.6 sh -c " \
      cd /cwd/src; \
      yum -y -q upgrade; \
      yum -y groupinstall 'Development Tools'; \
      yum -y install openssl-devel gmp-devel libpcap-devel bzip2-devel; \
      export OPENCL=$OPENCL; \
      export CC=$CCO; \
      export EXTRAS=$EXTRAS; \
      ./configure $ASAN_OPT $BUILD_OPTS; \
      make -sj4; \
      PROBLEM='slow' ../.travis/tests.sh
   "

elif [[ "$TEST" == "snap" ]]; then
    # Prepare environment
    sudo apt-get update -qq
    sudo apt-get install snapd

    # Install and test
    sudo snap install john-the-ripper
    sudo snap connect john-the-ripper:process-control core:process-control

elif [[ "$TEST" == "snap fedora" ]]; then
    docker run -v "$HOME":/root -v "$(pwd)":/cwd fedora:latest sh -c "
      dnf -y -q upgrade;
      dnf -y install snapd;
      snap install --channel=edge john-the-ripper;
      snap connect john-the-ripper:process-control core:process-control;
      snap alias john-the-ripper john;
      echo '--------------------------------';
      john -list=build-info;
      echo '--------------------------------'
   "

elif [[ "$TEST" == "TS" ]]; then
    # Configure and build
    do_Prepare_To_Test

    # Test Suite set up
    do_TS_Setup

    # Run the test: Test Suite
    if [[ "$OPENCL" != "yes" ]]; then
        ./jtrts.pl -stoponerror -dynamic none
    else
        # Disable failing formats
        echo 'descrypt-opencl = Y' >> john-local.conf

        ./jtrts.pl -noprelims -type opencl
    fi

elif [[ "$TEST" == "TS --restore" ]]; then
    # Configure and build
    do_Prepare_To_Test

    # Test Suite set up
    do_TS_Setup

    # Run the test: Test Suite --restore
    ./jtrts.pl --restore

elif [[ "$TEST" == "TS --internal" ]]; then
    # Configure and build
    do_Prepare_To_Test

    # Test Suite set up
    do_TS_Setup

    # Run the test: Test Suite --internal
    ./jtrts.pl -noprelims -internal

else
    echo
    echo  -----------------
    echo  "Nothing to do!!"
    echo  -----------------
fi

