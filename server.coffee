http = require 'http'
fs = require 'fs'

port = parseInt process.argv[2], 10

client = ''

fs.readFile 'client.coffee', (err, data) ->
  process.exit(1) if err?
  client = data

playerPictures = []
[
    'resources/player/red.png',
    'resources/player/green.png',
    'resources/player/blue.png',
    'resources/player/teal.png',
    'resources/player/white.png',
    'resources/player/black.png',
    'resources/player/violet.png',
    'resources/player/gray.png',
    'resources/player/yellow.png'
].forEach (file) ->
    fs.readFile file, (err, data) ->
        process.exit(1) if err?
        playerPictures.push 'data:image/png;base64,' + data.toString 'base64'

server = http.createServer (req, res) ->
  res.writeHead 200, {'Content-Type': 'text/html'}
  res.end '<html><head><style>body{margin:0;}</style><meta name="viewport" content="user-scalable=no, width=device-width" /><script src="/socket.io/socket.io.js"></script>' +
    '<script src="http://coffeescript.org/extras/coffee-script.js"></script>' + 
    '<script type="text/coffeescript">' + client + '</script></head><body></body></html>'
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

players = {}
setInterval ->
    for id, player of players
        diff = player.wantPos - player.pos
        dPos = diff/10
        dPos = 1 if dPos > 0 && dPos < 1
        dPos = -1 if dPos < 0 && dPos > -1
        dPos = Math.floor(dPos)
        players[id].pos = player.pos + dPos
, 20
io.sockets.on 'connection', (socket) ->
  console.log 'connection ' + socket.id
  intervals = []
  socket.on 'map', ->
    socket.emit 'images', players
    intervals.push setInterval ->
        cleanPlayers = {}
        for id, player of players
            cleanPlayers[id] = {pos: player.pos}
        socket.emit 'players', cleanPlayers
    , 20

  socket.on 'pos', (data) ->
    if players.hasOwnProperty socket.id
        players[socket.id].wantPos = data
    else
        players[socket.id] = {wantPos: data, pos: data, image: playerPictures.pop()}
        console.log 'sending image'
        socket.emit 'image', players[socket.id].image
        socket.broadcast.emit 'images', players

  socket.on 'disconnect', ->
    for interval in intervals
        clearInterval interval
    delete players[socket.id]
    console.log 'disconnection ' + socket.id

console.log 'Server running at *:' + port


