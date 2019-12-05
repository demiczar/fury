#!/bin/bash
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "sudo ./$(basename $0)"
   exit 1
fi
export YARA_VERSION=3.4.0
export SSDEEP_VERSION=2.13
export VOLATILITY_VERSION=2.6.1
export VOLUTILITY_VERSION=1.2.2

# Install OS Dependancies
apt update
apt -yq install autoconf \
                automake \
		autopoint \
                curl \
                git \
                libimage-exiftool-perl \
                libtool \
                python-dev \
		libpff-python \
                python-pip

#sudo apt-get install automake autoconf

# install Mongo
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.2.list
apt-get update --allow-unauthenticated
apt-get install -yq mongodb-org --allow-unauthenticated

# Install packages from source
# Make Tmp Dir
mkdir ~/tmp_build

# Install Yara
cd ~/tmp_build
curl -sSL https://github.com/plusvic/yara/archive/v$YARA_VERSION.tar.gz | tar -xzC .
cd yara-$YARA_VERSION
bash build.sh
make install
cd yara-python
python setup.py build
python setup.py install
cd ../..
rm -rf yara-$YARA_VERSION
ldconfig

# Install SSDEEP
cd ~/tmp_build &&\
curl -sSL http://sourceforge.net/projects/ssdeep/files/ssdeep-${SSDEEP_VERSION}/ssdeep-${SSDEEP_VERSION}.tar.gz/download | tar -xzC .
cd ssdeep-${SSDEEP_VERSION}
./configure
make install
pip install pydeep
cd ..
rm -rf ssdeep-${SSDEEP_VERSION}

# Get the maxmind database for ip lookup
cd ~/tmp_build
curl -sSL http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz > GeoLite2-City.mmdb.gz
gzip -d GeoLite2-City.mmdb.gz
mv GeoLite2-City.mmdb /usr/share/GeoIP/

# Install and Build libpff
cd ~/tmp_build
# https://github.com/libyal/libpff.git
git clone https://github.com/libyal/libpff.git
cd libpff/
./synclibs.sh
./autogen.sh
./configure --enable-python
make
make install
ldconfig

# Install Volatility
cd ~/tmp_build
git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
git checkout tags/$VOLATILITY_VERSION
python setup.py install

# Get VolUtility
cd /opt
curl -SL https://github.com/kisec/VolUtility/archive/v${VOLUTILITY_VERSION}.tar.gz | tar -xz
mv VolUtility-${VOLUTILITY_VERSION} VolUtility

# Install PIP Requirements.
cd /opt/VolUtility
pip install -r requirements.txt

# Clean Up
rm -rf ~/tmp_build
apt remove -yq automake \
               autopoint \
               gettext \
               autoconf \
               gettext \
               pkg-config \
               libpff-python \
               libtool
apt clean

# Setup
cp /opt/VolUtility/volutility.conf.sample ~/.volutility.conf
mkdir ~/dbpath
chmod 755 ~/dbpath
systemctl start mongod.service
sleep 5
cd /opt/VolUtility/
python manage.py migrate
sleep 5
systemctl stop mongod.service
systemctl disable mongod.service
chown $SUDO_USER:$SUDO_USER ~/.volutility.conf
chown $SUDO_USER:$SUDO_USER ~/.volatilityrc
chown $SUDO_USER:$SUDO_USER ~/dbpath -R
chown $SUDO_USER:$SUDO_USER /opt/VolUtility -R

#
# Make directory to put the memory images files
#
mkdir ~/images
chmod 755 ~/images
cd ~/images
echo "Images folder made at location:"
echo " "
pwd
echo " "
echo " "
echo " "
echo " "
echo Starting VolUtility...
echo ===================
echo " "
echo "Copy and paste each of the following that start with #"
echo ===================
echo "# sudo systemctl start mongod.service"
echo " "
echo "# cd /opt/VolUtility/"
echo " "
echo optional VT_APIKEY add in ~/.volutility.conf
echo "# vi /home/ubuntu/.volutility.conf"
echo "and add YOUR personal API key from Virustotal.com" 
echo " "
echo "-------------------------------------------------------"
echo " "
echo "Run the following command to start the web server"
echo " "
IPADD=`hostname -i`
echo " "
echo "# python manage.py runserver $IPADD:8080"
echo " "
echo "-------------------------------------------------------"
echo "Make sure you have YOUR address listed in the "
echo "security group for SSH, port 8080, and "
echo "port 27017 for the internal SG"
