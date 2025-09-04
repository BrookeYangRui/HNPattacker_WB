# aiosmtplib_async_example.py
# Async HNP reset-password example using aiosmtplib for async email
# SOURCE: request.url_for(), request.host, request.scheme
# ADDITION: async/await, string mutation, dict, function chain
# SINK: aiosmtplib.send

import aiosmtplib
import secrets
from email.message import EmailMessage
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse

app = FastAPI()

async def send_reset_email_async(to_addr: str, html_body: str):
    msg = EmailMessage()
    msg["Subject"] = "Reset your password async"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    await aiosmtplib.send(msg, hostname="localhost", port=25)

@app.get("/forgot", response_class=HTMLResponse)
async def forgot_form():
    return """
    <form method='post'>
      <input name='email' type='email' />
      <button>Send</button>
    </form>"""

@app.post("/forgot")
async def forgot(request: Request, email: str = Form(...)):
    token = secrets.token_urlsafe(16)
    reset_url = str(request.url_for("reset_password", token=token))
    # ADDITION: async mutation, dict, function chain
    context = {"reset_url": reset_url}
    if "?" not in context["reset_url"]:
        context["reset_url"] += "?from=aiosmtplib"
    context["reset_url"] += "&t=" + token
    html = f"<p>Reset link: <a href='{context['reset_url']}'>{context['reset_url']}</a></p>"
    await send_reset_email_async(email, html)
    return {"status": "sent"}

@app.get("/reset/{token}", name="reset_password")
async def reset_password(token: str):
    return {"ok": True, "token": token}
