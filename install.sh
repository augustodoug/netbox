#!/bin/bash

#### !! INICICANDO INSTALACAO E !!
#### !! CONFIGURACAO DO NETBOX !!
#### !! PREPARANDO AMBIENTE !! 
apt update && apt list --upgradable && apt upgrade -y
apt install gnupg vim wget aptitude lsb-release sudo -y

#### !! INSTALACAO DO POSTGRESQL !! 
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update && apt install postgresql-14 postgresql-contrib-14 postgresql-server-dev-14 -y

#### !! HABILITANDO O BANCO !!
systemctl enable postgresql && systemctl start postgresql

#### !! CONFIGURANDO O BANCO !!
sudo -Hiu postgres psql <<EOF
CREATE DATABASE netbox;
CREATE USER netbox WITH PASSWORD 'netbox';
GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;
\q
EOF

#### !! INSTALCAO REDIS SERVER !!
apt install -y redis-server

#### !! INSTALCAO DE DEPENDENCIAS !! 
apt install -y git python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev

mkdir -p /opt/netbox && cd /opt/netbox/

#### !! CLONE DO NETBOX !!
git clone -b master https://github.com/netbox-community/netbox.git .

#### !! CONFIGURACAO NETBOX !!
#### !! USUARIO E GRUPO !! 
adduser --system --group netbox
chown --recursive netbox /opt/netbox/netbox/media/

cd /opt/netbox/netbox/netbox/
cp configuration_example.py configuration.py

#### !! GERAR SECRET_KEY
python3 /opt/netbox/netbox/generate_secret_key.py

#### !! COPIAR A CHAVE

sed -i "11s/\[\]/\['*'\]/g" /opt/netbox/netbox/netbox/configuration.py
sed -i "17s/''/'netbox'/g" /opt/netbox/netbox/netbox/configuration.py
sed -i "18s/''/'netbox'/g" /opt/netbox/netbox/netbox/configuration.py
sed -i "60s/''/'$secrete_key'/g" /opt/netbox/netbox/netbox/configuration.py

echo 'pytz==2022.1' >> /opt/netbox/requirements.txt
echo 'napalm' >> /opt/netbox/requirements.txt
echo 'django-storages' >> /opt/netbox/requirements.txt

sudo /opt/netbox/upgrade.sh

systemctl restart netbox netbox-rq

source /opt/netbox/venv/bin/activate

cd /opt/netbox/netbox
python3 manage.py createsuperuser

ln -s /opt/netbox/contrib/netbox-housekeeping.sh /etc/cron.daily/netbox-housekeeping

#### !! TESTE DE VALIDACAO
python3 manage.py runserver 0.0.0.0:8000 --insecure

>> RESULTADO <<
Watching for file changes with StatReloader
Performing system checks...

System check identified no issues (0 silenced).
August 30, 2021 - 18:02:23
Django version 3.2.6, using settings 'netbox.settings'
Starting development server at http://127.0.0.1:8000/
Quit the server with CONTROL-C.
>>>>>>>>>>>> <<<<<<<<<<<<<<<<<<<<

#### !! SAIR DO MODO VENV !!
deactivate

#### !! CONFIGURANDO O GUNICORN !!

cp /opt/netbox/contrib/gunicorn.py /opt/netbox/gunicorn.py

cp -v /opt/netbox/contrib/*.service /etc/systemd/system/
systemctl daemon-reload

systemctl start netbox netbox-rq
systemctl enable netbox netbox-rq

#### !! CRIANDO CERTIFICADO PARA ACESSO HTTPS !!
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/netbox.key -out /etc/ssl/certs/netbox.crt

#### !! CONFIGURANDO NGINX !!
apt install -y nginx

cp /opt/netbox/contrib/nginx.conf /etc/nginx/sites-available/netbox

rm /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox

systemctl restart nginx redis

#### !! CONFIGURANDO PLUGINS
#### OBTERO NOME DO PLUGIN ATRAVÉS DO LINK 
#### https://github.com/netbox-community/netbox/wiki/Plugins

vim /opt/netbox/requirements.txt
echo 'NOME_DO_PLUGIN' >> /opt/netbox/requirements.txt

vim /opt/netbox/netbox/netbox/configuration.py
#### EDITAR A SEGUINTE LINHA. 'NOME_DO_PLUGIN' PODE SER

PLUGINS = [
    'NOME_DO_PLUGIN',
    ]

source /opt/netbox/venv/bin/activate
sh /opt/netbox/upgrade.sh
systemctl restart netbox netbox-rq