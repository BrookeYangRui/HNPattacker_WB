// Go Parameter Pollution HNP example
// SOURCE: c.Request.Host, c.Request.Header.Get("X-Forwarded-Host")
// ADDITION: parameter pollution, list join, string mutation
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
	
	r.GET("/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	r.POST("/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "random-token-123"
		
		// SOURCE: get host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// ADDITION: parameter pollution with multiple query params
		params := []string{"from=forgot", fmt.Sprintf("t=%s", token), "from=again"}
		query := strings.Join(params, "&")
		
		resetURL := fmt.Sprintf("http://%s/reset/%s", host, token)
		if !strings.Contains(resetURL, "?") {
			resetURL += "?" + query
		} else {
			resetURL += "&" + query
		}
		
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
