# django_cbv_example.py
# Django class-based view (CBV) HNP reset-password example
# SOURCE: self.request.build_absolute_uri(), reverse_lazy
# ADDITION: multiple assignments, method override, context mutation
# SINK: send_mail with HTML message

from django.views import View
from django.http import HttpRequest, HttpResponse
from django.urls import reverse_lazy
from django.core.mail import send_mail
import secrets

class ForgotView(View):
    def post(self, request: HttpRequest):
        email = request.POST.get("email", "user@example.com")
        token = secrets.token_urlsafe(16)
        # SOURCE: reverse_lazy + build_absolute_uri
        reset_path = reverse_lazy("reset_cbv", kwargs={"token": token})
        reset_url = request.build_absolute_uri(reset_path)
        # ADDITION: context mutation, multiple assignments
        context = {"reset_url": reset_url}
        if "?" not in context["reset_url"]:
            context["reset_url"] += "?cbv=1"
        context["reset_url"] += f"&t={token}"
        html = f"<p>Reset link: <a href='{context['reset_url']}'>{context['reset_url']}</a></p>"
        send_mail(
            subject="Reset your password (CBV)",
            message="HTML only",
            from_email="no-reply@example.com",
            recipient_list=[email],
            html_message=html,
        )
        return HttpResponse("OK")

class ResetView(View):
    def get(self, request: HttpRequest, token: str):
        return HttpResponse(f"Token: {token}")
