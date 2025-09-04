# starlette_async_example.py
# Starlette async HNP reset-password example with chain, mutation, and async email
# SOURCE: request.url_for(), request.url.hostname, request.url.scheme
# ADDITION: async/await, chain mutation, dict, function call, param pollution
# SINK: aiosmtplib.send

from starlette.applications import Starlette
from starlette.responses import HTMLResponse, JSONResponse
from starlette.routing import Route
from starlette.requests import Request
import secrets, aiosmtplib
from email.message import EmailMessage

async def send_reset_email_async(to_addr: str, html_body: str):
    msg = EmailMessage()
    msg["Subject"] = "Reset your password async"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    await aiosmtplib.send(msg, hostname="localhost", port=25)

async def forgot(request: Request):
    if request.method == "POST":
        form = await request.form()
        email = form.get("email", "user@example.com")
        token = secrets.token_urlsafe(16)
        # SOURCE: request.url_for (host/scheme from request)
        reset_url = request.url_for("reset", token=token)
        # ADDITION: chain mutation, param pollution
        params = ["from=starlette", f"t={token}", "from=again"]
        query = "&".join(params)
        if "?" not in reset_url:
            reset_url += "?" + query
        else:
            reset_url += "&" + query
        html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
        await send_reset_email_async(email, html)
        return JSONResponse({"status": "sent"})
    return HTMLResponse("""
    <form method='post'>
      <input name='email' type='email' />
      <button>Send</button>
    </form>""")

async def reset(request: Request):
    token = request.path_params["token"]
    return JSONResponse({"ok": True, "token": token})

routes = [
    Route("/forgot", forgot, methods=["GET", "POST"]),
    Route("/reset/{token}", reset, methods=["GET"]),
]

app = Starlette(debug=True, routes=routes)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
