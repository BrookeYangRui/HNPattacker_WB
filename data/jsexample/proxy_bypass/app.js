// JavaScript Proxy Bypass HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: proxy bypass, load balancer bypass, CDN bypass
// SINK: send email with polluted reset link

const express = require('express');
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

// Proxy bypass middleware
app.use((req, res, next) => {
  // SOURCE: extract host from request headers
  let host = req.headers.host;
  let realIP = req.connection.remoteAddress;
  let forwardedFor = req.headers['x-forwarded-for'];
  let realIPHeader = req.headers['x-real-ip'];
  let forwardedHost = req.headers['x-forwarded-host'];
  let forwardedProto = req.headers['x-forwarded-proto'];
  let cfConnectingIP = req.headers['cf-connecting-ip']; // Cloudflare
  let cfRay = req.headers['cf-ray']; // Cloudflare
  let cfIPCountry = req.headers['cf-ipcountry']; // Cloudflare
  
  // ADDITION: proxy bypass logic
  if (forwardedHost) {
    host = forwardedHost;
  }
  
  if (forwardedFor) {
    realIP = forwardedFor.split(',')[0].trim();
  }
  
  if (realIPHeader) {
    realIP = realIPHeader;
  }
  
  if (cfConnectingIP) {
    realIP = cfConnectingIP;
  }
  
  // Store proxy bypass information
  req.proxyBypass = {
    originalHost: req.headers.host,
    pollutedHost: host,
    realIP: realIP,
    forwardedFor: forwardedFor,
    realIPHeader: realIPHeader,
    cfConnectingIP: cfConnectingIP,
    cfRay: cfRay,
    cfIPCountry: cfIPCountry,
    forwardedProto: forwardedProto,
    userAgent: req.headers['user-agent'],
    requestTime: Date.now()
  };
  
  // Set custom headers for bypass
  res.setHeader('X-Proxy-Bypass', 'true');
  res.setHeader('X-Original-Host', req.headers.host);
  res.setHeader('X-Polluted-Host', host);
  res.setHeader('X-Real-IP', realIP);
  
  next();
});

async function sendResetEmail(toAddr, htmlBody) {
  const mailOptions = {
    from: 'no-reply@example.com',
    to: toAddr,
    subject: 'Reset your password - Proxy Bypass',
    html: htmlBody
  };

  try {
    await transporter.sendMail(mailOptions);
    return true;
  } catch (error) {
    throw error;
  }
}

// Proxy bypass helper functions
function detectProxyType(headers) {
  const proxyIndicators = [];
  
  if (headers['x-forwarded-for']) proxyIndicators.push('X-Forwarded-For');
  if (headers['x-real-ip']) proxyIndicators.push('X-Real-IP');
  if (headers['cf-connecting-ip']) proxyIndicators.push('Cloudflare');
  if (headers['x-forwarded-host']) proxyIndicators.push('X-Forwarded-Host');
  if (headers['x-forwarded-proto']) proxyIndicators.push('X-Forwarded-Proto');
  if (headers['via']) proxyIndicators.push('Via');
  if (headers['x-proxy-id']) proxyIndicators.push('Custom Proxy');
  
  return proxyIndicators;
}

function generateBypassUrl(host, token, proxyInfo) {
  let bypassUrl = `http://${host}/reset/${token}`;
  bypassUrl += `?from=proxy_bypass&t=${token}`;
  
  // Add proxy bypass indicators
  if (proxyInfo.forwardedFor) {
    bypassUrl += `&forwarded_for=${encodeURIComponent(proxyInfo.forwardedFor)}`;
  }
  if (proxyInfo.realIPHeader) {
    bypassUrl += `&real_ip=${encodeURIComponent(proxyInfo.realIPHeader)}`;
  }
  if (proxyInfo.cfConnectingIP) {
    bypassUrl += `&cf_ip=${encodeURIComponent(proxyInfo.cfConnectingIP)}`;
  }
  if (proxyInfo.cfRay) {
    bypassUrl += `&cf_ray=${encodeURIComponent(proxyInfo.cfRay)}`;
  }
  if (proxyInfo.cfIPCountry) {
    bypassUrl += `&cf_country=${encodeURIComponent(proxyInfo.cfIPCountry)}`;
  }
  
  return bypassUrl;
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
    const token = 'proxy-token-123';

    // Get proxy bypass information
    const proxyInfo = req.proxyBypass;
    const pollutedHost = proxyInfo.pollutedHost;

    // Detect proxy type
    const proxyTypes = detectProxyType(req.headers);

    // ADDITION: build reset URL with proxy bypass context
    const resetUrl = generateBypassUrl(pollutedHost, token, proxyInfo);

    const html = RESET_TEMPLATE.replace(/%s/g, resetUrl);

    await sendResetEmail(email, html);
    
    res.send(`Reset email sent with proxy bypass. Proxy types: ${proxyTypes.join(', ')}`);
  } catch (error) {
    res.status(500).send(`Error: ${error.message}`);
  }
});

app.get('/reset/:token', (req, res) => {
  const token = req.params.token;
  const proxyInfo = req.proxyBypass;
  
  res.json({ 
    ok: true, 
    token: token, 
    proxy_bypass: proxyInfo,
    proxy_types: detectProxyType(req.headers),
    proxy_bypass_vulnerability: true
  });
});

// Proxy information endpoint
app.get('/proxy/info', (req, res) => {
  const proxyInfo = req.proxyBypass;
  const proxyTypes = detectProxyType(req.headers);
  
  res.json({
    proxy_info: proxyInfo,
    proxy_types: proxyTypes,
    headers: req.headers,
    proxy_info_exposed: true
  });
});

// Proxy bypass test endpoint
app.get('/proxy/test', (req, res) => {
  const proxyInfo = req.proxyBypass;
  
  // Test different bypass scenarios
  const bypassTests = {
    host_bypass: proxyInfo.pollutedHost !== proxyInfo.originalHost,
    ip_bypass: proxyInfo.realIP !== req.connection.remoteAddress,
    cloudflare_bypass: !!proxyInfo.cfConnectingIP,
    forwarded_bypass: !!proxyInfo.forwardedFor,
    real_ip_bypass: !!proxyInfo.realIPHeader
  };
  
  res.json({
    bypass_tests: bypassTests,
    proxy_info: proxyInfo,
    bypass_test_results: true
  });
});

// Manual proxy bypass endpoint
app.post('/proxy/bypass', (req, res) => {
  const { path, host, ip } = req.body;
  
  // SOURCE: get host from request headers
  let targetHost = host || req.headers.host;
  if (req.headers['x-forwarded-host']) {
    targetHost = req.headers['x-forwarded-host'];
  }
  
  // ADDITION: manual proxy bypass
  const manualBypass = {
    path: path || '/',
    target_host: targetHost,
    bypass_ip: ip || req.connection.remoteAddress,
    bypass_time: Date.now(),
    bypass_type: 'manual'
  };
  
  res.json({
    success: true,
    manual_bypass: manualBypass,
    proxy_bypass_manual: true
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} with proxy bypass vulnerability`);
});
