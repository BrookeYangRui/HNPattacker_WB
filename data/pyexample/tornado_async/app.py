# tornado_async_example.py
# Tornado async HNP reset-password example
# SOURCE: self.request.full_url(), reverse_url
# ADDITION: async email send, multiple awaits, string mutation
# SINK: async email send (simulated)

import asyncio, secrets
from email.message import EmailMessage
import tornado.ioloop
import tornado.web

async def async_send_reset_email(to_addr: str, html_body: str):
    # Simulate async email send
    await asyncio.sleep(0.1)
    msg = EmailMessage()
    msg["Subject"] = "Reset password async"
    msg["From"] = "no-reply@example.com"
    msg["To"] = to_addr
    msg.add_alternative(html_body, subtype="html")
    # Here you would use an async SMTP client, e.g. aiosmtplib (omitted for brevity)
    print(f"[ASYNC EMAIL] To: {to_addr}\n{html_body}")

class ForgotHandler(tornado.web.RequestHandler):
    async def get(self):
        self.write("""
          <form method='post'>
            <input name='email' />
            <button>Send</button>
          </form>
        """)

    async def post(self):
        email = self.get_body_argument("email", "user@example.com")
        token = secrets.token_urlsafe(16)
        base = self.request.full_url().split(self.request.uri)[0]
        path = self.reverse_url("reset_async", token)
        reset_url = base + path
        # ADDITION: async mutation
        if "?" not in reset_url:
            reset_url += "?from=forgot_async"
        await asyncio.sleep(0.05)
        reset_url += "&t=" + token
        html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
        await async_send_reset_email(email, html)
        self.write("OK")

class ResetHandler(tornado.web.RequestHandler):
    async def get(self, token):
        self.write({"ok": True, "token": token})

def make_app():
    return tornado.web.Application([
        tornado.web.URLSpec(r"/forgot", ForgotHandler, name="forgot_async"),
        tornado.web.URLSpec(r"/reset/(?P<token>[^/]+)", ResetHandler, name="reset_async"),
    ])

if __name__ == "__main__":
    app = make_app()
    app.listen(8889)
    asyncio.get_event_loop().run_forever()
