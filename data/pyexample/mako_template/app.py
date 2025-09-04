# mako_template_example.py
# Flask HNP example with Mako template engine
# SOURCE: url_for/_external, request.host_url
# ADDITION: Mako template, context mutation, string concat in template
# SINK: send email with reset link rendered by Mako

from flask import Flask, request, url_for
import secrets, smtplib
from email.message import EmailMessage
from mako.template import Template
import os

app = Flask(__name__)

TEMPLATE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'reset_email.mako')
if not os.path.exists(TEMPLATE_PATH):
    with open(TEMPLATE_PATH, 'w', encoding='utf-8') as f:
        f.write("""
<p>Reset your password: <a href='${reset_url}'>${reset_url}?from=mako&t=${token}</a></p>
""")

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
        template = Template(filename=TEMPLATE_PATH)
        html = template.render(reset_url=reset_url, token=token)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    app.run(port=5009)
