// Express.js HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: string concatenation, query param addition
// SINK: send email with polluted reset link

const express = require('express');
const nodemailer = require('nodemailer');
const app = express();

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// Middleware
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

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
    const token = 'random-token-123';

    // SOURCE: get host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
      host = req.headers['x-forwarded-host'];
    }

    // ADDITION: build reset URL with query params
    let resetUrl = `http://${host}/reset/${token}`;
    resetUrl += `?from=forgot&t=${token}`;

    const html = RESET_TEMPLATE.replace(/%s/g, resetUrl);

    await sendResetEmail(email, html);
    res.send('Reset email sent');
  } catch (error) {
    res.status(500).send(`Error: ${error.message}`);
  }
});

app.get('/reset/:token', (req, res) => {
  const token = req.params.token;
  res.json({ ok: true, token: token });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
