wd=$(cd `dirname $0` && pwd)
cd $wd
source ./venv/bin/activate
gunicorn -w 1 --bind unix:nginx.sock -m 007 wsgi:app --log-level debug
