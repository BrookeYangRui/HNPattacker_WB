# sanic_example.py
# SOURCE: request.url_for() and request.scheme/host from Sanic request object.
# ADDITION: multiple string operations, dict/kwargs, and function call chains.
# SINK: send email with reset link (using smtplib).

from sanic import Sanic, response
from sanic.request import Request
import secrets, smtplib
from email.message import EmailMessage

app = Sanic("hnp_sanic")

def build_reset_url(request: Request, token: str) -> str:
    # SOURCE: scheme/host from request
    base = f"{request.scheme}://{request.host}"
    path = app.url_for("reset", token=token)
    url = base + path
    # ADDITION: kwargs, dict, and chained mutation
    params = {"from": "forgot", "t": token}
    query = "&".join(f"{k}={v}" for k, v in params.items())
    url = f"{url}?{query}" if "?" not in url else f"{url}&{query}"
    # More mutation
    if token.startswith("A"):
        url += "&special=1"
    return url

def send_reset_email(to_addr: str, html_body: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = "Reset your password"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    with smtplib.SMTP("localhost", 25) as s:
        s.send_message(msg)

@app.route("/forgot", methods=["GET", "POST"])
async def forgot(request: Request):
    if request.method == "POST":
        email = request.form.get("email", "user@example.com")
        token = secrets.token_urlsafe(16)
        reset_url = build_reset_url(request, token)
        html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
        send_reset_email(email, html)
        return response.text("OK")
    return response.html('<form method="post"><input name="email"/><button>Send</button></form>')

@app.route("/reset/<token>")
async def reset(request: Request, token: str):
    return response.json({"ok": True, "token": token})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
