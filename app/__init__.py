import os
from flask import Flask
from app.config import Config
from app.routes_scan import scan_bp
from app.routes_admin import admin_bp

def create_app():
    app = Flask(__name__, template_folder="../templates", static_folder="../static")
    app.config.from_object(Config)
    secret_key = os.environ.get("SECRET_KEY")
    if not secret_key:
        raise RuntimeError("SECRET_KEY environment variable is not set")
    app.secret_key = secret_key

    app.register_blueprint(scan_bp)
    app.register_blueprint(admin_bp)

    return app
