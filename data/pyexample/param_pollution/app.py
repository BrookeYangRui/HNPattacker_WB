# param_pollution_example.py
# Flask HNP example with parameter pollution (multiple query params)
# SOURCE: url_for/_external, request.host_url
# ADDITION: param pollution, list join, string mutation
# SINK: send email with polluted reset link

from flask import Flask, request, url_for
import secrets, smtplib
from email.message import EmailMessage

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

@app.route('/forgot', methods=['GET', 'POST'])
def forgot():
    if request.method == 'POST':
        email = request.form.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        reset_url = url_for('reset', token=token, _external=True)
        # ADDITION: param pollution
        params = [f"from=forgot", f"t={token}", f"from=again"]
        query = "&".join(params)
        if '?' not in reset_url:
            reset_url += '?' + query
        else:
            reset_url += '&' + query
        html = RESET_TEMPLATE.format(reset_url=reset_url)
        send_reset_email(email, html)
        return "OK"
    return "<form method='post'><input name='email'><button>Send</button></form>"

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    app.run(port=5006)
