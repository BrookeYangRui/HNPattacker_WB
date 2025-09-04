# flask_blueprint_example.py
# SOURCE: url_for/_external, request.host_url, Blueprint nesting.
# ADDITION: multiple function layers, attribute assignment, and template rendering.
# SINK: send email with reset link (using smtplib).

from flask import Flask, Blueprint, render_template_string, request, url_for
import secrets, smtplib
from email.message import EmailMessage

app = Flask(__name__)
userbp = Blueprint('userbp', __name__, url_prefix='/user')

RESET_TEMPLATE = """
<p>Reset your password: <a href='{{ reset_url }}'>{{ reset_url }}</a></p>
"""

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

def build_reset_url(token):
    # SOURCE: url_for/_external, host from request
    url = url_for('userbp.reset', token=token, _external=True)
    # ADDITION: attribute assignment, function call
    if "?" not in url:
        url += "?from=forgot"
    url += "&t=" + token
    return url

@userbp.route('/forgot', methods=['GET', 'POST'])
def forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = build_reset_url(token)
        html = render_template_string(RESET_TEMPLATE, reset_url=reset_url)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@userbp.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

app.register_blueprint(userbp)

if __name__ == "__main__":
    app.run(port=5001)
