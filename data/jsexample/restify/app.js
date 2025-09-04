// Node.js Restify Framework HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: Restify framework, middleware chain, context pollution
// SINK: send email with polluted reset link

const restify = require('restify');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Restify server configuration
const server = restify.createServer({
    name: 'hnp-restify',
    version: '1.0.0'
});

// Restify middleware for HNP
const hnpMiddleware = (req, res, next) => {
    // SOURCE: extract host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
        host = req.headers['x-forwarded-host'];
    }
    
    // Store polluted host in Restify context
    req.context = req.context || {};
    req.context.polluted_host = host;
    req.context.user_agent = req.headers['user-agent'];
    req.context.request_time = Date.now();
    req.context.restify_framework = true;
    
    next();
};

// Restify middleware for parsing
server.use(restify.plugins.bodyParser());
server.use(restify.plugins.queryParser());

// Apply HNP middleware
server.use(hnpMiddleware);

// Restify route for forgot password form
server.get('/forgot', (req, res, next) => {
    res.setHeader('Content-Type', 'text/html');
    res.send(200, `
        <form method="post">
            <input name="email" placeholder="Email">
            <button type="submit">Send Reset</button>
        </form>
    `);
    next();
});

// Restify route for forgot password submission
server.post('/forgot', async (req, res, next) => {
    const email = req.body.email || 'user@example.com';
    const token = 'restify-token-123';
    
    // Get polluted host from Restify context
    const pollutedHost = req.context.polluted_host;
    const userAgent = req.context.user_agent;
    const requestTime = req.context.request_time;
    
    // ADDITION: build reset URL with Restify framework context
    let resetURL = `http://${pollutedHost}/reset/${token}`;
    resetURL += `?from=restify_framework&t=${token}`;
    resetURL += `&framework=restify&polluted_host=${pollutedHost}`;
    resetURL += `&user_agent=${userAgent}`;
    resetURL += `&request_time=${requestTime}`;
    
    const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
    
    try {
        await sendResetEmail(email, html);
        res.json(200, {
            message: 'Reset email sent via Restify framework',
            restify_framework: true,
            polluted_host: pollutedHost,
            user_agent: userAgent,
            request_time: requestTime
        });
    } catch (error) {
        res.json(500, { error: error.message });
    }
    next();
});

// Restify route for password reset
server.get('/reset/:token', (req, res, next) => {
    const token = req.params.token;
    
    // Get polluted host from Restify context
    const pollutedHost = req.context.polluted_host;
    const userAgent = req.context.user_agent;
    const requestTime = req.context.request_time;
    
    res.json(200, {
        ok: true,
        token: token,
        framework: 'restify',
        polluted_host: pollutedHost,
        user_agent: userAgent,
        request_time: requestTime,
        restify_framework: true
    });
    next();
});

// Restify route for context information
server.get('/context', (req, res, next) => {
    res.json(200, {
        restify_context: {
            polluted_host: req.context.polluted_host,
            user_agent: req.context.user_agent,
            request_time: req.context.request_time,
            framework: 'restify'
        },
        restify_framework: true,
        context_exposed: true
    });
    next();
});

// Restify route for server info
server.get('/info', (req, res, next) => {
    res.json(200, {
        server_name: server.name,
        server_version: server.version,
        restify_framework: true,
        info_exposed: true
    });
    next();
});

// Restify route for middleware info
server.get('/middleware', (req, res, next) => {
    res.json(200, {
        middleware_count: server.middleware.length,
        restify_framework: true,
        middleware_exposed: true
    });
    next();
});

// Restify route for request headers
server.get('/headers', (req, res, next) => {
    res.json(200, {
        headers: req.headers,
        restify_framework: true,
        headers_exposed: true
    });
    next();
});

// Email sending function
async function sendResetEmail(to, htmlBody) {
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
        subject: 'Reset your password - Restify Framework',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Start Restify server
server.listen(3000, () => {
    console.log('Restify server running on port 3000');
});

// Error handling
server.on('error', (err) => {
    console.error('Restify server error:', err);
});

server.on('uncaughtException', (err) => {
    console.error('Uncaught exception:', err);
});
