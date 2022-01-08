wd=$(cd `dirname $0` && pwd)
cd $wd
source ./venv/bin/activate
gunicorn -w 2 app:app