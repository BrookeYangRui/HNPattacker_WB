# falcon_example.py
# SOURCE: req.url, req.host, req.scheme from Falcon request object.
# ADDITION: string formatting, list join, and function call chain.
# SINK: send email with reset link (using smtplib).

import falcon
import secrets, smtplib
from email.message import EmailMessage

class ForgotResource:
    def on_post(self, req, resp):
        email = req.get_param('email') or 'user@example.com'
        token = secrets.token_urlsafe(16)
        # SOURCE: scheme/host from request
        base = f"{req.scheme}://{req.host}"
        path = f"/reset/{token}"
        # ADDITION: list join, string formatting, function call chain
        params = [f"from=forgot", f"t={token}"]
        if token.endswith('A'):
            params.append("special=1")
        query = "&".join(params)
        reset_url = f"{base}{path}?{query}"
        html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
        send_reset_email(email, html)
        resp.status = falcon.HTTP_200
        resp.content_type = 'text/html'
        resp.text = "OK"

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

class ResetResource:
    def on_get(self, req, resp, token):
        resp.media = {"ok": True, "token": token}

app = falcon.App()
app.add_route('/forgot', ForgotResource())
app.add_route('/reset/{token}', ResetResource())
