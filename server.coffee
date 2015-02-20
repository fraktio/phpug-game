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
    config: {}
    players:  {}
    obstacles: []
    collectibles: []



    initialize: ->
        $.ajax({
            url: @assetsUrl + "/config.json",
            dataType: 'jsonp',
            crossDomain: true,
            jsonpCallback: 'loadConfig',
            success: (data) =>
                @sockets()
                @config = data
                @runServer()
            ,
            error: (data) ->
                console.log('failed to load data');
                console.log(data);
          });

    runServer: () ->
        setInterval =>

            for id, player of @players


                diff = player.wantpos.Y - player.pos.Y

                dPos = diff/10
                @players[id].pos.Y = player.pos.Y + dPos

                if player.collisions < 3.5
                    for obstacle in @obstacles
                        if Math.abs(player.pos.Y - (obstacle.pos.Y+10)) < 20 && Math.abs(player.pos.X - (obstacle.pos.X+10)) < 20
                            @players[id].collisions += 0.035

                for collectible in @collectibles
                    if Math.abs(player.pos.Y - (collectible.pos.Y+10)) < 20 && Math.abs(player.pos.X - (collectible.pos.X+10)) < 20
                      collectible.players.push id

                wantposX = 50 - 10 * player.collisions
                diff = wantposX - player.pos.X
                dposX = diff/10
                @players[id].pos.X = player.pos.X + dposX
                @players[id].collisions -= 0.02 if @players[id].collisions > 0


            @collectibles = @collectibles.filter (collectible) =>
                if collectible.players.length < 1
                   return true
                id = collectible.players[Math.floor(collectible.players.length*Math.random())]
                @players[id].points += 1
                @players[id].pushPoints = true
                console.log 'player ' + id + ' got a point'
                return false


            @moveObjects(@collectibles)
            @moveObjects(@obstacles)

            if Math.random() > 0.9 && @obstacles.length < @config.max_obstacles
                index = Math.floor(@config.obstacles.length * Math.random())
                item = @config.obstacles[index];

                @obstacles.push {
                    radius: item.radius,
                    pos:
                        Y: Math.random() * 100,
                        X: 100,
                    angle: Math.random() * (item.max_angle - item.min_angle + 1 )+ item.min_angle,
                    speed: @randomizeFromTo( item.min_speed, item.max_speed ) / 100,
                    index: index
                }

            if Math.random() > 0.995 && @collectibles.length < @config.max_collectibles
                index = Math.floor(@config.collectibles.length * Math.random())

                item = @config.collectibles[index];

                @collectibles.push {
                    radius: item.radius,
                    pos:
                        Y: Math.random() * 100,
                        X: 100,
                    angle: Math.random() * (item.max_angle - item.min_angle + 1 )+ item.min_angle,
                    speed: @randomizeFromTo( item.min_speed, item.max_speed ) / 100,
                    index: index
                    players: []
                }
        , 20

    moveObjects: (objects) ->
        for object, i in objects.slice(0)
            if (object.pos.X + 25) < 0 || (object.pos.X > 110) || (object.pos.Y > 110) || (object.pos.Y < -10)  ##out of bounds?
                objects.splice i, 1
            else
                @checkCollision(object)
                object.pos.X = object.pos.X - (Math.cos(object.angle) * object.speed)
                object.pos.Y = object.pos.Y + (Math.sin(object.angle) * object.speed)

    checkCollision: (currentObject) ->
        for object, i in @obstacles
            if (currentObject != object)
                if (@circleCircleCollision(object, currentObject))
                    @calculateCollisionEffect(object, currentObject)
                    return

    circleCircleCollision: (object1, object2) ->
        distX = object1.pos.X - object2.pos.X
        distY = object1.pos.Y - object2.pos.Y
        squaredist = (distX * distX) + (distY * distY)
        return squaredist <= (object1.radius + object1.radius) * (object1.radius + object2.radius)

    calculateCollisionEffect: (object1, object2) ->
        if(object1.pos.X < object2.pos.X )
            frontObject = object1
            backObject = object2
        else
            frontObject = object2
            backObject = object1

        frontObject.speed = frontObject.speed + backObject.speed * 0.5
        frontObject.angle = frontObject.angle * -1
        backObject.speed = backObject.speed * 0.5
        backObject.angle = backObject.angle * -1


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
                        cleanPlayers[id] = {
                            pos:
                                Y: player.pos.Y,
                                X: player.pos.X
                        }
                    socket.emit 'players', cleanPlayers
                    socket.emit 'obstacles', @obstacles
                    socket.emit 'collectibles', @collectibles
                , 20

            socket.on 'pos.Y', (data) =>
                if @players.hasOwnProperty socket.id
                    @players[socket.id].wantpos.Y = data
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

                    playerIndex = Math.floor(@config.players.length * Math.random())

                    @players[socket.id] = {
                        wantpos:
                            Y: data,
                            X: 0,
                        pos:
                            Y: data,
                            X: 50,
                        collisions: 0,
                        image:  @config.players[playerIndex].image,
                        points: 0,
                        pushPoints: false
                    }
                    console.log 'sending image'


                    console.log @players[socket.id].image

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



