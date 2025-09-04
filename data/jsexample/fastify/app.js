// Node.js Fastify Framework HNP example
// SOURCE: request.hostname, request.headers['x-forwarded-host']
// ADDITION: Fastify framework, hooks, context pollution
// SINK: send email with polluted reset link

const fastify = require('fastify')({ logger: true });
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Global context store for HNP
const globalContext = {};

// Fastify hook for HNP
fastify.addHook('onRequest', async (request, reply) => {
    // SOURCE: extract host from request headers
    let host = request.hostname;
    if (request.headers['x-forwarded-host']) {
        host = request.headers['x-forwarded-host'];
    }
    
    // Store polluted host in Fastify context
    request.fastifyContext = {
        polluted_host: host,
        user_agent: request.headers['user-agent'],
        request_time: Date.now(),
        fastify_framework: true
    };
    
    // Also store in global context
    globalContext.polluted_host = host;
    globalContext.user_agent = request.headers['user-agent'];
    globalContext.request_time = Date.now();
    globalContext.fastify_framework = true;
});

// Forgot password form
fastify.get('/forgot', async (request, reply) => {
    reply.type('text/html');
    return `
        <form method="post">
            <input name="email" placeholder="Email">
            <button type="submit">Send Reset</button>
        </form>
    `;
});

// Forgot password submission
fastify.post('/forgot', async (request, reply) => {
    const email = request.body.email || 'user@example.com';
    const token = 'fastify-token-123';
    
    // Get polluted host from Fastify context
    const pollutedHost = request.fastifyContext.polluted_host;
    const userAgent = request.fastifyContext.user_agent;
    const requestTime = request.fastifyContext.request_time;
    
    // ADDITION: build reset URL with Fastify framework context
    let resetURL = `http://${pollutedHost}/reset/${token}`;
    resetURL += `?from=fastify_framework&t=${token}`;
    resetURL += `&framework=fastify&polluted_host=${pollutedHost}`;
    resetURL += `&user_agent=${userAgent}`;
    resetURL += `&request_time=${requestTime}`;
    
    const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
    
    try {
        await sendResetEmail(email, html);
        return {
            message: 'Reset email sent via Fastify framework',
            fastify_framework: true,
            polluted_host: pollutedHost,
            user_agent: userAgent,
            request_time: requestTime
        };
    } catch (error) {
        reply.code(500);
        return { error: error.message };
    }
});

// Password reset
fastify.get('/reset/:token', async (request, reply) => {
    const token = request.params.token;
    
    // Get polluted host from Fastify context
    const pollutedHost = request.fastifyContext.polluted_host;
    const userAgent = request.fastifyContext.user_agent;
    const requestTime = request.fastifyContext.request_time;
    
    return {
        ok: true,
        token: token,
        framework: 'fastify',
        polluted_host: pollutedHost,
        user_agent: userAgent,
        request_time: requestTime,
        fastify_framework: true
    };
});

// Context information
fastify.get('/context', async (request, reply) => {
    return {
        fastify_context: request.fastifyContext,
        fastify_framework: true,
        context_exposed: true
    };
});

// Global context information
fastify.get('/global-context', async (request, reply) => {
    return {
        global_context: globalContext,
        fastify_framework: true,
        global_exposed: true
    };
});

// Fastify app info
fastify.get('/fastify/info', async (request, reply) => {
    return {
        framework: 'fastify',
        version: '4.0.0',
        status: 'running',
        fastify_framework: true
    };
});

// Fastify app status
fastify.get('/fastify/status', async (request, reply) => {
    return {
        framework: 'fastify',
        routes_count: 6,
        fastify_framework: true
    };
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
        subject: 'Reset your password - Fastify Framework',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Start server
const start = async () => {
    try {
        await fastify.listen({ port: 3000 });
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};

start();
