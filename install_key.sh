cd
rm -rf .ssh
mkdir .ssh
cd .ssh
wget --no-check-certificate https://raw.githubusercontent.com/nangsontay/XrayR-install-script/master/key.tar.gz
rm -rf key.tar.gz
cd 
chmod 700 .ssh
chmod 644 .ssh/*
chmod 600 .ssh/authorized_keys
chown -R root .ssh
rm -rf install_key.sh
history -c
