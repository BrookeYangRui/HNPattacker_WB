# web2py_example.py
# SOURCE: request.env.http_host, request.env.wsgi_url_scheme
# ADDITION: string formatting, dict mutation, function call chain
# SINK: mail.send() with reset link

def forgot():
    import uuid
    token = str(uuid.uuid4())
    email = request.vars.get('email', 'user@example.com')
    # SOURCE: host/scheme from request.env
    base = '%s://%s' % (request.env.wsgi_url_scheme, request.env.http_host)
    path = URL('reset', args=[token], scheme=True, host=True)
    reset_url = base + path
    # ADDITION: dict mutation, function call chain
    params = {'from': 'forgot', 't': token}
    query = '&'.join(['%s=%s' % (k, v) for k, v in params.items()])
    if '?' not in reset_url:
        reset_url += '?' + query
    else:
        reset_url += '&' + query
    # SINK: mail.send
    html = '<p>Reset link: <a href="%s">%s</a></p>' % (reset_url, reset_url)
    mail.send(to=[email], subject='Reset your password', message=html)
    return 'OK'

def reset():
    token = request.args(0)
    return dict(token=token)
