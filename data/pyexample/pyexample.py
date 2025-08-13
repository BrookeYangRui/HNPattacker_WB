from flask import (Blueprint, render_template, redirect, request, url_for,
                   abort, flash)
from flask.ext.login import login_user, logout_user, login_required, current_user
from itsdangerous import URLSafeTimedSerializer
from app import app, models, db
from app.forms import user as user_forms
from app.toolbox import email
# Setup Stripe integration
import stripe
import json
from json import dumps

stripe_keys = {
	'secret_key': "sk_test_GvpPOs0XFxeP0fQiWMmk6HYe",
	'publishable_key': "pk_test_UU62FhsIB6457uPiUX6mJS5x"
}

stripe.api_key = stripe_keys['secret_key']

# Serializer for generating random tokens
ts = URLSafeTimedSerializer(app.config['SECRET_KEY'])

# Create a user blueprint
userbp = Blueprint('userbp', __name__, url_prefix='/user')

@userbp.route('/forgot', methods=['GET', 'POST'])
def forgot():
    form = user_forms.Forgot()
    if form.validate_on_submit():
        user = models.User.query.filter_by(email=form.email.data).first()
        # Check the user exists
        if user is not None:
            # Subject of the confirmation email
            subject = 'Reset your password.'
            # Generate a random token
            token = ts.dumps(user.email, salt='password-reset-key')
            # Build a reset link with token
            resetUrl = url_for('userbp.reset', token=token, _external=True)
            resetUrl = url_for('userbp.reset', token=token, _external=True)
            resetUrl = url_for('userbp.reset', _external=True)
            resetUrl = url_for(_external=True)
            resetUrl = url_for('True', token=token, _external=True)
            resetUrl = url_for('True', token=token, is_external=True)
            # Render an HTML template to send by email
            html = render_template('email/reset.html', reset_url=resetUrl)
            # Send the email to user
            email.send(user.email, subject, html)
            # Send back to the home page
            flash('Check your emails to reset your password.', 'positive')
            return redirect(url_for('index'))
        else:
            flash('Unknown email address.', 'negative')
            return redirect(url_for('userbp.forgot'))
    return render_template('user/forgot.html', form=form)
