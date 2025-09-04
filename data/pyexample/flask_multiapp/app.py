# flask_multiapp_example.py
# Flask HNP example with multiple apps and blueprints
# SOURCE: url_for/_external, request.host_url, multiple app contexts
# ADDITION: blueprint registration, function chain, string mutation
# SINK: send email with reset link

from flask import Flask, Blueprint, request, url_for
import secrets, smtplib
from email.message import EmailMessage

RESET_TEMPLATE = "<p>Reset your password: <a href='{reset_url}'>{reset_url}</a></p>"

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

userbp = Blueprint('userbp', __name__, url_prefix='/user')

@userbp.route('/forgot', methods=['GET', 'POST'])
def forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = url_for('userbp.reset', token=token, _external=True)
        if '?' not in reset_url:
            reset_url += '?from=multiapp'
        reset_url += '&t=' + token
        html = RESET_TEMPLATE.format(reset_url=reset_url)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@userbp.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

adminbp = Blueprint('adminbp', __name__, url_prefix='/admin')

@adminbp.route('/forgot', methods=['GET', 'POST'])
def admin_forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'admin@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = url_for('adminbp.admin_reset', token=token, _external=True)
        if '?' not in reset_url:
            reset_url += '?from=admin'
        reset_url += '&t=' + token
        html = RESET_TEMPLATE.format(reset_url=reset_url)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@adminbp.route('/reset/<token>')
def admin_reset(token):
    return {"ok": True, "token": token}

app1 = Flask('userapp')
app1.register_blueprint(userbp)

app2 = Flask('adminapp')
app2.register_blueprint(adminbp)

if __name__ == "__main__":
    app1.run(port=5003)
    # app2.run(port=5004)  # Uncomment to run admin app separately
