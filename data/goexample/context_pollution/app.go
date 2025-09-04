// Go Context Pollution HNP example
// SOURCE: c.Request.Host, c.Request.Header.Get("X-Forwarded-Host")
// ADDITION: context pollution, goroutine context, channel communication
// SINK: send email with polluted reset link

package main

import (
	"context"
	"fmt"
	"net/http"
	"net/smtp"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Global context store for pollution
var (
	globalContext context.Context
	contextMutex  sync.RWMutex
	contextStore  = make(map[string]interface{})
)

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

// Context pollution middleware
func contextPollutionMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// SOURCE: extract host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// ADDITION: pollute global context
		contextMutex.Lock()
		contextStore["polluted_host"] = host
		contextStore["request_time"] = time.Now()
		contextStore["user_agent"] = c.Request.Header.Get("User-Agent")
		contextMutex.Unlock()
		
		// Create polluted context
		pollutedCtx := context.WithValue(context.Background(), "polluted_host", host)
		pollutedCtx = context.WithValue(pollutedCtx, "request_time", time.Now())
		
		// Store in gin context
		c.Set("polluted_context", pollutedCtx)
		c.Set("polluted_host", host)
		
		c.Next()
	}
}

// Goroutine that processes context pollution
func processContextPollution(ctx context.Context, host string) {
	// Simulate background processing with polluted context
	select {
	case <-ctx.Done():
		return
	case <-time.After(100 * time.Millisecond):
		// Process polluted host in background
		fmt.Printf("[GOROUTINE] Processing polluted host: %s\n", host)
	}
}

func main() {
	r := gin.Default()
	
	// Apply context pollution middleware
	r.Use(contextPollutionMiddleware())
	
	r.GET("/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	r.POST("/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "context-token-123"
		
		// Get polluted host from context
		pollutedHost, exists := c.Get("polluted_host")
		if !exists {
			pollutedHost = c.Request.Host
		}
		
		// Get polluted context
		pollutedCtx, _ := c.Get("polluted_context")
		if ctx, ok := pollutedCtx.(context.Context); ok {
			// Launch goroutine with polluted context
			go processContextPollution(ctx, fmt.Sprintf("%v", pollutedHost))
		}
		
		// ADDITION: build reset URL with polluted context
		resetURL := fmt.Sprintf("http://%v/reset/%s", pollutedHost, token)
		resetURL += "?from=context_pollution&t=" + token
		
		// Add context pollution indicators
		contextMutex.RLock()
		if pollutedTime, exists := contextStore["request_time"]; exists {
			resetURL += fmt.Sprintf("&polluted_time=%v", pollutedTime)
		}
		contextMutex.RUnlock()
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{"message": "Reset email sent with context pollution"})
	})
	
	r.GET("/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		
		// Get polluted host from context
		pollutedHost, _ := c.Get("polluted_host")
		
		c.JSON(http.StatusOK, gin.H{
			"ok": true, 
			"token": token, 
			"polluted_host": pollutedHost,
			"context_pollution": true,
		})
	})
	
	r.Run(":8080")
}
