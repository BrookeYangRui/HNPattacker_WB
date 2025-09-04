// Go gRPC Interceptor HNP example
// SOURCE: metadata.FromIncomingContext(ctx), grpc metadata pollution
// ADDITION: gRPC interceptor, metadata pollution, service context pollution
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
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

// gRPC metadata store
type GrpcMetadataStore struct {
	metadata map[string]interface{}
	mutex    sync.RWMutex
}

func NewGrpcMetadataStore() *GrpcMetadataStore {
	return &GrpcMetadataStore{
		metadata: make(map[string]interface{}),
	}
}

func (gms *GrpcMetadataStore) SetMetadata(key string, value interface{}) {
	gms.mutex.Lock()
	defer gms.mutex.Unlock()
	gms.metadata[key] = value
}

func (gms *GrpcMetadataStore) GetMetadata(key string) interface{} {
	gms.mutex.RLock()
	defer gms.mutex.RUnlock()
	return gms.metadata[key]
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

// gRPC interceptor for metadata pollution
func grpcInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	// SOURCE: extract metadata from gRPC context
	md, ok := metadata.FromIncomingContext(ctx)
	if ok {
		// Extract polluted host from metadata
		if hosts := md.Get("x-polluted-host"); len(hosts) > 0 {
			host := hosts[0]
			
			// Store in global metadata store
			globalMetadataStore.SetMetadata("polluted_host", host)
			globalMetadataStore.SetMetadata("grpc_service", info.FullMethod)
			globalMetadataStore.SetMetadata("pollution_time", time.Now())
			
			// Create new context with polluted metadata
			newMD := metadata.New(map[string]string{
				"polluted_host": host,
				"grpc_interceptor": "true",
			})
			ctx = metadata.NewIncomingContext(ctx, newMD)
		}
	}
	
	return handler(ctx, req)
}

var globalMetadataStore = NewGrpcMetadataStore()

func main() {
	r := gin.Default()
	
	// gRPC interceptor middleware
	r.Use(func(c *gin.Context) {
		// SOURCE: extract host from request headers
		host := c.Request.Host
		if forwardedHost := c.Request.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
			host = forwardedHost
		}
		
		// Store polluted host in context
		c.Set("polluted_host", host)
		c.Set("grpc_interceptor", true)
		
		// Also store in global metadata store
		globalMetadataStore.SetMetadata("http_polluted_host", host)
		globalMetadataStore.SetMetadata("http_request_time", time.Now())
		
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
		
		token := "grpc-token-123"
		
		// Get polluted host from multiple sources
		pollutedHost, _ := c.Get("polluted_host")
		grpcHost := globalMetadataStore.GetMetadata("polluted_host")
		httpHost := globalMetadataStore.GetMetadata("http_polluted_host")
		
		// Use the most polluted host
		finalHost := pollutedHost
		if grpcHost != nil {
			finalHost = grpcHost
		} else if httpHost != nil {
			finalHost = httpHost
		}
		
		// ADDITION: build reset URL with gRPC interceptor context
		resetURL := fmt.Sprintf("http://%v/reset/%s", finalHost, token)
		resetURL += "?from=grpc_interceptor&t=" + token
		resetURL += "&framework=grpc&polluted_host=" + fmt.Sprintf("%v", finalHost)
		
		// Add gRPC metadata indicators
		if grpcService := globalMetadataStore.GetMetadata("grpc_service"); grpcService != nil {
			resetURL += "&grpc_service=" + fmt.Sprintf("%v", grpcService)
		}
		if pollutionTime := globalMetadataStore.GetMetadata("pollution_time"); pollutionTime != nil {
			resetURL += "&pollution_time=" + fmt.Sprintf("%v", pollutionTime)
		}
		
		html := fmt.Sprintf(RESET_TEMPLATE, resetURL, resetURL)
		
		if err := sendResetEmail(email, html); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		
		c.JSON(http.StatusOK, gin.H{
			"message": "Reset email sent via gRPC interceptor",
			"grpc_interceptor": true,
			"polluted_host": finalHost,
			"grpc_metadata": map[string]interface{}{
				"grpc_service": globalMetadataStore.GetMetadata("grpc_service"),
				"pollution_time": globalMetadataStore.GetMetadata("pollution_time"),
			},
		})
	})
	
	r.GET("/reset/:token", func(c *gin.Context) {
		token := c.Param("token")
		pollutedHost, _ := c.Get("polluted_host")
		
		c.JSON(http.StatusOK, gin.H{
			"ok": true, 
			"token": token, 
			"grpc_interceptor": true,
			"polluted_host": pollutedHost,
			"grpc_metadata": globalMetadataStore.metadata,
		})
	})
	
	// gRPC metadata endpoint
	r.GET("/grpc/metadata", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"grpc_metadata": globalMetadataStore.metadata,
			"metadata_exposed": true,
		})
	})
	
	r.Run(":8080")
}
