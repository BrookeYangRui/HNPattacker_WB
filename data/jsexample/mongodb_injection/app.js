// Node.js MongoDB Injection HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: MongoDB injection, NoSQL injection, database pollution
// SINK: send email with polluted reset link

const express = require('express');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// MongoDB-like store for demonstration
const mongoStore = new Map();
const mongoCollections = new Map();
const mongoQueries = [];

// MongoDB injection middleware
const mongoInjectionMiddleware = (req, res, next) => {
    // SOURCE: extract host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
        host = req.headers['x-forwarded-host'];
    }
    
    // ADDITION: pollute MongoDB with host information
    const collectionName = generateMongoCollection(req.path, host);
    mongoCollections.set(req.path, collectionName);
    
    // Store polluted host in MongoDB-like store
    mongoStore.set(collectionName, {
        polluted_host: host,
        request_time: Date.now(),
        user_agent: req.headers['user-agent'],
        path: req.path,
        mongodb_injection: true,
        collection_name: collectionName
    });
    
    // Store in request for later use
    req.mongoCollection = collectionName;
    req.pollutedHost = host;
    req.mongodbInjection = true;
    
    next();
};

// MongoDB injection helper functions
function generateMongoCollection(path, host) {
    // Vulnerable MongoDB collection generation
    return `hnp_${path.replace(/\//g, '_')}_${host.replace(/[^a-zA-Z0-9]/g, '')}`;
}

function mongoFind(query, collection) {
    // Vulnerable: direct MongoDB query injection
    if (typeof query === 'string' && (query.includes("'") || query.includes('"') || query.includes(';') || query.includes('$'))) {
        // Simulate MongoDB injection vulnerability
        mongoQueries.push({
            query: query,
            collection: collection,
            injected: true,
            timestamp: Date.now()
        });
        
        // Return manipulated results
        const cleanQuery = query.replace(/['";$]/g, '');
        return Array.from(mongoStore.values()).filter(v => v.polluted_host.includes(cleanQuery));
    }
    
    // Normal query
    mongoQueries.push({
        query: query,
        collection: collection,
        injected: false,
        timestamp: Date.now()
    });
    
    if (collection && mongoStore.has(collection)) {
        return [mongoStore.get(collection)];
    }
    return Array.from(mongoStore.values());
}

function mongoInsert(document, collection) {
    const doc = {
        ...document,
        inserted_at: Date.now(),
        collection_name: collection
    };
    mongoStore.set(collection, doc);
    return collection;
}

function mongoUpdate(query, update, collection) {
    // Vulnerable: direct update injection
    if (typeof query === 'string' && (query.includes("'") || query.includes('"') || query.includes(';') || query.includes('$'))) {
        mongoQueries.push({
            query: query,
            update: update,
            collection: collection,
            injected: true,
            timestamp: Date.now()
        });
    }
    
    if (collection && mongoStore.has(collection)) {
        const existing = mongoStore.get(collection);
        const updated = { ...existing, ...update, updated_at: Date.now() };
        mongoStore.set(collection, updated);
        return updated;
    }
    return null;
}

// Express app setup
const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Apply MongoDB injection middleware
app.use(mongoInjectionMiddleware);

// Forgot password form
app.get('/forgot', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send(`
        <form method="post">
            <input name="email" placeholder="Email">
            <button type="submit">Send Reset</button>
        </form>
    `);
});

// Forgot password submission
app.post('/forgot', async (req, res) => {
    const email = req.body.email || 'user@example.com';
    const token = 'mongodb-token-123';
    
    // Get polluted host from MongoDB context
    const mongoCollection = req.mongoCollection;
    const pollutedHost = req.pollutedHost;
    
    // Get stored data
    const storedData = mongoStore.get(mongoCollection);
    
    // ADDITION: build reset URL with MongoDB injection context
    let resetURL = `http://${pollutedHost}/reset/${token}`;
    resetURL += `?from=mongodb_injection&t=${token}`;
    
    // Add MongoDB injection indicators
    if (storedData) {
        resetURL += `&mongo_collection=${mongoCollection}`;
        resetURL += `&polluted_host=${storedData.polluted_host}`;
        resetURL += `&mongo_time=${storedData.request_time}`;
    }
    
    // Store additional data in MongoDB
    const additionalData = {
        email: email,
        token: token,
        reset_url: resetURL,
        inserted_at: Date.now()
    };
    
    mongoInsert(additionalData, mongoCollection);
    
    const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
    
    try {
        await sendResetEmail(email, html);
        res.json({
            message: 'Reset email sent via MongoDB injection',
            mongodb_injection: true,
            mongo_collection: mongoCollection
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Password reset
app.get('/reset/:token', (req, res) => {
    const token = req.params.token;
    
    // Get MongoDB information
    const mongoCollection = req.mongoCollection;
    const pollutedHost = req.pollutedHost;
    const storedData = mongoStore.get(mongoCollection);
    
    res.json({
        ok: true,
        token: token,
        mongo_collection: mongoCollection,
        polluted_host: pollutedHost,
        stored_data: storedData,
        mongodb_injection: true
    });
});

// Vulnerable MongoDB find endpoint
app.post('/mongo/find', (req, res) => {
    const query = req.body.query || "";
    const collection = req.body.collection;
    
    // SOURCE: get host from request headers
    const host = req.headers.host;
    
    // ADDITION: MongoDB injection vulnerability
    const results = mongoFind(query, collection);
    
    // Store query attempt
    const queryKey = `query:${Date.now()}`;
    mongoInsert({
        query: query,
        collection: collection,
        host: host,
        results_count: results.length,
        queried_at: Date.now()
    }, queryKey);
    
    res.json({
        success: true,
        query: query,
        collection: collection,
        results: results,
        results_count: results.length,
        query_key: queryKey,
        mongodb_injection: true
    });
});

// MongoDB collection endpoint
app.get('/mongo/collection/:collectionName', (req, res) => {
    const collectionName = req.params.collectionName;
    
    // Get all documents in this collection
    const documents = {};
    mongoStore.forEach((value, key) => {
        if (value.collection_name === collectionName) {
            documents[key] = value;
        }
    });
    
    res.json({
        collection: collectionName,
        documents: documents,
        document_count: Object.keys(documents).length,
        mongodb_exposed: true
    });
});

// MongoDB query endpoint (vulnerable to injection)
app.get('/mongo/query', (req, res) => {
    const query = req.query.q || "";
    const collection = req.query.collection;
    
    // Vulnerable: direct query injection
    const results = mongoFind(query, collection);
    
    res.json({
        query: query,
        collection: collection,
        results: results,
        results_count: results.length,
        mongodb_query_injection: true
    });
});

// MongoDB update endpoint (vulnerable)
app.post('/mongo/update', (req, res) => {
    const query = req.body.query || "";
    const update = req.body.update || {};
    const collection = req.body.collection;
    
    // SOURCE: get host from request headers
    const host = req.headers.host;
    
    // ADDITION: MongoDB update injection vulnerability
    const result = mongoUpdate(query, update, collection);
    
    // Store update attempt
    const updateKey = `update:${Date.now()}`;
    mongoInsert({
        query: query,
        update: update,
        collection: collection,
        host: host,
        updated_at: Date.now()
    }, updateKey);
    
    res.json({
        success: true,
        query: query,
        update: update,
        collection: collection,
        result: result,
        update_key: updateKey,
        mongodb_update_injection: true
    });
});

// MongoDB status endpoint
app.get('/mongo/status', (req, res) => {
    res.json({
        total_collections: mongoCollections.size,
        total_documents: mongoStore.size,
        total_queries: mongoQueries.length,
        mongo_collections: Object.fromEntries(mongoCollections),
        mongo_store: Object.fromEntries(mongoStore),
        mongo_queries: mongoQueries,
        mongodb_status_exposed: true
    });
});

// MongoDB aggregation endpoint (vulnerable)
app.post('/mongo/aggregate', (req, res) => {
    const pipeline = req.body.pipeline || [];
    
    // SOURCE: get host from request headers
    const host = req.headers.host;
    
    // Vulnerable: direct pipeline injection
    let results = [];
    pipeline.forEach((stage, index) => {
        if (typeof stage === 'string' && (stage.includes("'") || stage.includes('"') || stage.includes(';') || stage.includes('$'))) {
            // Simulate aggregation injection
            mongoQueries.push({
                query: `aggregate:${stage}`,
                collection: 'aggregation',
                injected: true,
                timestamp: Date.now()
            });
        }
        
        // Process aggregation stage
        if (stage.$match) {
            results = mongoFind(stage.$match, null);
        }
    });
    
    res.json({
        success: true,
        pipeline: pipeline,
        results: results,
        results_count: results.length,
        mongodb_aggregation_injection: true
    });
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
        subject: 'Reset your password - MongoDB Injection',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Start server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`MongoDB injection server running on port ${PORT}`);
});
