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
  echo "WorkingDirectory=$wd" >> $file
  echo "ExecStart=/bin/bash -c '\"$wd/start.sh\"'" >> $file
  echo "[Install]" >> $file
  echo "WantedBy=multi-user.target" >> $file
}

start_depl () {
  cd $wd
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
  generate_service ps4-exploit.service
}

main
