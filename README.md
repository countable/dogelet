dogelet
=======

Dead Simple Dogeoin Wallet in Node.JS with coffeescript.

These instructions were typed in a hurry and aren't great yet.

You'll have to install dogecoind first. Then clone this wallet and install deps with npm. Then create a local config file. It is in the .gitignore if you do this, so your sensitive info isn't shared:

```

cp config.coffee.template config.coffee

```

Then fill out all the values in config.coffee for your system. Remember to compile any coffee file after changing it.

```

coffee -c config.coffee

```

This wallet currently uses sendgrid and redis for email and sessions, respectively, but it's easy to change this.

