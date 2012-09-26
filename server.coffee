http = require 'http'

port = parseInt process.argv[2], 10

server = http.createServer (req, res) ->
  res.writeHead 200, {'Content-Type': 'text/html'}
  res.end 'hello world'
server.listen port

io = (require 'socket.io').listen server

io.configure 'production', ->
  io.enable 'browser client etag'
  io.set 'log level', 1

  io.set 'transports', [
    'websocket'
    'flashsocket'
    'htmlfile'
    'xhr-polling'
    'jsonp-polling'
  ]

io.sockets.on 'connection', (socket) ->
  console.log 'connection ' + socket.id
  socket.on 'disconnect', ->
    console.log 'disconnection ' + socket.id

console.log 'Server running at *:' + port


