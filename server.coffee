http = require 'http'
fs = require 'fs'

port = parseInt process.argv[2], 10

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

obstacleImages = []
[
  'resources/obstacle/cigarette.png',
  'resources/obstacle/patents.png',
  'resources/obstacle/stevebill.png'
].forEach (file) ->
  fs.readFile file, (err, data) ->
    process.exit(1) if err?
    obstacleImages.push 'data:image/png;base64,' + data.toString 'base64'

collectibleImages = []
[
  'resources/collectible/fraktio.png',
  'resources/collectible/druid.png',
  'resources/collectible/w3.png'
].forEach (file) ->
  fs.readFile file, (err, data) ->
    process.exit(1) if err?
    collectibleImages.push 'data:image/png;base64,' + data.toString 'base64'

server = http.createServer (req, res) ->
  res.writeHead 200, {'Content-Type': 'text/html'}
  fs.readFile 'client.coffee', (err, data) ->
    if err? then return res.end 'reading client script failed'
    res.end '<html><head><style>body{margin:0;}</style><meta name="viewport" content="user-scalable=no, width=device-width" /><script src="/socket.io/socket.io.js"></script>' +
      '<script src="http://coffeescript.org/extras/coffee-script.js"></script>' +
      '<script type="text/coffeescript">' + data + '</script></head><body></body></html>'
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
obstacles = []
collectibles = []
setInterval ->
  for id, player of players
    diff = player.wantPos - player.pos
    dPos = diff/10
    players[id].pos = player.pos + dPos

    if player.collisions < 3.5
      for obstacle in obstacles
        if Math.abs(player.pos - (obstacle.pos+10)) < 20 && Math.abs(player.speed - (obstacle.speed+10)) < 20
          players[id].collisions += 0.035

    for collectible in collectibles
      if Math.abs(player.pos - (collectible.pos+10)) < 20 && Math.abs(player.speed - (collectible.speed+10)) < 20
        collectible.players.push id

    wantSpeed = 50 - 10 * player.collisions
    diff = wantSpeed - player.speed
    dSpeed = diff/10
    players[id].speed = player.speed + dSpeed
    players[id].collisions -= 0.02 if players[id].collisions > 0

  delAmount = 0
  for obstacle, i in obstacles
    obstacle.speed -= 0.5
    delAmount = i+1 if obstacle.speed < 0
  obstacles.splice 0, delAmount

  collectibles = collectibles.filter (collectible) ->
    if collectible.players.length < 1
      return true
    id = collectible.players[Math.floor(collectible.players.length*Math.random())]
    players[id].points += 1
    players[id].pushPoints = true
    console.log 'player ' + id + ' got a point'
    return false

  delAmount = 0
  for collectible, i in collectibles
    collectible.speed -= 0.5
    delAmount = i+1 if collectible.speed < 0
  collectibles.splice 0, delAmount
  
  if Math.random() > 0.99
    obstacles.push {pos: Math.random()*100, speed: 100, image: Math.floor(obstacleImages.length*Math.random())}

  if Math.random() > 0.99
    collectibles.push {pos: Math.random()*100, speed:100, image: Math.floor(collectibleImages.length*Math.random()), players: []}
, 20
io.sockets.on 'connection', (socket) ->
  console.log 'connection ' + socket.id
  intervals = []
  socket.on 'map', ->
    socket.emit 'images', players
    socket.emit 'obstacleImages', obstacleImages
    socket.emit 'collectibleImages', collectibleImages
    intervals.push setInterval ->
        cleanPlayers = {}
        for id, player of players
            cleanPlayers[id] = {pos: player.pos, speed: player.speed}
        socket.emit 'players', cleanPlayers
        socket.emit 'obstacles', obstacles
        socket.emit 'collectibles', collectibles
    , 20

  socket.on 'pos', (data) ->
    if players.hasOwnProperty socket.id
        players[socket.id].wantPos = data
        if players[socket.id].pushPoints
          players[socket.id].pushPoints = false
          socket.emit 'points', players[socket.id].points
    else
        players[socket.id] = {wantPos: data, pos: data, collisions: 0, speed: 50, image: playerPictures.pop(), points: 0, pushPoints: false}
        console.log 'sending image'
        socket.emit 'image', players[socket.id].image
        socket.broadcast.emit 'images', players

  socket.on 'disconnect', ->
    for interval in intervals
        clearInterval interval
    delete players[socket.id]
    console.log 'disconnection ' + socket.id

console.log 'Server running at *:' + port


