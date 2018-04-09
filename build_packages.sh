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

CH_FULL_TAG="${CH_FULL_TAG:-07718746959cfc85fcb8ffd29d97c8e217b082a2}"

# SSH username used to publish built packages
REPO_USER="${REPO_USER:-clickhouse}"

# Hostname of the server used to publish packages
REPO_SERVER="${REPO_SERVER:-10.81.1.162}"

# Root directory for repositories on the remote server
REPO_ROOT="${REPO_ROOT:-/var/www/html/repos/clickhouse}"

# Detect number of threads
export THREADS=$(grep -c ^processor /proc/cpuinfo)

# Build most libraries using default GCC
export PATH=${PATH/"/usr/local/bin:"/}:/usr/local/bin

# Determine RHEL major version
RHEL_VERSION=`rpm -qa --queryformat '%{VERSION}\n' '(redhat|sl|slf|centos|oraclelinux|goslinux)-release(|-server|-workstation|-client|-computenode)'`

function prepare_dependencies {

# Install development packages

# Required repos:
# CentOS 6:
# - epel-6
# CentOS 7:
# - epel-7
sudo yum -y install rpm-build redhat-rpm-config gcc-c++ readline-devel\
  unixODBC-devel subversion python-devel git wget openssl-devel m4 createrepo\
  libicu-devel zlib-devel libtool-ltdl-devel \
  cmake3 centos-release-scl devtoolset-7

}

function make_packages {

source /opt/rh/devtoolset-7/enable
# Clean up after previous run
rm -f ~/rpmbuild/RPMS/x86_64/clickhouse*
rm -f ~/rpmbuild/SRPMS/clickhouse*
rm -f rpm/*.zip

TAR=~/rpmbuild/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.tar

# Configure RPM build environment
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild
%_smp_mflags  -j'"$THREADS" > ~/.rpmmacros
rm -f ${TAR}

# Create RPM packages
cd rpm
sed -e s/@CH_VERSION@/$CH_VERSION/ -e s/@CH_TAG@/$CH_TAG/ -e s/@CH_FULL_TAG@/${CH_FULL_TAG}/ clickhouse.spec.in > clickhouse.spec
if [ -d ClickHouse ] ; then 
  (cd ClickHouse && git checkout ${CH_FULL_TAG})
else
  git clone --recursive https://github.com/yandex/ClickHouse
  (cd ClickHouse && git checkout ${CH_FULL_TAG})
fi
(cd ClickHouse && \
    git archive --format=tar --prefix=ClickHouse-${CH_FULL_TAG}/ HEAD > ${TAR} && \
    echo Running git archive submodules... && \
    p=`pwd` && (echo .; git submodule foreach) | while read entering path ; do \
        temp="${path%\'}"; \
        temp="${temp#\'}"; \
        path=$temp; \
        [ "$path" = "" ] && continue; \
        (cd $path && git archive --prefix=ClickHouse-${CH_FULL_TAG}/$path/ HEAD > ~/rpmbuild/tmp.tar && tar --concatenate --file=${TAR} ~/rpmbuild/tmp.tar && rm -f ~/rpmbuild/tmp.tar ); \
done) 
rpmbuild -bs clickhouse.spec
rpmbuild -bb clickhouse.spec
cd -
}

if [[ "$1" != "publish_only"  && "$1" != "build_only" ]]; then
  prepare_dependencies
fi
if [ "$1" != "publish_only" ]; then
  make_packages
fi
