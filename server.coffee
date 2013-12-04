$ = require('jquery').create();

http = require 'http'
fs = require 'fs'

port = parseInt process.argv[2], 10

server = http.createServer (req, res) ->
    res.writeHead 200, {'Content-Type': 'text/html'}
    fs.readFile 'client.coffee', (err, data) ->
        if err?
            return res.end 'reading client script failed'
        res.end '<html><head><script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script><link href="http://assets.phpug.tunk.io/scifi/css/styles.css" media="all" rel="stylesheet" type="text/css"><meta name="viewport" content="user-scalable=no, width=device-width" /><script src="/socket.io/socket.io.js"></script>' +
            '<script src="http://coffeescript.org/extras/coffee-script.js"></script>' +
            '<script type="text/coffeescript">' + data + '</script></head><body><div id="background"></div><div id="midground"></div><div id="foreground"></div><div id="canvas-container"></div></div></body></html>'



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

program = {
    assetsUrl: "http://assets.phpug.tunk.io/scifi"
    players:  {}
    obstacles:  []
    collectibles:  []

    initialize: ->
        $.ajax({
            url: @assetsUrl + "/config.json",
            dataType: 'jsonp',
            crossDomain: true,
            jsonpCallback: 'loadConfig',
            success: (data) =>
                @sockets()
                @runServer(data)
            ,
            error: (data) ->
                console.log('failed to load data');
                console.log(data);
          });

    runServer: (assets) ->
        setInterval =>
            for id, player of @players

                diff = player.wantPos - player.ypos

                dPos = diff/10
                @players[id].ypos = player.ypos + dPos

                if player.collisions < 3.5
                    for obstacle in @obstacles
                        if Math.abs(player.ypos - (obstacle.ypos+10)) < 20 && Math.abs(player.xpos - (obstacle.xpos+10)) < 20
                            @players[id].collisions += 0.035

                for collectible in @collectibles
                    if Math.abs(player.ypos - (collectible.ypos+10)) < 20 && Math.abs(player.xpos - (collectible.xpos+10)) < 20
                      collectible.players.push id

                wantXpos = 50 - 10 * player.collisions
                diff = wantXpos - player.xpos
                dXpos = diff/10
                @players[id].xpos = player.xpos + dXpos
                @players[id].collisions -= 0.02 if @players[id].collisions > 0


            delAmount = 0
            for obstacle, i in @obstacles
                obstacle.xpos -= obstacle.speed
                delAmount = i+1 if (obstacle.xpos + 25) < 0
            @obstacles.splice 0, delAmount


            @collectibles = @collectibles.filter (collectible) =>
                if collectible.players.length < 1
                   return true
                id = collectible.players[Math.floor(collectible.players.length*Math.random())]
                @players[id].points += 1
                @players[id].pushPoints = true
                console.log 'player ' + id + ' got a point'
                return false


            delAmount = 0
            for collectible, i in @collectibles
                collectible.xpos -= collectible.speed
                delAmount = i+1 if (collectible.xpos + 25) < 0
            @collectibles.splice 0, delAmount


            if Math.random() > 0.995
                index = Math.floor(assets.obstacles.length * Math.random())
                item = assets.obstacles[index];

                @obstacles.push {
                    ypos: Math.random() * 100,
                    xpos: 100,
                    speed: @randomizeFromTo( item.min_speed, item.max_speed ) / 100,
                    index: index
                }

            if Math.random() > 0.995
                index = Math.floor(assets.collectibles.length * Math.random())

                item = assets.collectibles[index];

                @collectibles.push {
                    ypos: Math.random() * 100,
                    xpos: 100,
                    speed: @randomizeFromTo( item.min_speed, item.max_speed ) / 100,
                    index: index
                    players: []
                }

        , 20



    randomizeFromTo: (from, to) ->
        return Math.floor( Math.random() * (to - from + 1 )+ from )

    sockets: ->

        io.sockets.on 'connection', (socket) =>
            console.log 'connection ' + socket.id
            intervals = []
            socket.on 'map', =>
                socket.emit 'images', @players
                intervals.push setInterval =>
                    cleanPlayers = {}
                    for id, player of @players
                        cleanPlayers[id] = {ypos: player.ypos, xpos: player.xpos}
                    socket.emit 'players', cleanPlayers
                    socket.emit 'obstacles', @obstacles
                    socket.emit 'collectibles', @collectibles
                , 20

            socket.on 'ypos', (data) =>
                if @players.hasOwnProperty socket.id
                    @players[socket.id].wantYPos = data
                    if @players[socket.id].pushPoints
                        @players[socket.id].pushPoints = false
                        socket.emit 'points', @players[socket.id].points
                        if @players[socket.id].points > 21
                            socket.emit 'location', 'http://herpderp.fi/winner'
                            console.log 'a winner was found'
                            setTimeout ->
                               process.exit 0
                            , 10000

                else
                    @players[socket.id] = {wantYPos: data, ypos: data, collisions: 0, xpos: 50, image: playerPictures.pop(), points: 0, pushPoints: false}
                    console.log 'sending image'
                    socket.emit 'image', @players[socket.id].image
                    socket.broadcast.emit 'images', @players

            socket.on 'disconnect', =>
                for interval in intervals
                    clearInterval interval
                delete @players[socket.id]
                console.log 'disconnection ' + socket.id

}

console.log 'Server running at *:' + port
program.initialize()



