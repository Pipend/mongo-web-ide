## TOC

## Starting the server

* install the required node modules :
``` sudo npm install ```

* install the client-side javascript libraries :
``` sudo bower install ```

* create ``` ./config.ls ``` with the following contents :
```
config =
  env: \release
  all:
    mongo: "mongodb://127.0.0.1:27017/MobiOne-events/"
    mongoOptions:
      auto_reconnect: true
      db:
        w:1
      server:
        socketOptions: 
          keepAlive: 1
    port: 3000
    test-ips: <[127.0.0.1]>
  release: {}
  preview: {}
  local:
    mongo: "mongodb://127.0.0.1:27017/MobiOne-events/"

module.exports = config.all <<< config[config.env] <<< env: config.env
```

* run the server
``` ./start.sh ```



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