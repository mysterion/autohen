import os

from flask import Flask, render_template, request
from sender import send
app = Flask(__name__)


@app.route('/')
def index():
    return render_template("index.html")


@app.route("/log/<msg>")
def log(msg):
    send(request.remote_addr, 9020, "payload/goldhen_2.0b2_900.bin")
    print(msg)
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
