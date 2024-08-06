import os

from flask import Flask, render_template, request
from sender import send
import logging

app = Flask(__name__)

app.logger.setLevel(logging.INFO)

if __name__ != '__main__':
    # if we are not running directly, we set the loggers
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)

@app.route('/')
def index():
    return render_template("index.html")


@app.route("/log/<msg>")
def log(msg):
    app.logger.info(request.remote_addr)
    send(request.remote_addr, 9020, "payload/goldhen_2.3_900.bin")
    return "OK"


@app.after_request
def add_header(r):
    """
    Add headers to both force latest IE rendering engine or Chrome Frame,
    and also to cache the rendered page for 10 minutes.
    """
    r.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    r.headers["Pragma"] = "no-cache"
    r.headers["Expires"] = "0"
    r.headers['Cache-Control'] = 'public, max-age=0'
    return r


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=1337)
