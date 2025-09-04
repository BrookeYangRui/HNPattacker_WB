// Node.js Koa2 Framework HNP example
// SOURCE: ctx.request.host, ctx.request.headers['x-forwarded-host']
// ADDITION: Koa2 framework, middleware chain, context pollution
// SINK: send email with polluted reset link

const Koa = require('koa');
const Router = require('@koa/router');
const bodyParser = require('koa-bodyparser');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Koa2 application
const app = new Koa();
const router = new Router();

// Global context store for HNP
const globalContext = {};

// Koa2 middleware for HNP
const hnpMiddleware = async (ctx, next) => {
    // SOURCE: extract host from request headers
    let host = ctx.request.host;
    if (ctx.request.headers['x-forwarded-host']) {
        host = ctx.request.headers['x-forwarded-host'];
    }
    
    // Store polluted host in Koa2 context
    ctx.state.polluted_host = host;
    ctx.state.user_agent = ctx.request.headers['user-agent'];
    ctx.state.request_time = Date.now();
    ctx.state.koa2_framework = true;
    
    // Also store in global context
    globalContext.polluted_host = host;
    globalContext.user_agent = ctx.request.headers['user-agent'];
    globalContext.request_time = Date.now();
    globalContext.koa2_framework = true;
    
    await next();
};

// Apply middleware
app.use(bodyParser());
app.use(hnpMiddleware);

// Forgot password form
router.get('/forgot', async (ctx) => {
    ctx.type = 'text/html';
    ctx.body = `
        <form method="post">
            <input name="email" placeholder="Email">
            <button type="submit">Send Reset</button>
        </form>
    `;
});

// Forgot password submission
router.post('/forgot', async (ctx) => {
    const email = ctx.request.body.email || 'user@example.com';
    const token = 'koa2-token-123';
    
    // Get polluted host from Koa2 context
    const pollutedHost = ctx.state.polluted_host;
    const userAgent = ctx.state.user_agent;
    const requestTime = ctx.state.request_time;
    
    // ADDITION: build reset URL with Koa2 framework context
    let resetURL = `http://${pollutedHost}/reset/${token}`;
    resetURL += `?from=koa2_framework&t=${token}`;
    resetURL += `&framework=koa2&polluted_host=${pollutedHost}`;
    resetURL += `&user_agent=${userAgent}`;
    resetURL += `&request_time=${requestTime}`;
    
    const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
    
    try {
        await sendResetEmail(email, html);
        ctx.body = {
            message: 'Reset email sent via Koa2 framework',
            koa2_framework: true,
            polluted_host: pollutedHost,
            user_agent: userAgent,
            request_time: requestTime
        };
    } catch (error) {
        ctx.status = 500;
        ctx.body = { error: error.message };
    }
});

// Password reset
router.get('/reset/:token', async (ctx) => {
    const token = ctx.params.token;
    
    // Get polluted host from Koa2 context
    const pollutedHost = ctx.state.polluted_host;
    const userAgent = ctx.state.user_agent;
    const requestTime = ctx.state.request_time;
    
    ctx.body = {
        ok: true,
        token: token,
        framework: 'koa2',
        polluted_host: pollutedHost,
        user_agent: userAgent,
        request_time: requestTime,
        koa2_framework: true
    };
});

// Context information
router.get('/context', async (ctx) => {
    ctx.body = {
        koa2_context: {
            polluted_host: ctx.state.polluted_host,
            user_agent: ctx.state.user_agent,
            request_time: ctx.state.request_time,
            framework: 'koa2'
        },
        koa2_framework: true,
        context_exposed: true
    };
});

// Global context information
router.get('/global-context', async (ctx) => {
    ctx.body = {
        global_context: globalContext,
        koa2_framework: true,
        global_exposed: true
    };
});

// Koa2 app info
router.get('/koa2/info', async (ctx) => {
    ctx.body = {
        framework: 'koa2',
        version: '2.14.0',
        status: 'running',
        koa2_framework: true
    };
});

// Koa2 app status
router.get('/koa2/status', async (ctx) => {
    ctx.body = {
        framework: 'koa2',
        routes_count: 6,
        koa2_framework: true
    };
});

// Apply routes
app.use(router.routes());
app.use(router.allowedMethods());

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
        subject: 'Reset your password - Koa2 Framework',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Start server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Koa2 server running on port ${PORT}`);
});
