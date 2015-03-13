request = require('request')
request.get('http://ipinfo.io/8.8.8.8', {json: true}, (e, r, details) ->
    console.log details
)