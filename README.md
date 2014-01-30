dogelet
=======

Dead Simple Dogeoin Wallet in Node.JS with coffeescript. Clone it and install deps with npm.

You'll have to install dogecoind first.

```

cp config.coffee.template config.coffee

```

Then fill out all the values in config.coffee for your system. Remember to compile any coffee file after changing it.

```

coffee -c config.coffee

```

This wallet currently uses sendgrid and redis for email and sessions, respectively, but it's easy to change this.

