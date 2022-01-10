wd=$(cd `dirname $0` && pwd)

main() {
  check_python
  install_pkg python3-pip
  install_pkg python3-venv
  start_depl
}

check_python() {
  python3 --version > /dev/null
  if [ $? -eq 0 ]; then
    PYTHON=python3
    return
  fi
  python --version > /dev/null
  if [ $? -eq 0 ]; then
    PYTHON=python
    return
  fi
  echo "could not find python installation"
  exit 1
}

install_pkg() {
  pip_installed=`apt -qq list $1 | grep installed | wc -l`
  if [ "$pip_installed" == "0" ]; then
    echo "installing $1"
    sudo apt install -y "$1"
    if [ $? -ne 0 ]; then
      echo "failed to install $1"
      exit 1
    fi
  fi
}

generate_service() {
  file=$1
  if [ -f "$file" ]; then
    rm "$file"
    if [ $? -ne 0 ]; then
      echo "failed to remove $file"
      exit 1
    fi
  fi

  echo '[Unit]' >> "$file"
  echo 'Description=ps4-exploit' >> $file
  echo 'After=network.target' >> $file
  echo '[Service]' >> $file
  echo "User=$USER" >> $file
  echo "Group=www-data" >> $file
  echo "WorkingDirectory=$wd" >> $file
  echo "ExecStart=/bin/bash -c '\"$wd/start.sh\"'" >> $file
  echo "[Install]" >> $file
  echo "WantedBy=multi-user.target" >> $file
}

generate_nginx() {
  echo "server {" >> $DOMAIN
  echo "    listen 80;" >> $DOMAIN
  echo "    server_name $DOMAIN www.$DOMAIN;" >> $DOMAIN
  echo "    location / {" >> $DOMAIN
  echo "        include proxy_params;" >> $DOMAIN
  echo "        proxy_pass http://unix:$wd/nginx.sock;" >> $DOMAIN
  echo "    }" >> $DOMAIN
  echo "}" >> $DOMAIN
}

setup_service() {
  if [ -f "/etc/systemd/system/$1" ]; then
    sudo systemctl stop $1
    sudo rm /etc/systemd/system/$1
  fi
  
  sudo mv ./$1 /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl start $1
  sudo systemctl enable $1
}


setup_nginx() {
  if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
    sudo rm /etc/nginx/sites-enabled/$DOMAIN
    sudo rm /etc/nginx/sites-available/$DOMAIN
  fi
  sudo mv ./$DOMAIN /etc/nginx/sites-available/
  sudo chmod 644 /etc/nginx/sites-available/$DOMAIN 
  sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled
  sudo nginx -t
  if [ $? -eq 0 ]; then
    echo "successfully configured nginx"
  else
    echo "failed to configure nginx"
    sudo rm /etc/nginx/sites-enabled/$DOMAIN
    sudo rm /etc/nginx/sites-available/$DOMAIN
  fi
  sudo systemctl restart nginx
  echo "enabling firewall"
  sudo ufw allow 'Nginx Full'
}

start_depl () {
  cd $wd
  . conf.cfg
  if [ -d ./venv ]; then
    rm -rf ./venv
    if [ $? -ne 0 ]; then
      echo "failed to remove $wd/venv dir"
      exit 1
    fi
  fi
  "$PYTHON" -m venv ./venv
  source ./venv/bin/activate
  pip install -r requirements.txt
  chmod +x ./start.sh
  generate_service ps4.service
  setup_service ps4.service
  generate_nginx
  setup_nginx
}

main
