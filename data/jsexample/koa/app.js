// Koa.js HNP example
// SOURCE: ctx.request.host, ctx.request.headers['x-forwarded-host']
// ADDITION: string concatenation, query param addition
// SINK: send email with polluted reset link

const Koa = require('koa');
const Router = require('@koa/router');
const bodyParser = require('koa-bodyparser');
const nodemailer = require('nodemailer');

const app = new Koa();
const router = new Router();

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Middleware
app.use(bodyParser());

// Email configuration
const transporter = nodemailer.createTransporter({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: 'no-reply@example.com',
    pass: 'password'
  }
});

async function sendResetEmail(toAddr, htmlBody) {
  const mailOptions = {
    from: 'no-reply@example.com',
    to: toAddr,
    subject: 'Reset your password',
    html: htmlBody
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    throw error;
  }
}

// Routes
router.get('/forgot', async (ctx) => {
  ctx.type = 'text/html';
  ctx.body = `
    <form method="post">
      <input name="email" placeholder="Email">
      <button type="submit">Send Reset</button>
    </form>
  `;
});

router.post('/forgot', async (ctx) => {
  try {
    const email = ctx.request.body.email || 'user@example.com';
    const token = 'random-token-456';

    // SOURCE: get host from request headers
    let host = ctx.request.host;
    if (ctx.request.headers['x-forwarded-host']) {
      host = ctx.request.headers['x-forwarded-host'];
    }

    // ADDITION: build reset URL with query params
    let resetUrl = `http://${host}/reset/${token}`;
    resetUrl += `?from=forgot&t=${token}`;

    const html = RESET_TEMPLATE.replace(/%s/g, resetUrl);

    await sendResetEmail(email, html);
    ctx.body = 'Reset email sent';
  } catch (error) {
    ctx.status = 500;
    ctx.body = `Error: ${error.message}`;
  }
});

router.get('/reset/:token', async (ctx) => {
  const token = ctx.params.token;
  ctx.body = { ok: true, token: token };
});

// Use router
app.use(router.routes());
app.use(router.allowedMethods());

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
