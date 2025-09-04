// Node.js NestJS Framework HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: NestJS framework, decorators, dependency injection pollution
// SINK: send email with polluted reset link

const express = require('express');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// NestJS-like application structure
class NestJSApp {
    constructor() {
        this.app = express();
        this.providers = new Map();
        this.controllers = new Map();
        this.middleware = [];
        this.globalContext = {};
        
        this.setupMiddleware();
        this.setupProviders();
        this.setupControllers();
        this.setupRoutes();
    }
    
    // NestJS-like middleware setup
    setupMiddleware() {
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));
        
        // NestJS-like global middleware for HNP
        this.app.use((req, res, next) => {
            // SOURCE: extract host from request headers
            let host = req.headers.host;
            if (req.headers['x-forwarded-host']) {
                host = req.headers['x-forwarded-host'];
            }
            
            // Store polluted host in NestJS global context
            this.globalContext.polluted_host = host;
            this.globalContext.user_agent = req.headers['user-agent'];
            this.globalContext.request_time = Date.now();
            this.globalContext.nestjs_framework = true;
            
            // Also store in request for controller access
            req.nestjsContext = { ...this.globalContext };
            
            next();
        });
    }
    
    // NestJS-like provider setup
    setupProviders() {
        // Email service provider
        this.providers.set('EmailService', {
            sendResetEmail: async (to, htmlBody) => {
                const transporter = nodemailer.createTransporter({
                    host: 'smtp.gmail.com',
                    port: 587,
                    secure: false,
                    auth: {
                        user: 'no-reply@example.com',
                        pass: 'password'
                    }
                });

                const mailOptions = {
                    from: 'no-reply@example.com',
                    to: to,
                    subject: 'Reset your password - NestJS Framework',
                    html: htmlBody
                };

                return transporter.sendMail(mailOptions);
            }
        });
        
        // Context service provider
        this.providers.set('ContextService', {
            getContext: () => this.globalContext,
            setContext: (key, value) => {
                this.globalContext[key] = value;
            }
        });
    }
    
    // NestJS-like controller setup
    setupControllers() {
        // Forgot password controller
        this.controllers.set('ForgotController', {
            forgotForm: (req, res) => {
                res.setHeader('Content-Type', 'text/html');
                res.send(`
                    <form method="post">
                        <input name="email" placeholder="Email">
                        <button type="submit">Send Reset</button>
                    </form>
                `);
            },
            
            forgotSubmit: async (req, res) => {
                const email = req.body.email || 'user@example.com';
                const token = 'nestjs-token-123';
                
                // Get polluted host from NestJS context
                const pollutedHost = req.nestjsContext.polluted_host;
                const userAgent = req.nestjsContext.user_agent;
                const requestTime = req.nestjsContext.request_time;
                
                // ADDITION: build reset URL with NestJS framework context
                let resetURL = `http://${pollutedHost}/reset/${token}`;
                resetURL += `?from=nestjs_framework&t=${token}`;
                resetURL += `&framework=nestjs&polluted_host=${pollutedHost}`;
                resetURL += `&user_agent=${userAgent}`;
                resetURL += `&request_time=${requestTime}`;
                
                const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
                
                try {
                    const emailService = this.providers.get('EmailService');
                    await emailService.sendResetEmail(email, html);
                    
                    res.json({
                        message: 'Reset email sent via NestJS framework',
                        nestjs_framework: true,
                        polluted_host: pollutedHost,
                        user_agent: userAgent,
                        request_time: requestTime
                    });
                } catch (error) {
                    res.status(500).json({ error: error.message });
                }
            }
        });
        
        // Reset password controller
        this.controllers.set('ResetController', {
            reset: (req, res) => {
                const token = req.params.token;
                
                // Get polluted host from NestJS context
                const pollutedHost = req.nestjsContext.polluted_host;
                const userAgent = req.nestjsContext.user_agent;
                const requestTime = req.nestjsContext.request_time;
                
                res.json({
                    ok: true,
                    token: token,
                    framework: 'nestjs',
                    polluted_host: pollutedHost,
                    user_agent: userAgent,
                    request_time: requestTime,
                    nestjs_framework: true
                });
            }
        });
        
        // Context controller
        this.controllers.set('ContextController', {
            getContext: (req, res) => {
                res.json({
                    nestjs_context: req.nestjsContext,
                    nestjs_framework: true,
                    context_exposed: true
                });
            },
            
            getProviders: (req, res) => {
                res.json({
                    providers: Array.from(this.providers.keys()),
                    nestjs_framework: true,
                    providers_exposed: true
                });
            },
            
            getControllers: (req, res) => {
                res.json({
                    controllers: Array.from(this.controllers.keys()),
                    nestjs_framework: true,
                    controllers_exposed: true
                });
            }
        });
    }
    
    // NestJS-like route setup
    setupRoutes() {
        const forgotController = this.controllers.get('ForgotController');
        const resetController = this.controllers.get('ResetController');
        const contextController = this.controllers.get('ContextController');
        
        // Forgot password routes
        this.app.get('/forgot', forgotController.forgotForm);
        this.app.post('/forgot', forgotController.forgotSubmit);
        
        // Reset password routes
        this.app.get('/reset/:token', resetController.reset);
        
        // Context routes
        this.app.get('/context', contextController.getContext);
        this.app.get('/providers', contextController.getProviders);
        this.app.get('/controllers', contextController.getControllers);
        
        // NestJS framework info routes
        this.app.get('/nestjs/info', (req, res) => {
            res.json({
                framework: 'nestjs',
                version: '1.0.0',
                status: 'running',
                nestjs_framework: true
            });
        });
        
        this.app.get('/nestjs/status', (req, res) => {
            res.json({
                framework: 'nestjs',
                providers_count: this.providers.size,
                controllers_count: this.controllers.size,
                middleware_count: this.middleware.length,
                nestjs_framework: true
            });
        });
    }
    
    // NestJS-like application methods
    use(middleware) {
        this.middleware.push(middleware);
        this.app.use(middleware);
    }
    
    listen(port) {
        this.app.listen(port, () => {
            console.log(`NestJS-like server running on port ${port}`);
        });
    }
}

// Create and start NestJS-like application
const app = new NestJSApp();
app.listen(3000);
