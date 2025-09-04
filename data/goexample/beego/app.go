// Go Beego Framework HNP example
// SOURCE: ctx.Input.Host(), ctx.Input.Header("X-Forwarded-Host")
// ADDITION: Beego framework, controller structure, context pollution
// SINK: send email with polluted reset link

package main

import (
	"fmt"
	"net/smtp"
	"time"

	"github.com/astaxie/beego"
	"github.com/astaxie/beego/context"
)

const resetTemplate = "<p>Reset your password: <a href='%s'>%s</a></p>"

// Global context store for HNP
var globalContext = make(map[string]interface{})

// Beego middleware for HNP
func hnpMiddleware(ctx *context.Context) {
	// SOURCE: extract host from request headers
	host := ctx.Input.Host()
	if forwardedHost := ctx.Input.Header("X-Forwarded-Host"); forwardedHost != "" {
		host = forwardedHost
	}

	// Store polluted host in Beego context
	ctx.Input.SetData("polluted_host", host)
	ctx.Input.SetData("user_agent", ctx.Input.Header("User-Agent"))
	ctx.Input.SetData("request_time", time.Now().Unix())
	ctx.Input.SetData("beego_framework", true)

	// Also store in global context
	globalContext["polluted_host"] = host
	globalContext["user_agent"] = ctx.Input.Header("User-Agent")
	globalContext["request_time"] = time.Now().Unix()
	globalContext["beego_framework"] = true
}

// Main controller
type MainController struct {
	beego.Controller
}

// Forgot password form
func (c *MainController) Forgot() {
	c.Data["Title"] = "Forgot Password"
	c.TplName = "forgot.html"
}

// Forgot password submission
func (c *MainController) ForgotSubmit() {
	email := c.GetString("email")
	if email == "" {
		email = "user@example.com"
	}
	token := "beego-token-123"

	// Get polluted host from Beego context
	pollutedHost := c.Ctx.Input.GetData("polluted_host").(string)
	userAgent := c.Ctx.Input.GetData("user_agent").(string)
	requestTime := c.Ctx.Input.GetData("request_time").(int64)

	// ADDITION: build reset URL with Beego framework context
	resetURL := fmt.Sprintf("http://%s/reset/%s", pollutedHost, token)
	resetURL += fmt.Sprintf("?from=beego_framework&t=%s", token)
	resetURL += fmt.Sprintf("&framework=beego&polluted_host=%s", pollutedHost)
	resetURL += fmt.Sprintf("&user_agent=%s", userAgent)
	resetURL += fmt.Sprintf("&request_time=%d", requestTime)

	html := fmt.Sprintf(resetTemplate, resetURL, resetURL)

	if err := sendResetEmail(email, html); err != nil {
		c.Data["json"] = map[string]interface{}{
			"error": err.Error(),
		}
		c.ServeJSON()
		return
	}

	c.Data["json"] = map[string]interface{}{
		"message":        "Reset email sent via Beego framework",
		"beego_framework": true,
		"polluted_host":  pollutedHost,
		"user_agent":     userAgent,
		"request_time":   requestTime,
	}
	c.ServeJSON()
}

// Password reset
func (c *MainController) Reset() {
	token := c.Ctx.Input.Param(":token")

	// Get polluted host from Beego context
	pollutedHost := c.Ctx.Input.GetData("polluted_host").(string)
	userAgent := c.Ctx.Input.GetData("user_agent").(string)
	requestTime := c.Ctx.Input.GetData("request_time").(int64)

	c.Data["json"] = map[string]interface{}{
		"ok":             true,
		"token":          token,
		"framework":      "beego",
		"polluted_host":  pollutedHost,
		"user_agent":     userAgent,
		"request_time":   requestTime,
		"beego_framework": true,
	}
	c.ServeJSON()
}

// Context information
func (c *MainController) Context() {
	c.Data["json"] = map[string]interface{}{
		"beego_context": map[string]interface{}{
			"polluted_host":  c.Ctx.Input.GetData("polluted_host"),
			"user_agent":     c.Ctx.Input.GetData("user_agent"),
			"request_time":   c.Ctx.Input.GetData("request_time"),
			"framework":      "beego",
		},
		"beego_framework": true,
		"context_exposed": true,
	}
	c.ServeJSON()
}

// Global context information
func (c *MainController) GlobalContext() {
	c.Data["json"] = map[string]interface{}{
		"global_context": globalContext,
		"beego_framework": true,
		"global_exposed": true,
	}
	c.ServeJSON()
}

// Beego app info
func (c *MainController) Info() {
	c.Data["json"] = map[string]interface{}{
		"framework":      "beego",
		"version":        "1.12.0",
		"status":         "running",
		"beego_framework": true,
	}
	c.ServeJSON()
}

// Beego app status
func (c *MainController) Status() {
	c.Data["json"] = map[string]interface{}{
		"framework":      "beego",
		"routes_count":   len(beego.BeeApp.Handlers.Router),
		"beego_framework": true,
	}
	c.ServeJSON()
}

// Email sending function
func sendResetEmail(to, htmlBody string) error {
	from := "no-reply@example.com"
	password := "password"

	msg := fmt.Sprintf("To: %s\r\nSubject: Reset your password - Beego Framework\r\n\r\n%s", to, htmlBody)

	auth := smtp.PlainAuth("", from, password, "smtp.gmail.com", 587)
	return smtp.SendMail("smtp.gmail.com:587", auth, from, []string{to}, []byte(msg))
}

func main() {
	// Register middleware
	beego.InsertFilter("/*", beego.BeforeRouter, hnpMiddleware)

	// Register routes
	beego.Router("/forgot", &MainController{}, "get:Forgot")
	beego.Router("/forgot", &MainController{}, "post:ForgotSubmit")
	beego.Router("/reset/:token", &MainController{}, "get:Reset")
	beego.Router("/context", &MainController{}, "get:Context")
	beego.Router("/global-context", &MainController{}, "get:GlobalContext")
	beego.Router("/beego/info", &MainController{}, "get:Info")
	beego.Router("/beego/status", &MainController{}, "get:Status")

	// Start server
	beego.Run(":3000")
}
