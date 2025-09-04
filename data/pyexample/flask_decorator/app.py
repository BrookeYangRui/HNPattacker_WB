# flask_decorator_example.py
# Flask HNP example with decorator wrapping, function chain, and context mutation
# SOURCE: url_for/_external, request.host_url
# ADDITION: decorator, function chain, context dict, string mutation
# SINK: send email with reset link

from flask import Flask, request, url_for
import secrets, smtplib
from email.message import EmailMessage
from functools import wraps

app = Flask(__name__)

RESET_TEMPLATE = "<p>Reset your password: <a href='{reset_url}'>{reset_url}</a></p>"

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

def log_and_call(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        print(f"[LOG] Calling {f.__name__}")
        return f(*args, **kwargs)
    return wrapper

@app.route('/forgot', methods=['GET', 'POST'])
@log_and_call
def forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = build_reset_url(token)
        context = {'reset_url': reset_url}
        if '?' not in context['reset_url']:
            context['reset_url'] += '?from=decorator'
        context['reset_url'] += '&t=' + token
        html = RESET_TEMPLATE.format(**context)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

def build_reset_url(token):
    # SOURCE: url_for/_external
    return url_for('reset', token=token, _external=True)

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    app.run(port=5002)
