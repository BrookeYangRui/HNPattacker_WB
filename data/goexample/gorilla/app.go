// Go Gorilla Mux Framework HNP example
// SOURCE: r.Header.Get("Host"), r.Header.Get("X-Forwarded-Host")
// ADDITION: Gorilla Mux, router middleware, context variables
// SINK: send email with polluted reset link

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/smtp"
	"time"

	"github.com/gorilla/mux"
	"github.com/gorilla/context"
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

// Gorilla Mux HNP middleware
func gorillaHnpMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// SOURCE: extract host from request headers
		host := r.Header.Get("Host")
		if forwardedHost := r.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// Store in Gorilla context
		context.Set(r, "polluted_host", host)
		context.Set(r, "request_time", time.Now())
		context.Set(r, "user_agent", r.Header.Get("User-Agent"))
		
		next.ServeHTTP(w, r)
	})
}

func main() {
	r := mux.NewRouter()
	
	// Apply Gorilla Mux middleware
	r.Use(gorillaHnpMiddleware)
	
	r.HandleFunc("/forgot", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprintf(w, `
			<form method="post">
				<input name="email" placeholder="Email">
				<button type="submit">Send Reset</button>
			</form>
		`)
	}).Methods("GET")
	
	r.HandleFunc("/forgot", func(w http.ResponseWriter, r *http.Request) {
		email := r.FormValue("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "gorilla-token-123"
		
		// Get polluted host from Gorilla context
		pollutedHost := context.Get(r, "polluted_host").(string)
		
		// ADDITION: build reset URL with Gorilla context
		resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
		resetURL += "?from=gorilla&t=" + token
		resetURL += "&framework=gorilla&polluted_host=" + pollutedHost
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		
		response := map[string]string{
			"message": "Reset email sent via Gorilla Mux framework",
			"framework": "gorilla",
			"polluted_host": pollutedHost,
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}).Methods("POST")
	
	r.HandleFunc("/reset/{token}", func(w http.ResponseWriter, r *http.Request) {
		vars := mux.Vars(r)
		token := vars["token"]
		pollutedHost := context.Get(r, "polluted_host").(string)
		
		response := map[string]interface{}{
			"ok": true, 
			"token": token, 
			"framework": "gorilla",
			"polluted_host": pollutedHost,
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}).Methods("GET")
	
	http.ListenAndServe(":8080", r)
}
