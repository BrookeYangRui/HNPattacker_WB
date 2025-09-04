// Helmet Bypass HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: Helmet middleware bypass, CSP bypass, string concatenation
// SINK: send email with polluted reset link

const express = require('express');
const helmet = require('helmet');
const nodemailer = require('nodemailer');
const app = express();

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

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

// Helmet middleware with custom configuration
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Custom middleware to bypass Helmet protections
app.use((req, res, next) => {
  // SOURCE: extract host from request headers
  let host = req.headers.host;
  if (req.headers['x-forwarded-host']) {
    host = req.headers['x-forwarded-host'];
  }
  
  // Store host in request object for later use
  req.extractedHost = host;
  
  // Bypass some Helmet protections by modifying headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  
  next();
});

async function sendResetEmail(toAddr, htmlBody) {
  const mailOptions = {
    from: 'no-reply@example.com',
    to: toAddr,
    subject: 'Reset your password - Helmet Bypass',
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
app.get('/forgot', (req, res) => {
  res.send(`
    <form method="post">
      <input name="email" placeholder="Email">
      <button type="submit">Send Reset</button>
    </form>
  `);
});

app.post('/forgot', async (req, res) => {
  try {
    const email = req.body.email || 'user@example.com';
    const token = 'helmet-token-123';

    // Get host from middleware context
    let host = req.extractedHost || req.headers.host;
    if (req.headers['x-forwarded-host']) {
      host = req.headers['x-forwarded-host'];
    }

    // ADDITION: build reset URL with Helmet bypass context
    let resetUrl = `http://${host}/reset/${token}`;
    resetUrl += `?from=helmet_bypass&t=${token}`;
    
    // Add security bypass indicators
    resetUrl += `&bypass=true&csp=${encodeURIComponent(req.headers['content-security-policy'] || 'none')}`;

    const html = RESET_TEMPLATE.replace(/%s/g, resetUrl);

    await sendResetEmail(email, html);
    res.send('Reset email sent with Helmet bypass');
  } catch (error) {
    res.status(500).send(`Error: ${error.message}`);
  }
});

app.get('/reset/:token', (req, res) => {
  const token = req.params.token;
  const host = req.extractedHost || req.headers.host;
  
  res.json({ 
    ok: true, 
    token: token, 
    host: host, 
    helmet_bypass: true,
    headers: req.headers
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with Helmet bypass`);
});
