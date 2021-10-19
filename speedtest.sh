#!/bin/bash
###################INSTALANDO OS PACORTES #####################
############################################################

domainSpeed=$1
domainUrl=$2
email=$3


apt update
apt upgrade

apt install -y vim sudo wget unzip apt-transport-https  
sudo addgroup speedtest  
sudo useradd -d /etc/speedtest -m -g speedtest -s /bin/bash speedtest 
sudo -u speedtest bash -c "cd /etc/speedtest && wget https://install.speedtest.net/ooklaserver/ooklaserver.sh --no-check-certificate"
sudo -u speedtest bash -c "cd /etc/speedtest && chmod +x ooklaserver.sh"
sudo -u speedtest bash -c "cd /etc/speedtest && ./ooklaserver.sh install -f" 
ln -s /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
printf '%s\n' '#!/bin/bash' '/usr/bin/su - speedtest -c "/etc/speedtest/OoklaServer --daemon"' 'exit 0' | tee -a /etc/rc.local && chmod +x /etc/rc.local

############## INSTALAR WEB SERVER ###############

##su -u bash root
apt-get install apache2 libapache2-mod-php php -y && mkdir /var/www/speedtest/ && cat <<EOF > /etc/apache2/sites-available/speedtest.conf
<virtualhost *:80>
        ServerName $domainSpeed
        ServerAdmin $email
        DocumentRoot /var/www/speedtest
        <directory /var/www/speedtest/ >
                Options FollowSymLinks
                AllowOverride All
        </directory>
        LogLevel warn
        ErrorLog ${APACHE_LOG_DIR}/error_speedtest.log
        CustomLog ${APACHE_LOG_DIR}/access_speedtest.log combined
</virtualhost>
EOF

sudo a2ensite speedtest 
systemctl restart apache2

#######################SECURITY ################

sed -i '25c\ServerTokens Prod' /etc/apache2/conf-available/security.conf
sleep 2
sed -i '36c\ServerSignature Off' /etc/apache2/conf-available/security.conf
sleep 2
systemctl restart apache2
sleep 3
######################### INSTALAR CERTIFICADO ########################
sudo apt install letsencrypt python-certbot-apache -y
sleep 25
systemctl stop apache2
sleep 1
sed -i '45c\OoklaServer.allowedDomains = *.ookla.com, *.speedtest.net, *.'$domainUrl'' /etc/speedtest/OoklaServer.properties
sleep 1
################################### FAZENDO CRONTAB ###################################

cat <<EOF > /etc/speedtest/renovassl.sh
#!/bin/bash
# Para o apache 
/usr/bin/systemctl stop apache2
 
# Aguarda 10 seg (tempo do apache parar) 
sleep 10
 
# Renova o certificado
/usr/bin/certbot -q renew
 
# Aguarda o certificado renovar
sleep 30
 
# Altera as permissoes para o usuÃ¡rio speedtest conseguir ler os certificados
/usr/bin/chown speedtest. /etc/letsencrypt/ -R
 
# Aguarda 2 seg
sleep 2
 
# Restarta o apache 
/usr/bin/systemctl restart apache2
sleep 10
# Restarta o apache mais uma vez so por garantia (opcional)
/usr/bin/systemctl restart apache2
 
# Para o ooklaserver
/etc/speedtest/ooklaserver.sh stop 
sleep 120
# Inicia o ooklaserver
/usr/bin/su - speedtest -c "/etc/speedtest/OoklaServer --daemon"
EOF
sleep 1
################################ CONTRAB ATIVAR ####################
chmod +x /etc/speedtest/renovassl.sh
sleep 5
chown speedtest. /etc/speedtest/renovassl.sh
sleep 5
echo '00 00   1 * *   root    /etc/speedtest/renovassl.sh' >> /etc/crontab
sleep 5
############################# CROSSDOMAIN ###############################
cd /var/www/speedtest
sleep 1
wget http://install.speedtest.net/httplegacy/http_legacy_fallback.zip
sleep 10

unzip http_legacy_fallback.zip
rm http_legacy_fallback.zip -f
mv /var/www/speedtest/speedtest/* /var/www/speedtest/
rm /var/www/speedtest/speedtest/ -rf
rm *.asp *.aspx *.jsp

cat <<EOF > /var/www/speedtest/crossdomain.xml
<?xml version="1.0"?>
<cross-domain-policy>
  <allow-access-from domain="*.speedtest.net" />
  <allow-access-from domain="*.ookla.com" />
  <allow-access-from domain="*.$domainUrl" />
</cross-domain-policy>
EOF
sed -i '5c\<allow-access-from domain="*.'$domainUrl'" />' /var/www/speedtest/crossdomain.xml
####################### COLOCANDO CERTIFICADO  ###########
letsencrypt --authenticator standalone --installer apache -d $domainSpeed --agree-tos -m $email 

sed -i '97c\openSSL.server.certificateFile = /etc/letsencrypt/live/'$domainSpeed'/fullchain.pem' /etc/speedtest/OoklaServer.properties
sed -i '98c\openSSL.server.privateKeyFile = /etc/letsencrypt/live/'$domainSpeed'/privkey.pem' /etc/speedtest/OoklaServer.properties

cp /etc/speedtest/OoklaServer.properties /etc/speedtest/OoklaServer.properties.default

chown speedtest. /etc/letsencrypt/ -R

##sudo reboot
sudo reboot
