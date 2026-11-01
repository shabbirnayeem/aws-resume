from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/healthz')
def healthz():
    return {'status': 'ok'}

if __name__ == '__main__':
    # Local development only; production runs under gunicorn (see Dockerfile).
    # Set FLASK_DEBUG=1 for auto-reload.
    app.run(host='127.0.0.1', port=9123)
