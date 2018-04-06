#
# Yandex ClickHouse DBMS build script for RHEL based distributions
#
# Important notes:
#  - build requires ~35 GB of disk space
#  - each build thread requires 2 GB of RAM - for example, if you
#    have dual-core CPU with 4 threads you need 8 GB of RAM
#  - build user needs to have sudo priviledges, preferrably with NOPASSWD
#
# Tested on:
#  - GosLinux IC4
#  - CentOS 6.8
#  - CentOS 7.2
#
# Copyright (C) 2016, 2017 Red Soft LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Git version of ClickHouse that we package
CH_VERSION="${CH_VERSION:-1.1.git}"

# Git tag marker (stable/testing)
CH_TAG="${CH_TAG:-0771874}"

# SSH username used to publish built packages
REPO_USER="${REPO_USER:-clickhouse}"

# Hostname of the server used to publish packages
REPO_SERVER="${REPO_SERVER:-10.81.1.162}"

# Root directory for repositories on the remote server
REPO_ROOT="${REPO_ROOT:-/var/www/html/repos/clickhouse}"

# Detect number of threads
export THREADS=4

# Build most libraries using default GCC
export PATH=${PATH/"/usr/local/bin:"/}:/usr/local/bin

# Determine RHEL major version
RHEL_VERSION=`rpm -qa --queryformat '%{VERSION}\n' '(redhat|sl|slf|centos|oraclelinux|goslinux)-release(|-server|-workstation|-client|-computenode)'`

function prepare_dependencies {

if [ ! -d lib ]; then
  mkdir lib
fi

sudo rm -rf lib/*

cd lib

# Install development packages
sudo yum -y install rpm-build redhat-rpm-config gcc-c++ readline-devel\
  unixODBC-devel subversion python-devel git wget openssl-devel m4 createrepo\
  libicu-devel zlib-devel libtool-ltdl-devel \
  cmake3 clang-5.0.1 libcxx-5.0.1-devel git



# Use GCC 6 for builds
export PATH=/opt/llvm-5.0.1/bin:${PATH}
export CC=/opt/llvm-5.0.1/bin/clang
export CXX=/opt/llvm-5.0.1/bin/clamg++

# Install Boost
wget http://downloads.sourceforge.net/project/boost/boost/1.62.0/boost_1_62_0.tar.bz2
tar xf boost_1_62_0.tar.bz2
cd boost_1_62_0
./bootstrap.sh
./b2 --toolset=clang-5 -j $THREADS
sudo PATH=$PATH ./b2 install --toolset=clang-5 -j $THREADS
cd ..

}

function make_packages {

# Clean up after previous run
rm -f ~/rpmbuild/RPMS/x86_64/clickhouse*
rm -f ~/rpmbuild/SRPMS/clickhouse*
rm -f rpm/*.zip

# Configure RPM build environment
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild
%_smp_mflags  -j'"$THREADS" > ~/.rpmmacros

# Create RPM packages
cd rpm
sed -e s/@CH_VERSION@/$CH_VERSION/ -e s/@CH_TAG@/$CH_TAG/ clickhouse.spec.in > clickhouse.spec
wget -O ~/rpmbuild/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.zip https://github.com/yandex/ClickHouse/archive/${CH_TAG}.zip
rpmbuild -bs clickhouse.spec
rpmbuild -bb clickhouse.spec

}

if [[ "$1" != "publish_only"  && "$1" != "build_only" ]]; then
  prepare_dependencies
fi
if [ "$1" != "publish_only" ]; then
  make_packages
fi
