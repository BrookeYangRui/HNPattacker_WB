// Node.js GraphQL Injection HNP example
// SOURCE: req.headers.host, req.headers['x-forwarded-host']
// ADDITION: GraphQL injection, query pollution, schema manipulation
// SINK: send email with polluted reset link

const express = require('express');
const { graphqlHTTP } = require('express-graphql');
const { buildSchema } = require('graphql');
const nodemailer = require('nodemailer');

const RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>";

// GraphQL-like store for demonstration
const graphqlStore = new Map();
const graphqlQueries = [];
const graphqlSchemas = new Map();

// GraphQL injection middleware
const graphqlInjectionMiddleware = (req, res, next) => {
    // SOURCE: extract host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
        host = req.headers['x-forwarded-host'];
    }
    
    // ADDITION: pollute GraphQL with host information
    const schemaName = generateGraphQLSchema(req.path, host);
    graphqlSchemas.set(req.path, schemaName);
    
    // Store polluted host in GraphQL-like store
    graphqlStore.set(schemaName, {
        polluted_host: host,
        request_time: Date.now(),
        user_agent: req.headers['user-agent'],
        path: req.path,
        graphql_injection: true,
        schema_name: schemaName
    });
    
    // Store in request for later use
    req.graphqlSchema = schemaName;
    req.pollutedHost = host;
    req.graphqlInjection = true;
    
    next();
};

// GraphQL injection helper functions
function generateGraphQLSchema(path, host) {
    // Vulnerable GraphQL schema generation
    return `hnp_${path.replace(/\//g, '_')}_${host.replace(/[^a-zA-Z0-9]/g, '')}`;
}

function executeGraphQLQuery(query, schema) {
    // Vulnerable: direct GraphQL query injection
    if (typeof query === 'string' && (query.includes("'") || query.includes('"') || query.includes(';') || query.includes('{') || query.includes('}'))) {
        // Simulate GraphQL injection vulnerability
        graphqlQueries.push({
            query: query,
            schema: schema,
            injected: true,
            timestamp: Date.now()
        });
        
        // Return manipulated results
        const cleanQuery = query.replace(/['";{}]/g, '');
        return Array.from(graphqlStore.values()).filter(v => v.polluted_host.includes(cleanQuery));
    }
    
    // Normal query
    graphqlQueries.push({
        query: query,
        schema: schema,
        injected: false,
        timestamp: Date.now()
    });
    
    if (schema && graphqlStore.has(schema)) {
        return [graphqlStore.get(schema)];
    }
    return Array.from(graphqlStore.values());
}

function createGraphQLSchema(schemaName, typeDefs) {
    // Vulnerable: direct schema creation
    try {
        const schema = buildSchema(typeDefs);
        graphqlSchemas.set(schemaName, schema);
        return { success: true, schema: schemaName };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Express app setup
const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Apply GraphQL injection middleware
app.use(graphqlInjectionMiddleware);

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
    const token = 'graphql-token-123';
    
    // Get polluted host from GraphQL context
    const graphqlSchema = req.graphqlSchema;
    const pollutedHost = req.pollutedHost;
    
    // Get indexed data
    const indexedData = graphqlStore.get(graphqlSchema);
    
    // ADDITION: build reset URL with GraphQL injection context
    let resetURL = `http://${pollutedHost}/reset/${token}`;
    resetURL += `?from=graphql_injection&t=${token}`;
    
    // Add GraphQL injection indicators
    if (indexedData) {
        resetURL += `&graphql_schema=${graphqlSchema}`;
        resetURL += `&polluted_host=${indexedData.polluted_host}`;
        resetURL += `&graphql_time=${indexedData.request_time}`;
    }
    
    // Index additional data in GraphQL
    const additionalData = {
        email: email,
        token: token,
        reset_url: resetURL,
        indexed_at: Date.now(),
        id: Math.random().toString(36).substr(2, 9)
    };
    
    graphqlStore.set(graphqlSchema, { ...indexedData, ...additionalData });
    
    const html = RESET_TEMPLATE.replace(/%s/g, resetURL);
    
    try {
        await sendResetEmail(email, html);
        res.json({
            message: 'Reset email sent via GraphQL injection',
            graphql_injection: true,
            graphql_schema: graphqlSchema,
            polluted_host: pollutedHost
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Password reset
app.get('/reset/:token', (req, res) => {
    const token = req.params.token;
    
    // Get GraphQL information
    const graphqlSchema = req.graphqlSchema;
    const pollutedHost = req.pollutedHost;
    const indexedData = graphqlStore.get(graphqlSchema);
    
    res.json({
        ok: true,
        token: token,
        graphql_schema: graphqlSchema,
        polluted_host: pollutedHost,
        indexed_data: indexedData,
        graphql_injection: true
    });
});

// Vulnerable GraphQL endpoint
app.post('/graphql', (req, res) => {
    const { query, variables, operationName } = req.body;
    
    // SOURCE: get host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
        host = req.headers['x-forwarded-host'];
    }
    
    // ADDITION: GraphQL injection vulnerability
    const results = executeGraphQLQuery(query, req.graphqlSchema);
    
    // Store query attempt
    const queryKey = `query:${Date.now()}`;
    graphqlStore.set(queryKey, {
        query: query,
        variables: variables,
        operation_name: operationName,
        host: host,
        results_count: results.length,
        queried_at: Date.now()
    });
    
    res.json({
        data: results,
        query: query,
        variables: variables,
        operation_name: operationName,
        results_count: results.length,
        query_key: queryKey,
        graphql_injection: true
    });
});

// GraphQL schema endpoint
app.get('/graphql/schema/:schemaName', (req, res) => {
    const schemaName = req.params.schemaName;
    
    // Get all data in this schema
    const data = {};
    graphqlStore.forEach((value, key) => {
        if (value.schema_name === schemaName) {
            data[key] = value;
        }
    });
    
    res.json({
        schema: schemaName,
        data: data,
        data_count: Object.keys(data).length,
        graphql_exposed: true
    });
});

// GraphQL query endpoint (vulnerable to injection)
app.get('/graphql/query', (req, res) => {
    const query = req.query.q || "";
    const schema = req.query.schema;
    
    // Vulnerable: direct query injection
    const results = executeGraphQLQuery(query, schema);
    
    res.json({
        query: query,
        schema: schema,
        results: results,
        results_count: results.length,
        graphql_query_injection: true
    });
});

// GraphQL schema creation endpoint (vulnerable)
app.post('/graphql/schema', (req, res) => {
    const { name, type_defs } = req.body;
    
    // SOURCE: get host from request headers
    let host = req.headers.host;
    if (req.headers['x-forwarded-host']) {
        host = req.headers['x-forwarded-host'];
    }
    
    // Vulnerable: direct schema creation
    const result = createGraphQLSchema(name, type_defs);
    
    if (result.success) {
        // Store schema information
        graphqlStore.set(name, {
            schema_name: name,
            type_defs: type_defs,
            created_at: Date.now(),
            host: host,
            graphql_schema_created: true
        });
    }
    
    res.json({
        success: result.success,
        schema_name: name,
        result: result,
        graphql_schema_injection: true
    });
});

// GraphQL status endpoint
app.get('/graphql/status', (req, res) => {
    res.json({
        total_schemas: graphqlSchemas.size,
        total_data: graphqlStore.size,
        total_queries: graphqlQueries.length,
        graphql_schemas: Array.from(graphqlSchemas.keys()),
        graphql_store: Object.fromEntries(graphqlStore),
        graphql_queries: graphqlQueries,
        graphql_status_exposed: true
    });
});

// GraphQL introspection endpoint (vulnerable)
app.get('/graphql/introspect', (req, res) => {
    const schemaName = req.query.schema;
    
    if (schemaName && graphqlStore.has(schemaName)) {
        const schemaData = graphqlStore.get(schemaName);
        res.json({
            schema: schemaName,
            introspection: schemaData,
            graphql_introspection_exposed: true
        });
    } else {
        res.json({
            available_schemas: Array.from(graphqlStore.keys()),
            graphql_introspection_exposed: true
        });
    }
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
        subject: 'Reset your password - GraphQL Injection',
        html: htmlBody
    };

    return transporter.sendMail(mailOptions);
}

// Start server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`GraphQL Injection server running on port ${PORT}`);
});
