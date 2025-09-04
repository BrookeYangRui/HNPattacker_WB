// Go Echo Framework HNP example
// SOURCE: c.Request().Host, c.Request().Header.Get("X-Forwarded-Host")
// ADDITION: Echo framework, middleware chain, context pollution
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/http"
	"net/smtp"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
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

// Echo HNP middleware
func echoHnpMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// SOURCE: extract host from request headers
			host := c.Request().Host
			if forwardedHost := c.Request().Header.Get("X-Forwarded-Host"); forwardedHost != "" {
				host = forwardedHost
			}
			
			// Store in Echo context
			c.Set("polluted_host", host)
			c.Set("request_time", time.Now())
			c.Set("user_agent", c.Request().Header.Get("User-Agent"))
			
			return next(c)
		}
	}
}

func main() {
	e := echo.New()
	
	// Apply Echo middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(echoHnpMiddleware())
	
	e.GET("/forgot", func(c echo.Context) error {
		return c.HTML(http.StatusOK, `
			<form method="post">
				<input name="email" placeholder="Email">
				<button type="submit">Send Reset</button>
			</form>
		`)
	})
	
	e.POST("/forgot", func(c echo.Context) error {
		email := c.FormValue("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "echo-token-123"
		
		// Get polluted host from Echo context
		pollutedHost := c.Get("polluted_host").(string)
		
		// ADDITION: build reset URL with Echo context
		resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
		resetURL += "?from=echo&t=" + token
		resetURL += "&framework=echo&polluted_host=" + pollutedHost
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		
		return c.JSON(http.StatusOK, map[string]string{
			"message": "Reset email sent via Echo framework",
			"framework": "echo",
			"polluted_host": pollutedHost,
		})
	})
	
	e.GET("/reset/:token", func(c echo.Context) error {
		token := c.Param("token")
		pollutedHost := c.Get("polluted_host").(string)
		
		return c.JSON(http.StatusOK, map[string]interface{}{
			"ok": true, 
			"token": token, 
			"framework": "echo",
			"polluted_host": pollutedHost,
		})
	})
	
	e.Start(":8080")
}
