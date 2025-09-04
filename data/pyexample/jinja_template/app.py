# jinja_template_example.py
# Flask HNP example with Jinja2 template, url_for/_external, and template logic
# SOURCE: url_for/_external, request.host_url
# ADDITION: Jinja2 template, context mutation, string concat in template
# SINK: send email with reset link rendered by Jinja2

from flask import Flask, render_template_string, request, url_for
import secrets, smtplib
from email.message import EmailMessage

app = Flask(__name__)

RESET_TEMPLATE = """
<p>Reset your password: <a href='{{ reset_url }}'>{{ reset_url }}?from=jinja&t={{ token }}</a></p>
"""

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

@app.route('/forgot', methods=['GET', 'POST'])
def forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = url_for('reset', token=token, _external=True)
        html = render_template_string(RESET_TEMPLATE, reset_url=reset_url, token=token)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    app.run(port=5005)
