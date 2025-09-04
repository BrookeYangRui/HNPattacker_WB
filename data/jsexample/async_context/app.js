// JavaScript Async Context HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: AsyncLocalStorage pollution, Promise context, event loop pollution
// SINK: send email with polluted reset link

const express = require('express');
const { AsyncLocalStorage } = require('async_hooks');
const nodemailer = require('nodemailer');
const app = express();

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// AsyncLocalStorage for context pollution
const asyncLocalStorage = new AsyncLocalStorage();
const globalContextStore = new Map();

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

// Async context pollution middleware
app.use((req, res, next) => {
  // SOURCE: extract host from request headers
  let host = req.headers.host;
  if (req.headers['x-forwarded-host']) {
    host = req.headers['x-forwarded-host'];
  }
  
  // ADDITION: pollute async context
  const pollutedContext = {
    polluted_host: host,
    polluted_time: Date.now(),
    user_agent: req.headers['user-agent'],
    request_id: Math.random().toString(36).substr(2, 9)
  };
  
  // Store in global context store
  globalContextStore.set(req, pollutedContext);
  
  // Run in AsyncLocalStorage context
  asyncLocalStorage.run(pollutedContext, () => {
    // Store in request object for later use
    req.pollutedContext = pollutedContext;
    req.extractedHost = host;
    
    next();
  });
});

async function sendResetEmail(toAddr, htmlBody) {
  const mailOptions = {
    from: 'no-reply@example.com',
    to: toAddr,
    subject: 'Reset your password - Async Context Pollution',
    html: htmlBody
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    throw error;
  }
}

// Background processing with polluted context
async function processPollutedContext() {
  const context = asyncLocalStorage.getStore();
  if (context) {
    console.log('[ASYNC_CONTEXT] Processing polluted context:');
    console.log('  Host:', context.polluted_host);
    console.log('  Time:', context.polluted_time);
    console.log('  User-Agent:', context.user_agent);
    
    // Simulate async processing
    await new Promise(resolve => setTimeout(resolve, 100));
    
    return context;
  }
  return null;
}

// Promise chain with context pollution
function createPollutedPromiseChain(host, token) {
  return new Promise((resolve) => {
    // First promise in chain
    Promise.resolve()
      .then(() => {
        const context = asyncLocalStorage.getStore();
        console.log('[PROMISE_CHAIN] Step 1 - Host:', context?.polluted_host);
        return context?.polluted_host || host;
      })
      .then((pollutedHost) => {
        // Second promise with polluted context
        return new Promise((resolveStep) => {
          setTimeout(() => {
            const context = asyncLocalStorage.getStore();
            console.log('[PROMISE_CHAIN] Step 2 - Host:', context?.polluted_host);
            resolveStep(pollutedHost);
          }, 50);
        });
      })
      .then((finalHost) => {
        resolve(finalHost);
      });
  });
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
    const token = 'async-token-123';

    // Get polluted host from various contexts
    let host = req.extractedHost || req.headers.host;
    if (req.headers['x-forwarded-host']) {
      host = req.headers['x-forwarded-host'];
    }

    // Get context from AsyncLocalStorage
    const asyncContext = asyncLocalStorage.getStore();
    const pollutedHost = asyncContext?.polluted_host || host;

    // ADDITION: build reset URL with async context pollution
    let resetUrl = `http://${pollutedHost}/reset/${token}`;
    resetUrl += `?from=async_context&t=${token}`;
    
    // Add context pollution indicators
    if (asyncContext) {
      resetUrl += `&polluted_host=${asyncContext.polluted_host}`;
      resetUrl += `&polluted_time=${asyncContext.polluted_time}`;
      resetUrl += `&request_id=${asyncContext.request_id}`;
    }

    const html = RESET_TEMPLATE.replace(/%s/g, resetUrl);

    // Launch background processing with polluted context
    const backgroundResult = await processPollutedContext();
    
    // Create promise chain with polluted context
    const chainResult = await createPollutedPromiseChain(pollutedHost, token);

    await sendResetEmail(email, html);
    
    res.send(`Reset email sent with async context pollution. Background: ${!!backgroundResult}, Chain: ${chainResult}`);
  } catch (error) {
    res.status(500).send(`Error: ${error.message}`);
  }
});

app.get('/reset/:token', (req, res) => {
  const token = req.params.token;
  
  // Get context from various sources
  const asyncContext = asyncLocalStorage.getStore();
  const pollutedContext = req.pollutedContext;
  
  res.json({ 
    ok: true, 
    token: token, 
    async_context: asyncContext,
    polluted_context: pollutedContext,
    async_context_pollution: true
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with async context pollution`);
});
