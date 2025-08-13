let nodemailer = require('nodemailer');
let express = require('express');
let backend = require('./backend');

let app = express();

let config = JSON.parse(fs.readFileSync('config.json', 'utf8'));

app.post('/resetpass', (req, res) => {
  let email = req.query.email;
  let transport = nodemailer.createTransport(config.smtp);
  let token = backend.getUserSecretResetToken(email);
  transport.sendMail({
    from: 'webmaster@example.com',
    to: email,
    subject: 'Forgot password',
    text: `Click to reset password: https://${req.host}/resettoken/${token}`,
  });
});

  app.post("/forgot-password", function (req, res, next) {
    async.waterfall(
      [
        function (done) {
          crypto.randomBytes(20, function (err, buf) {
            var token = buf.toString("hex");
            done(err, token);
          });
        },
        function (token, done) {
          if (!exists(req.body.email)) {
            req.flash(
              "emailSend",
              "Please enter a valid Email address and try again (error code: #1000)"
            );
            return res.redirect("/forgot-password");
          }
          if (req.body.email.trim().length < 1) {
            req.flash(
              "emailSend",
              "Please enter a valid Email address and try again"
            );
            return res.redirect("/forgot-password");
          }
          User.findOne(
            {
              "user.email": req.body.email.toLowerCase(),
            },
            function (err, users) {
              if (err) return console.error(err);
              if (!users) {
                req.flash(
                  "emailSend",
                  "If this e-mail exists, then an email has been sent to '" +
                    req.body.email.toLowerCase() +
                    "' with a link to change the password."
                );
                return res.redirect("/forgot-password");
              }
              users.user.resetPasswordToken = token;
              users.user.resetPasswordExpires = Date.now() + 3600000; // 1 hour

              users.save(function (err) {
                done(err, token, users);
              });
            }
          );
        },
        function (token, users, done) {
          var smtpTransport = nodemailer.createTransport(
            nodemailerSendgrid({
              apiKey: process.env.MAIL_API_KEY,
            })
          );
          fs.readFile("resetPassword.html", "utf8", function (err, htmlData) {
            if (err) {
              console.error("failed to read file: ", err);
              return res.redirect("back");
            }
            let template = handlebars.compile(htmlData);
            let data = {
              resetLink:
                process.env.SITE_PROTOCOL +
                req.headers.host +
                "/reset/" +
                token,
              sentTo: users.user.email.toLowerCase(),
            };
            let htmlToSend = template(data);
            var mailOptions = {
              to: users.user.email.toLowerCase(),
              from: process.env.FROM_EMAIL,
              subject: "Lines Police CAD Reset Password",
              html: htmlToSend,
            };
            smtpTransport.sendMail(mailOptions, function (err) {
              req.flash(
                "emailSend",
                "If this e-mail exists, then an email has been sent to " +
                  users.user.email.toLowerCase() +
                  " with a link to change the password."
              );
              done(err, "done");
            });
          });
        },
      ],
      function (err) {
        if (err) return next(err);
        res.render("forgot-password", {
          message: req.flash("emailSend"),
        });
      }
    );
  });