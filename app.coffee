
###
Module dependencies.
###
express = require("express")
http = require("http")
path = require("path")

crypto = require 'crypto'
connect = require('connect')
RedisStore = require('connect-redis')(connect)

app = express()

# import configuration options
require('config')(app)

dogecoin = (require 'node-dogecoin')()
dogecoin.auth(app.get('dogecoin_username'),app.get('dogecoin_password')).set('host', 'localhost').set({port:22555})

app.set 'name', 'dogelet'
app.set 'admin_email', "info@dogelet.com"
app.set 'email_name', 'DogeLet'

require('implied-mail').sendgrid(app)

mailer = app.get 'mailer'

# all environments
app.set "port", process.env.PORT or 3000
app.set "views", __dirname + "/views"
app.set "view engine", "jade"

SALT = app.get('salt')

app.use(express.cookieParser())
app.use(connect.session({ store: new RedisStore({port:6379,host:'localhost'}), secret: app.get('secret') }))

app.use express.favicon()
app.use express.logger("dev")
app.use express.bodyParser()
app.use express.methodOverride()

# Middleware to make request available to templates.
app.use (req,res,next)->
  res.locals.req = res.locals.request = req
  next()

app.use app.router
app.use express.static(path.join(__dirname, "public"))

# development only
app.use express.errorHandler()  if "development" is app.get("env")



EMAIL_REGEX = ///
[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?
///



get_email_hash = (email, callback)->
  
  unless EMAIL_REGEX.test email
    throw 'Invalid Email'
  
  hash = crypto.createHmac('sha1', SALT).update(email).digest('hex');



security_error = (res, msg)->
  res.render 'message',
    message: msg


login_required = (req, res, next)->

  if req.session.email

    if req.session.address
      next()

    else
      res.send 'Your account seems broken.'

  else
    res.send 'Login first.'



app.get '/', (req, res)->
  
  email = req.session.email

  if email and req.session.address # If we're logged in properly...

    dogecoin.getBalance email, (err, result)->

      if err
        return security_error res, ''+err

      # For some reason empty accounts have a composite object as balance.
      unless typeof result is 'number'
        result = result.result


      res.render 'index',
        balance: result
        address: req.session.address


  else
    res.render 'index',
      email: null



app.get '/signup', (req,res)->
  
  email = req.query.email
  hash = get_email_hash email

  unless EMAIL_REGEX.test email
    return security_error res, 'Invalid email address.'
   
  dogecoin.getAddressesByAccount email, (err, result)->
    
    if err
      return security_error res, ''+err


    if result.length

      mailer.send_mail
          to: email
          subject: "Your DogeLet (Dogecoin wallet)"
          body:"""
          Here's your secure DogeLet link:
          
          http://#{app.get('host')}/login?email=#{email}&hash=#{hash}

          WARNING: Never share this with anyone, as they will be able to use your wallet!

          """
        , (success, message)->
          
          unless success
            return security_error res, message

          return security_error res, 'You already have a wallet. Check your email (search inbox for dogelet.com)'

    else
      dogecoin.getNewAddress email, (err, result)->
        
        if err
          return security_error res, err

        mailer.send_mail
            to: email
            subject: "Your New DogeLet (Dogecoin wallet)"
            body:"""
            Here's your secure DogeLet link:
            
            http://#{app.get('host')}/login?email=#{email}&hash=#{hash}

            WARNING: Never share this with anyone, as they will be able to use your wallet!

            """
          , (success, message)->

            unless success
              return security_error res, message

            return security_error res, 'Your new wallet has been created! Check your email (search inbox for dogelet.com)'



app.get '/login', (req,res)->

  unless EMAIL_REGEX.test req.query.email
    return security_error res, 'Invalid email address.'

  if get_email_hash(req.query.email) is req.query.hash # hash is good.
    req.session.email = req.query.email
    dogecoin.getAddressesByAccount req.query.email, (err, result)->
      if result.length isnt 1
        return security_error res, "Duplicate address."
      req.session.address = result[0]
      res.redirect '/'
  
  else
    req.session.email = null
    req.session.address = null
    security_error res, 'Bad credentials.'



app.get '/send', login_required, (req,res)->

  email = req.query.email

  if email isnt req.session.email
    return security_error res, 'Sender email does not match account email.'

  unless /[0-9]*\.?[0-9]/.test req.query.amount
    return security_error res, 'Badly formed amount.'

  unless /[a-zA-Z\d]+/.test req.query.send_to
    return security_error res, 'Badly formed recipient address'

  dogecoin.validateAddress req.query.send_to, (err, result)->
    if err
      return security_error '' + err
    if result.isvalid
      dogecoin.sendFrom email, req.query.send_to, parseFloat(req.query.amount), 1, ->
        res.send arguments



app.get '/history', login_required, (req,res)->
  
  page = parseInt(req.query.page or '0')

  dogecoin.listTransactions req.session.email, 11, page * 0, (err, transactions)->
    if err
      return security_error '' + err
    res.render 'history',
      transactions: transactions
      page: page


app.get '/history/:tid', login_required, (req,res)->

  dogecoin.gettransaction req.params.tid, (err, transaction)->
    if err
      return security_error '' + err
    res.send transaction


app.get '/logout', (req,res)->
  req.session.email = null
  req.session.address = null
  res.redirect '/'


http.createServer(app).listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

