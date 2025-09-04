// Go Iris Framework HNP example
// SOURCE: ctx.Host(), ctx.GetHeader("X-Forwarded-Host")
// ADDITION: Iris framework, middleware chain, context pollution
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/smtp"

	"github.com/kataras/iris/v12"
	"github.com/kataras/iris/v12/middleware/logger"
)

const resetTemplate = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Global context store for HNP
var globalContext = make(map[string]interface{})

// Iris middleware for HNP
func hnpMiddleware(ctx iris.Context) {
	// SOURCE: extract host from request headers
	host := ctx.Host()
	if forwardedHost := ctx.GetHeader("X-Forwarded-Host"); forwardedHost != "" {
		host = forwardedHost
	}

	// Store polluted host in Iris context
	ctx.Values().Set("polluted_host", host)
	ctx.Values().Set("user_agent", ctx.GetHeader("User-Agent"))
	ctx.Values().Set("request_time", ctx.Time().Unix())
	ctx.Values().Set("iris_framework", true)

	// Also store in global context
	globalContext["polluted_host"] = host
	globalContext["user_agent"] = ctx.GetHeader("User-Agent")
	globalContext["request_time"] = ctx.Time().Unix()
	globalContext["iris_framework"] = true

	ctx.Next()
}

// Email sending function
func sendResetEmail(to, htmlBody string) error {
	from := "no-reply@example.com"
	password := "password"

	msg := fmt.Sprintf("To: %s\r\nSubject: Reset your password - Iris Framework\r\n\r\n%s", to, htmlBody)

	auth := smtp.PlainAuth("", from, password, "smtp.gmail.com", 587)
	return smtp.SendMail("smtp.gmail.com:587", auth, from, []string{to}, []byte(msg))
}

func main() {
	app := iris.New()

	// Add logger middleware
	app.Use(logger.New())

	// Apply HNP middleware
	app.Use(hnpMiddleware)

	// Forgot password form
	app.Get("/forgot", func(ctx iris.Context) {
		ctx.HTML(`
			<form method="post">
				<input name="email" placeholder="Email">
				<button type="submit">Send Reset</button>
			</form>
		`)
	})

	// Forgot password submission
	app.Post("/forgot", func(ctx iris.Context) {
		email := ctx.FormValue("email")
		if email == "" {
			email = "user@example.com"
		}
		token := "iris-token-123"

		// Get polluted host from Iris context
		pollutedHost := ctx.Values().GetString("polluted_host")
		userAgent := ctx.Values().GetString("user_agent")
		requestTime := ctx.Values().GetInt64("request_time")

		// ADDITION: build reset URL with Iris framework context
		resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
		resetURL += fmt.Sprintf("?from=iris_framework&t=%s", token)
		resetURL += fmt.Sprintf("&framework=iris&polluted_host=%s", pollutedHost)
		resetURL += fmt.Sprintf("&user_agent=%s", userAgent)
		resetURL += fmt.Sprintf("&request_time=%d", requestTime)

		html := fmt.Sprintf(resetTemplate, resetURL, resetURL)

		if err := sendResetEmail(email, html); err != nil {
			ctx.StatusCode(500)
			ctx.JSON(iris.Map{
				"error": err.Error(),
			})
			return
		}

		ctx.JSON(iris.Map{
			"message":        "Reset email sent via Iris framework",
			"iris_framework": true,
			"polluted_host":  pollutedHost,
			"user_agent":     userAgent,
			"request_time":   requestTime,
		})
	})

	// Password reset
	app.Get("/reset/{token:string}", func(ctx iris.Context) {
		token := ctx.Params().Get("token")

		// Get polluted host from Iris context
		pollutedHost := ctx.Values().GetString("polluted_host")
		userAgent := ctx.Values().GetString("user_agent")
		requestTime := ctx.Values().GetInt64("request_time")

		ctx.JSON(iris.Map{
			"ok":             true,
			"token":          token,
			"framework":      "iris",
			"polluted_host":  pollutedHost,
			"user_agent":     userAgent,
			"request_time":   requestTime,
			"iris_framework": true,
		})
	})

	// Context information
	app.Get("/context", func(ctx iris.Context) {
		ctx.JSON(iris.Map{
			"iris_context": iris.Map{
				"polluted_host":  ctx.Values().Get("polluted_host"),
				"user_agent":     ctx.Values().Get("user_agent"),
				"request_time":   ctx.Values().Get("request_time"),
				"framework":      "iris",
			},
			"iris_framework": true,
			"context_exposed": true,
		})
	})

	// Global context information
	app.Get("/global-context", func(ctx iris.Context) {
		ctx.JSON(iris.Map{
			"global_context": globalContext,
			"iris_framework": true,
			"global_exposed": true,
		})
	})

	// Iris app info
	app.Get("/iris/info", func(ctx iris.Context) {
		ctx.JSON(iris.Map{
			"framework":      "iris",
			"version":        "12.0.0",
			"status":         "running",
			"iris_framework": true,
		})
	})

	// Iris app status
	app.Get("/iris/status", func(ctx iris.Context) {
		ctx.JSON(iris.Map{
			"framework":      "iris",
			"routes_count":   len(app.GetRoutes()),
			"iris_framework": true,
		})
	})

	// Start server
	app.Listen(":3000")
}
