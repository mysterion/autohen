wd=$(cd `dirname $0` && pwd)
cd $wd
source ./venv/bin/activate
gunicorn -w 1 wsgi:app
