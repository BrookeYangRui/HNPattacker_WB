// Go Middleware Chain HNP example
// SOURCE: c.Request.Host, c.Request.Header.Get("X-Forwarded-Host")
// ADDITION: multiple middleware, function chain, context mutation
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/http"
	"net/smtp"
	"strings"

	"github.com/gin-gonic/gin"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Middleware functions
func logMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		fmt.Printf("[LOG] %s %s\n", c.Request.Method, c.Request.URL.Path)
		c.Next()
	}
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Simulate authentication check
		c.Set("authenticated", true)
		c.Next()
	}
}

func hostExtractionMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// SOURCE: extract host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		c.Set("extracted_host", host)
		c.Next()
	}
}

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

func main() {
	r := gin.Default()
	
	// Apply middleware chain
	r.Use(logMiddleware())
	r.Use(authMiddleware())
	r.Use(hostExtractionMiddleware())
	
	r.GET("/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	r.POST("/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "random-token-456"
		
		// Get host from middleware context
		host, exists := c.Get("extracted_host")
		if !exists {
			host = c.Request.Host
		}
		
		// ADDITION: build reset URL with query params
		resetURL := fmt.Sprintf("http://%s/reset/%s", host, token)
		resetURL += "?from=middleware_chain&t=" + token
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{"message": "Reset email sent"})
	})
	
	r.GET("/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		c.JSON(http.StatusOK, gin.H{"ok": true, "token": token})
	})
	
	r.Run(":8080")
}
