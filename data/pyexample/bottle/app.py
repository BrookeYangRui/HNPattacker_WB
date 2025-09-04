# bottle_example.py
# SOURCE: request.urlparts uses host/scheme from the request.
# ADDITION: string concatenation, query param addition.
# SINK: send email with reset link (using smtplib).

from bottle import Bottle, request, template, run
import secrets, smtplib
from email.message import EmailMessage

app = Bottle()

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

@app.route('/forgot', method=['GET', 'POST'])
def forgot():
    if request.method == 'POST':
        email = request.forms.get('email', 'user@example.com')
        token = secrets.token_urlsafe(16)
        # SOURCE: build base URL from request
        base = f"{request.urlparts.scheme}://{request.urlparts.netloc}"
        reset_url = base + f"/reset/{token}"
        # ADDITION: messy query param addition
        if "?" not in reset_url:
            reset_url += "?from=forgot"
        reset_url += "&t=" + token
        html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
        send_reset_email(email, html)
        return "OK"
    return '''<form method="post"><input name="email"/><button>Send</button></form>'''

@app.route('/reset/<token>')
def reset(token):
    return {"ok": True, "token": token}

if __name__ == "__main__":
    run(app, host='localhost', port=8080)
