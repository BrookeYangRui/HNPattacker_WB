// Go Multi-Application HNP example
// SOURCE: c.Request.Host, c.Request.Header.Get("X-Forwarded-Host")
// ADDITION: multiple apps, blueprint registration, function chain
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/http"
	"net/smtp"

	"github.com/gin-gonic/gin"
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

// User application
func createUserApp() *gin.Engine {
	app := gin.New()
	
	app.GET("/user/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	app.POST("/user/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "user-token-123"
		
		// SOURCE: get host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// ADDITION: build reset URL with query params
		resetURL := fmt.Sprintf("http://%s/user/reset/%s", host, token)
		resetURL += "?from=user&t=" + token
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{"message": "User reset email sent"})
	})
	
	app.GET("/user/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		c.JSON(http.StatusOK, gin.H{"ok": true, "token": token, "type": "user"})
	})
	
	return app
}

// Admin application
func createAdminApp() *gin.Engine {
	app := gin.New()
	
	app.GET("/admin/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "admin_forgot.html", nil)
	})
	
	app.POST("/admin/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "admin@example.com"
		}
		
		token := "admin-token-456"
		
		// SOURCE: get host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// ADDITION: build reset URL with query params
		resetURL := fmt.Sprintf("http://%s/admin/reset/%s", host, token)
		resetURL += "?from=admin&t=" + token
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{"message": "Admin reset email sent"})
	})
	
	app.GET("/admin/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		c.JSON(http.StatusOK, gin.H{"ok": true, "token": token, "type": "admin"})
	})
	
	return app
}

func main() {
	// Create separate applications
	userApp := createUserApp()
	adminApp := createAdminApp()
	
	// Run user app on port 8080
	go func() {
		userApp.Run(":8080")
	}()
	
	// Run admin app on port 8081
	adminApp.Run(":8081")
}
