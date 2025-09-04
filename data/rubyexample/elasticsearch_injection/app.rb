# Ruby Elasticsearch Injection HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Elasticsearch injection, search query pollution, index manipulation
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'securerandom'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Elasticsearch-like store for demonstration
$es_store = {}
$es_indices = {}
$es_queries = []

# Elasticsearch injection middleware
class ElasticsearchInjectionMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # ADDITION: pollute Elasticsearch with host information
    index_name = generate_es_index(env["PATH_INFO"], host)
    $es_indices[env["PATH_INFO"]] = index_name
    
    # Store polluted host in Elasticsearch-like store
    $es_store[index_name] = {
      'polluted_host' => host,
      'request_time' => Time.now.to_i,
      'user_agent' => env["HTTP_USER_AGENT"],
      'path' => env["PATH_INFO"],
      'elasticsearch_injection' => true,
      'index_name' => index_name
    }
    
    # Store in environment for later use
    env["es_index"] = index_name
    env["polluted_host"] = host
    env["elasticsearch_injection"] = true
    
    @app.call(env)
  end
  
  private
  
  def generate_es_index(path, host)
    # Vulnerable Elasticsearch index generation
    "hnp-#{path.gsub('/', '-')}-#{host.gsub(/[^a-zA-Z0-9]/, '')}"
  end
end

def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password - Elasticsearch Injection
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end

# Elasticsearch injection helper functions
def es_search(query, index = nil)
  # Vulnerable: direct Elasticsearch query injection
  if query.include?("'") || query.include?('"') || query.include?(';') || query.include?('{')
    # Simulate Elasticsearch injection vulnerability
    $es_queries << {
      'query' => query,
      'index' => index,
      'injected' => true,
      'timestamp' => Time.now.to_i
    }
    
    # Return manipulated results
    return $es_store.values.select { |v| v['polluted_host'].include?(query.gsub(/['";{}]/, '')) }
  end
  
  # Normal search
  $es_queries << {
    'query' => query,
    'index' => index,
    'injected' => false,
    'timestamp' => Time.now.to_i
  }
  
  if index && $es_store[index]
    [$es_store[index]]
  else
    $es_store.values
  end
end

def es_index_document(index, document)
  $es_store[index] = document.merge({
    'indexed_at' => Time.now.to_i,
    'index_name' => index
  })
  index
end

def es_get_document(index, id = nil)
  if id
    # Simulate document retrieval by ID
    $es_store.values.find { |v| v['id'] == id }
  else
    $es_store[index]
  end
end

# Configure Sinatra with middleware
configure do
  use ElasticsearchInjectionMiddleware
end

get '/forgot' do
  content_type 'text/html'
  <<~HTML
    <form method="post">
      <input name="email" placeholder="Email">
      <button type="submit">Send Reset</button>
    </form>
  HTML
end

post '/forgot' do
  email = params[:email] || 'user@example.com'
  token = 'elasticsearch-token-123'
  
  # Get polluted host from Elasticsearch context
  es_index = request.env["es_index"]
  polluted_host = request.env["polluted_host"]
  
  # Get indexed data
  indexed_data = $es_store[es_index]
  
  # ADDITION: build reset URL with Elasticsearch injection context
  reset_url = "http://#{polluted_host}/reset/#{token}"
  reset_url += "?from=elasticsearch_injection&t=#{token}"
  
  # Add Elasticsearch injection indicators
  if indexed_data
    reset_url += "&es_index=#{es_index}"
    reset_url += "&polluted_host=#{indexed_data['polluted_host']}"
    reset_url += "&es_time=#{indexed_data['request_time']}"
  end
  
  # Index additional data in Elasticsearch
  additional_data = {
    'email' => email,
    'token' => token,
    'reset_url' => reset_url,
    'indexed_at' => Time.now.to_i,
    'id' => SecureRandom.uuid
  }
  
  es_index_document(es_index, additional_data.merge(indexed_data || {}))
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  begin
    send_reset_email(email, html)
    "Reset email sent via Elasticsearch injection"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  token = params[:token]
  
  # Get Elasticsearch information
  es_index = request.env["es_index"]
  polluted_host = request.env["polluted_host"]
  indexed_data = $es_store[es_index]
  
  response = {
    ok: true, 
    token: token,
    es_index: es_index,
    polluted_host: polluted_host,
    indexed_data: indexed_data,
    elasticsearch_injection: true
  }
  
  response.to_json
end

# Vulnerable Elasticsearch search endpoint
post '/es/search' do
  content_type 'application/json'
  query = params[:query] || ""
  index = params[:index]
  
  # SOURCE: get host from request headers
  host = request.host
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  
  # ADDITION: Elasticsearch injection vulnerability
  results = es_search(query, index)
  
  # Store search attempt
  search_key = "search:#{Time.now.to_i}"
  es_index_document(search_key, {
    'query' => query,
    'index' => index,
    'host' => host,
    'results_count' => results.length,
    'searched_at' => Time.now.to_i
  })
  
  {
    success: true,
    query: query,
    index: index,
    results: results,
    results_count: results.length,
    search_key: search_key,
    elasticsearch_injection: true
  }.to_json
end

# Elasticsearch index endpoint
get '/es/index/:index_name' do
  content_type 'application/json'
  index_name = params[:index_name]
  
  # Get all documents in this index
  documents = {}
  $es_store.each do |key, value|
    if value['index_name'] == index_name
      documents[key] = value
    end
  end
  
  {
    index: index_name,
    documents: documents,
    document_count: documents.length,
    elasticsearch_exposed: true
  }.to_json
end

# Elasticsearch query endpoint (vulnerable to injection)
get '/es/query' do
  content_type 'application/json'
  query = params[:q] || ""
  index = params[:index]
  
  # Vulnerable: direct query injection
  results = es_search(query, index)
  
  {
    query: query,
    index: index,
    results: results,
    results_count: results.length,
    elasticsearch_query_injection: true
  }.to_json
end

# Elasticsearch status endpoint
get '/es/status' do
  content_type 'application/json'
  {
    total_indices: $es_indices.size,
    total_documents: $es_store.size,
    total_queries: $es_queries.length,
    es_indices: $es_indices,
    es_store: $es_store,
    es_queries: $es_queries,
    elasticsearch_status_exposed: true
  }.to_json
end

# Elasticsearch document endpoint
get '/es/document/:id' do
  content_type 'application/json'
  id = params[:id]
  
  # Find document by ID
  document = es_get_document(nil, id)
  
  if document
    {
      id: id,
      document: document,
      elasticsearch_document_exposed: true
    }.to_json
  else
    {
      error: "Document not found",
      id: id
    }.to_json
  end
end

# Elasticsearch bulk operations endpoint (vulnerable)
post '/es/bulk' do
  content_type 'application/json'
  operations = params[:operations] || []
  
  # SOURCE: get host from request headers
  host = request.host
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  
  results = []
  operations.each do |op|
    if op['index'] && op['document']
      # Vulnerable: direct document indexing
      index_name = op['index']
      document = op['document'].merge({
        'bulk_indexed_at' => Time.now.to_i,
        'bulk_host' => host
      })
      
      es_index_document(index_name, document)
      results << { 'index' => index_name, 'status' => 'created' }
    end
  end
  
  {
    success: true,
    operations: operations,
    results: results,
    elasticsearch_bulk_injection: true
  }.to_json
end
