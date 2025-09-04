// Node.js Hapi Framework HNP example
// SOURCE: request.info.host, request.headers['x-forwarded-host']
// ADDITION: Hapi framework, server methods, context pollution
// SINK: send email with polluted reset link

const Hapi = require('@hapi/hapi');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Hapi server configuration
const init = async () => {
    const server = Hapi.server({
        port: 3000,
        host: 'localhost'
    });

    // Hapi server method for HNP
    server.method('polluteHost', (request) => {
        // SOURCE: extract host from request headers
        let host = request.info.host;
        if (request.headers['x-forwarded-host']) {
            host = request.headers['x-forwarded-host'];
        }
        
        // Store polluted host in Hapi context
        request.app.polluted_host = host;
        request.app.user_agent = request.headers['user-agent'];
        request.app.request_time = Date.now();
        request.app.hapi_framework = true;
        
        return host;
    });

    // Hapi plugin for HNP middleware
    const hnpPlugin = {
        name: 'hnp-plugin',
        register: async (server, options) => {
            server.ext('onRequest', (request, h) => {
                // Call server method to pollute host
                server.methods.polluteHost(request);
                return h.continue;
            });
        }
    };

    // Register Hapi plugin
    await server.register(hnpPlugin);

    // Hapi route for forgot password form
    server.route({
        method: 'GET',
        path: '/forgot',
        handler: (request, h) => {
            return h.response(`
                <form method="post">
                    <input name="email" placeholder="Email">
                    <button type="submit">Send Reset</button>
                </form>
            `).type('text/html');
        }
    });

    // Hapi route for forgot password submission
    server.route({
        method: 'POST',
        path: '/forgot',
        handler: async (request, h) => {
            const email = request.payload.email || 'user@example.com';
            const token = 'hapi-token-123';
            
            // Get polluted host from Hapi context
            const pollutedHost = request.app.polluted_host;
            const userAgent = request.app.user_agent;
            const requestTime = request.app.request_time;
            
            // ADDITION: build reset URL with Hapi framework context
            let resetURL = `http://${pollutedHost}/reset/${token}`;
            resetURL += `?from=hapi_framework&t=${token}`;
            resetURL += `&framework=hapi&polluted_host=${pollutedHost}`;
            resetURL += `&user_agent=${userAgent}`;
            resetURL += `&request_time=${requestTime}`;
            
            const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
            
            try {
                await sendResetEmail(email, html);
                return {
                    message: 'Reset email sent via Hapi framework',
                    hapi_framework: true,
                    polluted_host: pollutedHost,
                    user_agent: userAgent,
                    request_time: requestTime
                };
            } catch (error) {
                return h.response({ error: error.message }).code(500);
            }
        }
    });

    // Hapi route for password reset
    server.route({
        method: 'GET',
        path: '/reset/{token}',
        handler: (request, h) => {
            const token = request.params.token;
            
            // Get polluted host from Hapi context
            const pollutedHost = request.app.polluted_host;
            const userAgent = request.app.user_agent;
            const requestTime = request.app.request_time;
            
            return {
                ok: true,
                token: token,
                framework: 'hapi',
                polluted_host: pollutedHost,
                user_agent: userAgent,
                request_time: requestTime,
                hapi_framework: true
            };
        }
    });

    // Hapi route for context information
    server.route({
        method: 'GET',
        path: '/context',
        handler: (request, h) => {
            return {
                hapi_context: {
                    polluted_host: request.app.polluted_host,
                    user_agent: request.app.user_agent,
                    request_time: request.app.request_time,
                    framework: 'hapi'
                },
                hapi_framework: true,
                context_exposed: true
            };
        }
    });

    // Hapi route for server methods
    server.route({
        method: 'GET',
        path: '/methods',
        handler: (request, h) => {
            return {
                server_methods: Object.keys(server.methods),
                hapi_framework: true,
                methods_exposed: true
            };
        }
    });

    // Hapi route for server info
    server.route({
        method: 'GET',
        path: '/info',
        handler: (request, h) => {
            return {
                server_info: server.info,
                hapi_framework: true,
                info_exposed: true
            };
        }
    });

    await server.start();
    console.log('Hapi server running on %s', server.info.uri);
};

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
        subject: 'Reset your password - Hapi Framework',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Error handling
process.on('unhandledRejection', (err) => {
    console.log(err);
    process.exit(1);
});

init();
