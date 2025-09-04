// Go Chi Router Framework HNP example
// SOURCE: r.Header.Get("Host"), r.Header.Get("X-Forwarded-Host")
// ADDITION: Chi router, middleware chain, context pollution
// SINK: send email with polluted reset link

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/smtp"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

func sendResetEmail(toAddr, htmlBody string) error {
	from := "no-reply@example.com"
	password := "password"
	to := []string{toAddr}
	
	msg := fmt.Sprintf("To: %s\r\n"+
		"Subject: Reset your password\r\n"+
		"\r\n"+
		"%s\r\n", toAddr, htmlBody)
	
	auth := smtp.PlainAuth("", from, password, "smtp.gmail.com", "587")
	
	return smtp.SendMail("smtp.gmail.com:587", auth, from, to, []byte(msg))
}

// Chi HNP middleware
func chiHnpMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// SOURCE: extract host from request headers
		host := r.Header.Get("Host")
		if forwardedHost := r.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// Store in request context
		ctx := r.Context()
		ctx = context.WithValue(ctx, "polluted_host", host)
		ctx = context.WithValue(ctx, "request_time", time.Now())
		ctx = context.WithValue(ctx, "user_agent", r.Header.Get("User-Agent"))
		
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func main() {
	r := chi.NewRouter()
	
	// Apply Chi middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(chiHnpMiddleware)
	
	r.Get("/forgot", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprintf(w, `
			<form method="post">
				<input name="email" placeholder="Email">
				<button type="submit">Send Reset</button>
			</form>
		`)
	})
	
	r.Post("/forgot", func(w http.ResponseWriter, r *http.Request) {
		email := r.FormValue("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "chi-token-123"
		
		// Get polluted host from Chi context
		pollutedHost := r.Context().Value("polluted_host").(string)
		
		// ADDITION: build reset URL with Chi context
		resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
		resetURL += "?from=chi&t=" + token
		resetURL += "&framework=chi&polluted_host=" + pollutedHost
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		
		response := map[string]string{
			"message": "Reset email sent via Chi router framework",
			"framework": "chi",
			"polluted_host": pollutedHost,
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	})
	
	r.Get("/reset/{token}", func(w http.ResponseWriter, r *http.Request) {
		token := chi.URLParam(r, "token")
		pollutedHost := r.Context().Value("polluted_host").(string)
		
		response := map[string]interface{}{
			"ok": true, 
			"token": token, 
			"framework": "chi",
			"polluted_host": pollutedHost,
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	})
	
	http.ListenAndServe(":8080", r)
}
