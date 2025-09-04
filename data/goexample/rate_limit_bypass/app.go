// Go Rate Limit Bypass HNP example
// SOURCE: c.Request.Host, c.Request.Header.Get("X-Forwarded-Host")
// ADDITION: rate limiting bypass, IP spoofing, header manipulation
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/http"
	"net/smtp"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/ratelimit"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Rate limiter store
type RateLimiter struct {
	requests map[string][]time.Time
	mutex    sync.RWMutex
	limit    int
	window   time.Duration
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
}

func (rl *RateLimiter) IsAllowed(key string) bool {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	now := time.Now()
	windowStart := now.Add(-rl.window)

	// Clean old requests
	if times, exists := rl.requests[key]; exists {
		var validTimes []time.Time
		for _, t := range times {
			if t.After(windowStart) {
				validTimes = append(validTimes, t)
			}
		}
		rl.requests[key] = validTimes
	}

	// Check if limit exceeded
	if len(rl.requests[key]) >= rl.limit {
		return false
	}

	// Add current request
	rl.requests[key] = append(rl.requests[key], now)
	return true
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

// Rate limit bypass middleware
func rateLimitBypassMiddleware(limiter *RateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		// SOURCE: extract host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}

		// Get client IP (vulnerable to spoofing)
		clientIP := c.ClientIP()
		
		// Check X-Forwarded-For header (can be spoofed)
		if forwardedFor := c.Request.Header.Get("X-Forwarded-For"); forwardedFor != "" {
			clientIP = forwardedFor
		}
		
		// Check X-Real-IP header (can be spoofed)
		if realIP := c.Request.Header.Get("X-Real-IP"); realIP != "" {
			clientIP = realIP
		}

		// Store in context for later use
		c.Set("bypass_client_ip", clientIP)
		c.Set("bypass_host", host)
		c.Set("bypass_headers", c.Request.Header)

		// Check rate limit
		if !limiter.IsAllowed(clientIP) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "Rate limit exceeded",
				"ip":    clientIP,
				"host":  host,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

func main() {
	r := gin.Default()
	
	// Create rate limiter: 5 requests per minute per IP
	limiter := NewRateLimiter(5, time.Minute)
	
	// Apply rate limit bypass middleware
	r.Use(rateLimitBypassMiddleware(limiter))
	
	r.GET("/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	r.POST("/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "bypass-token-123"
		
		// Get bypass information from context
		clientIP, _ := c.Get("bypass_client_ip")
		bypassHost, _ := c.Get("bypass_host")
		bypassHeaders, _ := c.Get("bypass_headers")
		
		// ADDITION: build reset URL with bypass context
		resetURL := fmt.Sprintf("http://%v/reset/%s", bypassHost, token)
		resetURL += "?from=rate_limit_bypass&t=" + token
		resetURL += fmt.Sprintf("&bypass_ip=%v", clientIP)
		resetURL += fmt.Sprintf("&bypass_host=%v", bypassHost)
		
		// Add bypass indicators
		if headers, ok := bypassHeaders.(http.Header); ok {
			if forwardedFor := headers.Get("X-Forwarded-For"); forwardedFor != "" {
				resetURL += "&forwarded_for=" + forwardedFor
			}
			if realIP := headers.Get("X-Real-IP"); realIP != "" {
				resetURL += "&real_ip=" + realIP
			}
		}
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{
			"message": "Reset email sent with rate limit bypass",
			"client_ip": clientIP,
			"bypass_host": bypassHost,
		})
	})
	
	r.GET("/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		
		// Get bypass information
		clientIP, _ := c.Get("bypass_client_ip")
		bypassHost, _ := c.Get("bypass_host")
		
		c.JSON(http.StatusOK, gin.H{
			"ok": true, 
			"token": token, 
			"bypass_client_ip": clientIP,
			"bypass_host": bypassHost,
			"rate_limit_bypass": true,
		})
	})
	
	r.Run(":8080")
}
