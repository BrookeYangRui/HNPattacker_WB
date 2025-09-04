// Go Fiber Framework HNP example
// SOURCE: c.Context().Host(), c.Get("X-Forwarded-Host")
// ADDITION: Fiber framework, middleware chain, context pollution
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/smtp"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
)

const resetTemplate = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Global context store for HNP
var globalContext = make(map[string]interface{})

// Fiber middleware for HNP
func hnpMiddleware(c *fiber.Ctx) error {
	// SOURCE: extract host from request headers
	host := c.Context().Host()
	if forwardedHost := c.Get("X-Forwarded-Host"); forwardedHost != "" {
		host = forwardedHost
	}

	// Store polluted host in Fiber context
	c.Locals("polluted_host", host)
	c.Locals("user_agent", c.Get("User-Agent"))
	c.Locals("request_time", c.Context().Time().Unix())
	c.Locals("fiber_framework", true)

	// Also store in global context
	globalContext["polluted_host"] = host
	globalContext["user_agent"] = c.Get("User-Agent")
	globalContext["request_time"] = c.Context().Time().Unix()
	globalContext["fiber_framework"] = true

	return c.Next()
}

// Email sending function
func sendResetEmail(to, htmlBody string) error {
	from := "no-reply@example.com"
	password := "password"

	msg := fmt.Sprintf("To: %s\r\nSubject: Reset your password - Fiber Framework\r\n\r\n%s", to, htmlBody)

	auth := smtp.PlainAuth("", from, password, "smtp.gmail.com", 587)
	return smtp.SendMail("smtp.gmail.com:587", auth, from, []string{to}, []byte(msg))
}

func main() {
	app := fiber.New(fiber.Config{
		AppName: "HNP Fiber App",
	})

	// Add logger middleware
	app.Use(logger.New())

	// Apply HNP middleware
	app.Use(hnpMiddleware)

	// Forgot password form
	app.Get("/forgot", func(c *fiber.Ctx) error {
		c.Set("Content-Type", "text/html")
		html := `
			<form method="post">
				<input name="email" placeholder="Email">
				<button type="submit">Send Reset</button>
			</form>
		`
		return c.SendString(html)
	})

	// Forgot password submission
	app.Post("/forgot", func(c *fiber.Ctx) error {
		email := c.FormValue("email")
		if email == "" {
			email = "user@example.com"
		}
		token := "fiber-token-123"

		// Get polluted host from Fiber context
		pollutedHost := c.Locals("polluted_host").(string)
		userAgent := c.Locals("user_agent").(string)
		requestTime := c.Locals("request_time").(int64)

		// ADDITION: build reset URL with Fiber framework context
		resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
		resetURL += fmt.Sprintf("?from=fiber_framework&t=%s", token)
		resetURL += fmt.Sprintf("&framework=fiber&polluted_host=%s", pollutedHost)
		resetURL += fmt.Sprintf("&user_agent=%s", userAgent)
		resetURL += fmt.Sprintf("&request_time=%d", requestTime)

		html := fmt.Sprintf(resetTemplate, resetURL, resetURL)

		if err := sendResetEmail(email, html); err != nil {
			return c.Status(500).JSON(fiber.Map{
				"error": err.Error(),
			})
		}

		return c.JSON(fiber.Map{
			"message":        "Reset email sent via Fiber framework",
			"fiber_framework": true,
			"polluted_host":  pollutedHost,
			"user_agent":     userAgent,
			"request_time":   requestTime,
		})
	})

	// Password reset
	app.Get("/reset/:token", func(c *fiber.Ctx) error {
		token := c.Params("token")

		// Get polluted host from Fiber context
		pollutedHost := c.Locals("polluted_host").(string)
		userAgent := c.Locals("user_agent").(string)
		requestTime := c.Locals("request_time").(int64)

		return c.JSON(fiber.Map{
			"ok":             true,
			"token":          token,
			"framework":      "fiber",
			"polluted_host":  pollutedHost,
			"user_agent":     userAgent,
			"request_time":   requestTime,
			"fiber_framework": true,
		})
	})

	// Context information
	app.Get("/context", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"fiber_context": fiber.Map{
				"polluted_host":  c.Locals("polluted_host"),
				"user_agent":     c.Locals("user_agent"),
				"request_time":   c.Locals("request_time"),
				"framework":      "fiber",
			},
			"fiber_framework": true,
			"context_exposed": true,
		})
	})

	// Global context information
	app.Get("/global-context", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"global_context": globalContext,
			"fiber_framework": true,
			"global_exposed": true,
		})
	})

	// Fiber app info
	app.Get("/fiber/info", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"framework":      "fiber",
			"version":        "2.0.0",
			"status":         "running",
			"fiber_framework": true,
		})
	})

	// Fiber app status
	app.Get("/fiber/status", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"framework":      "fiber",
			"middleware_count": len(app.GetRoutes()),
			"fiber_framework": true,
		})
	})

	// Start server
	app.Listen(":3000")
}
