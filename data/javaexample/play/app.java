// Java Play Framework HNP example
// SOURCE: request.header("Host"), request.header("X-Forwarded-Host")
// ADDITION: Play Framework, action composition, context pollution
// SINK: send email with polluted reset link

package com.example.hnp.play;

import play.mvc.*;
import play.libs.Json;
import play.libs.mailer.Email;
import play.libs.mailer.MailerClient;
import play.mvc.Http.Request;
import play.mvc.Http.Response;
import play.mvc.Results;
import play.routing.Router;
import play.data.Form;
import play.data.FormFactory;
import play.i18n.MessagesApi;
import play.twirl.api.Html;

import javax.inject.Inject;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;

public class PlayFrameworkHnpApplication extends Controller {

    private final MailerClient mailerClient;
    private final FormFactory formFactory;
    private final MessagesApi messagesApi;

    @Inject
    public PlayFrameworkHnpApplication(MailerClient mailerClient, FormFactory formFactory, MessagesApi messagesApi) {
        this.mailerClient = mailerClient;
        this.formFactory = formFactory;
        this.messagesApi = messagesApi;
    }

    // Play Framework action composition for HNP
    public class HnpAction extends Action.Simple {
        @Override
        public CompletionStage<Result> call(Http.Context ctx) {
            Request request = ctx.request();
            
            // SOURCE: extract host from request headers
            String host = request.header("Host").orElse("localhost:9000");
            String forwardedHost = request.header("X-Forwarded-Host").orElse(null);
            
            if (forwardedHost != null && !forwardedHost.isEmpty()) {
                host = forwardedHost;
            }
            
            // Store polluted host in Play context
            ctx.args.put("polluted_host", host);
            ctx.args.put("play_framework", true);
            ctx.args.put("request_time", System.currentTimeMillis());
            
            return delegate.call(ctx);
        }
    }

    @With(HnpAction.class)
    public Result forgotForm() {
        return ok(views.html.forgot.render());
    }

    @With(HnpAction.class)
    public CompletionStage<Result> forgotSubmit() {
        Request request = request();
        Http.Context ctx = Http.Context.current();
        
        // Get form data
        Map<String, String[]> formData = request.body().asFormUrlEncoded();
        String email = formData.get("email") != null ? formData.get("email")[0] : "user@example.com";
        
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "play-token-123";

        // Get polluted host from Play context
        String pollutedHost = (String) ctx.args.get("polluted_host");
        Long requestTime = (Long) ctx.args.get("request_time");

        // ADDITION: build reset URL with Play Framework context
        String resetUrl = "http://" + pollutedHost + "/reset/" + token;
        resetUrl += "?from=play_framework&t=" + token;
        resetUrl += "&framework=play&polluted_host=" + pollutedHost;
        resetUrl += "&request_time=" + requestTime;

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        // Send email using Play Mailer
        Email emailObj = new Email();
        emailObj.setSubject("Reset your password - Play Framework");
        emailObj.setFrom("no-reply@example.com");
        emailObj.addTo(email);
        emailObj.setBodyHtml(html);

        return CompletableFuture.supplyAsync(() -> {
            try {
                mailerClient.send(emailObj);
                Map<String, Object> response = new HashMap<>();
                response.put("message", "Reset email sent via Play Framework");
                response.put("play_framework", true);
                response.put("polluted_host", pollutedHost);
                response.put("request_time", requestTime);
                return ok(Json.toJson(response));
            } catch (Exception e) {
                Map<String, String> error = new HashMap<>();
                error.put("error", e.getMessage());
                return internalServerError(Json.toJson(error));
            }
        });
    }

    @With(HnpAction.class)
    public Result reset(String token) {
        Http.Context ctx = Http.Context.current();
        String pollutedHost = (String) ctx.args.get("polluted_host");
        Long requestTime = (Long) ctx.args.get("request_time");

        Map<String, Object> response = new HashMap<>();
        response.put("ok", true);
        response.put("token", token);
        response.put("framework", "play");
        response.put("polluted_host", pollutedHost);
        response.put("request_time", requestTime);
        response.put("play_framework", true);

        return ok(Json.toJson(response));
    }

    // Play Framework context endpoint
    @With(HnpAction.class)
    public Result context() {
        Http.Context ctx = Http.Context.current();
        
        Map<String, Object> contextInfo = new HashMap<>();
        contextInfo.put("play_context", ctx.args);
        contextInfo.put("play_framework", true);
        contextInfo.put("context_exposed", true);

        return ok(Json.toJson(contextInfo));
    }
}
