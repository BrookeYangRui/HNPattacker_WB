# django_example.py
# SOURCE: request.build_absolute_uri() uses host/scheme from the request.
# ADDITION: string concatenation, query param addition.
# SINK: send_mail() includes the URL in the message body and sends it.

from django.core.mail import send_mail
from django.http import HttpRequest, HttpResponse
from django.urls import reverse
import secrets

def forgot(request: HttpRequest):
    email = request.POST.get("email", "user@example.com")
    token = secrets.token_urlsafe(16)

    # SOURCE: build absolute URL from request (host/scheme from Host header)
    reset_path = reverse("reset", args=[token])
    reset_url = request.build_absolute_uri(reset_path)

    # ADDITION: messy query param addition
    if "?" not in reset_url:
        reset_url += "?from=forgot"
    reset_url += "&t=" + token

    html = f"<p>Reset link: <a href='{reset_url}'>{reset_url}</a></p>"
    send_mail(
        subject="Reset your password",
        message="HTML only",  # for demo
        from_email="no-reply@example.com",
        recipient_list=[email],
        html_message=html,
    )
    return HttpResponse("OK")

def reset(request: HttpRequest, token: str):
    return HttpResponse(f"Token: {token}")
