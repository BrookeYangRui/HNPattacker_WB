# decorator_chain_example.py
# Flask HNP example with multiple decorators, function chain, and context mutation
# SOURCE: url_for/_external, request.host_url
# ADDITION: multiple decorators, function chain, context dict, string mutation
# SINK: send email with reset link

from flask import Flask, request, url_for
import secrets, smtplib
from email.message import EmailMessage
from functools import wraps

app = Flask(__name__)

RESET_TEMPLATE = "<p>Reset your password: <a href='{reset_url}'>{reset_url}</a></p>"

def log_call(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        print(f"[LOG] {f.__name__}")
        return f(*args, **kwargs)
    return wrapper

def require_post(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if request.method != 'POST':
            return "<form method='post'><input name='email'><button>Send</button></form>"
        return f(*args, **kwargs)
    return wrapper

@app.route('/forgot', methods=['GET', 'POST'])
@log_call
@require_post
def forgot():
    email = request.form.get('email', 'user@example.com')
    token = secrets.token_urlsafe(16)
    reset_url = url_for('reset', token=token, _external=True)
    context = {'reset_url': reset_url}
    if '?' not in context['reset_url']:
        context['reset_url'] += '?from=decorator_chain'
    context['reset_url'] += '&t=' + token
    html = RESET_TEMPLATE.format(**context)
    send_reset_email(email, html)
    return "OK"

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    app.run(port=5007)
