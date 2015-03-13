## TOC

## Starting the server

* install gulp: 
``` sudo npm install --global gulp ```

* install the required node modules :
``` sudo npm install ```

* create ``` ./config.ls ``` with the following contents :
```
{rextend} = require \./public/scripts/presentation-plottables/_utils.ls  

config =
  env: \local

  all:
    allow-disk-use: true
    authentication:
      white-list: <[127.0.0.0/31 192.168.0.0/16]>
      strategy: \github
      strategies:
        github:
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
    authentication: strategy: \none
    browserify-debug-mode: true    
    mongo: "mongodb://127.0.0.1:27017/Mongo-Web-IDE/"

module.exports = {} <<< (config.all `rextend` config[config.env] `rextend` env: config.env)
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




## Features

### Aggregation Framework

### Transformation and Presentation

### REST API

### Version Management

## Security