// Go WebSocket Hijacking HNP example
// SOURCE: r.Header.Get("Host"), r.Header.Get("X-Forwarded-Host")
// ADDITION: WebSocket hijacking, connection pollution, real-time data leakage
// SINK: send email with polluted reset link

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/smtp"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

// WebSocket connection store
type WebSocketStore struct {
	connections map[string]*websocket.Conn
	mutex       sync.RWMutex
}

func NewWebSocketStore() *WebSocketStore {
	return &WebSocketStore{
		connections: make(map[string]*websocket.Conn),
	}
}

func (ws *WebSocketStore) AddConnection(id string, conn *websocket.Conn) {
	ws.mutex.Lock()
	defer ws.mutex.Unlock()
	ws.connections[id] = conn
}

func (ws *WebSocketStore) RemoveConnection(id string) {
	ws.mutex.Lock()
	defer ws.mutex.Unlock()
	delete(ws.connections, id)
}

func (ws *WebSocketStore) BroadcastMessage(message interface{}) {
	ws.mutex.RLock()
	defer ws.mutex.RUnlock()
	
	data, _ := json.Marshal(message)
	for _, conn := range ws.connections {
		conn.WriteMessage(websocket.TextMessage, data)
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

// WebSocket upgrader
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Vulnerable: accept any origin
		return true
	},
}

func main() {
	r := gin.Default()
	wsStore := NewWebSocketStore()
	
	// WebSocket hijacking middleware
	r.Use(func(c *gin.Context) {
		// SOURCE: extract host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// Store polluted host in context
		c.Set("polluted_host", host)
		c.Set("websocket_hijacking", true)
		
		c.Next()
	})
	
	r.GET("/forgot", func(c *gin.Context) {
		c.HTML(http.StatusOK, "forgot.html", nil)
	})
	
	r.POST("/forgot", func(c *gin.Context) {
		email := c.PostForm("email")
		if email == "" {
			email = "user@example.com"
		}
		
		token := "websocket-token-123"
		
		// Get polluted host from context
		pollutedHost, _ := c.Get("polluted_host")
		
		// ADDITION: build reset URL with WebSocket context
		resetURL := fmt.Sprintf("http://%v/reset/%s", pollutedHost, token)
		resetURL += "?from=websocket_hijacking&t=" + token
		resetURL += "&framework=websocket&polluted_host=" + fmt.Sprintf("%v", pollutedHost)
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		// Broadcast to WebSocket connections
		wsStore.BroadcastMessage(map[string]interface{}{
			"type": "reset_email_sent",
			"email": email,
			"polluted_host": pollutedHost,
			"timestamp": time.Now().Unix(),
		})
		
		c.JSON(http.StatusOK, gin.H{
			"message": "Reset email sent via WebSocket hijacking",
			"websocket_hijacking": true,
			"polluted_host": pollutedHost,
		})
	})
	
	r.GET("/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		pollutedHost, _ := c.Get("polluted_host")
		
		c.JSON(http.StatusOK, gin.H{
			"ok": true, 
			"token": token, 
			"websocket_hijacking": true,
			"polluted_host": pollutedHost,
		})
	})
	
	// WebSocket endpoint
	r.GET("/ws", func(c *gin.Context) {
		// Upgrade HTTP connection to WebSocket
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		defer conn.Close()
		
		// Get polluted host from context
		pollutedHost, _ := c.Get("polluted_host")
		
		// Generate connection ID
		connID := fmt.Sprintf("conn_%d", time.Now().UnixNano())
		wsStore.AddConnection(connID, conn)
		defer wsStore.RemoveConnection(connID)
		
		// Send initial message with polluted host
		conn.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf(`{
			"type": "connected",
			"connection_id": "%s",
			"polluted_host": "%v",
			"websocket_hijacking": true
		}`, connID, pollutedHost)))
		
		// Handle WebSocket messages
		for {
			messageType, message, err := conn.ReadMessage()
			if err != nil {
				break
			}
			
			// Echo message back with polluted context
			response := map[string]interface{}{
				"type": "echo",
				"message": string(message),
				"polluted_host": pollutedHost,
				"connection_id": connID,
				"timestamp": time.Now().Unix(),
			}
			
			responseData, _ := json.Marshal(response)
			conn.WriteMessage(messageType, responseData)
		}
	})
	
	r.Run(":8080")
}
