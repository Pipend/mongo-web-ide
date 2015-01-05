## TOC

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/Mobitrans/mongo-web-ide?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Starting the server

* install gulp: 
``` sudo npm install --global gulp ```

* install the required node modules :
``` sudo npm install ```

* create ``` ./config.ls ``` with the following contents :
```
config =
  env: \local

  all:
    allow-disk-use: true
    authentication:
      strategy:
        name: \github
        options:
          client-id: ""
          client-secret: ""
          organization-name: ""
    browserify-debug-mode: false
    connection-strings: [
      {
        name: \local
        host: \127.0.0.1
        port: 27017
      }
    ]
    default-connection-details: {
      server-name: \ubuntu
      database: \MobiOne-events
      collection: \events
    }    
    mongo: "mongodb://127.0.0.1:27017/Mongo-Web-IDE/"
    mongoOptions:
      auto_reconnect: true
      db:
        w:1
      server:
        socketOptions: 
          keepAlive: 1    
    port: 3000
    test-ips: <[127.0.0.1 localhost]>

  release: {}  

  preview: {}

  local:
    authentication: 
      strategy: 
        name: \none
    browserify-debug-mode: true    
    mongo: "mongodb://127.0.0.1:27017/Mongo-Web-IDE/"

module.exports = config.all <<< config[config.env] <<< env: config.env
```

* run the server
``` gulp ```

## Usage

* paste the following script in the IDE : 
```
$project:
  ip: 1
  country: 1
  
$limit: 5
```

* hit the execute button to be amazed!

## Sublime Stylus build command

* install nib module globally :
``` sudo npm install -g nib ```

* To create a new build system with the following contents goto Tools > Build System > New Build System
```
{
  "cmd": ["stylus", "--include", "/usr/local/lib/node_modules/nib/lib", "$file"],
  "selector" : "source.styl",
  "path" : "/usr/local/bin"
}
```

* Save it as ``` Stylus.sublime-build ```






