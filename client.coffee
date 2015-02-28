assetsUrl = "http://assets.phpug.tunk.io/scifi"

class mapCanvas

    windowWidth: window.innerWidth
    windowHeight: window.innerHeight
    ctx: null
    canvas: null
    obstacles: {}
    collectibles: {}
    players: {}

    drawMapCanvas: (config) ->
        document.body.querySelector('#canvas-container').innerHTML = '<canvas width="' + @windowWidth + '" height="' + @windowHeight + '" style="width: ' + @windowWidth + 'px; height: ' + @windowHeight + 'px;"></canvas>'
        @initialize()

        playerImages = {}
        playerImages = @loadPlayerImages(config.players)

        socket.on 'players', (data) =>
           @players = data

        socket.on 'obstacles', (data) =>
            @obstacles = data;
            @setImagesToData(@obstacles, config['obstacles'])

        socket.on 'collectibles', (data) =>
            @collectibles = data;
            @setImagesToData(@collectibles, config['collectibles'])

        socket.emit 'map', {}
        setInterval =>
            @ctx.clearRect 0, 0, @canvas.width, @canvas.height
            i = 0

            for obstacle in @obstacles
               @drawItem(obstacle)

            for collectible in @collectibles
               @drawItem(collectible)

            for id, player of @players
                id = 0    #TODO: id does not work yet
                @ctx.drawImage playerImages[id], @canvas.width / 100 * player.pos.X , @canvas.height / 100 * player.pos.Y, playerImages[id].width / 2, playerImages[id].height / 2 if playerImages.hasOwnProperty id
                i += 1

    initialize: ->
        @canvas = document.getElementsByTagName('canvas')[0]
        @ctx = @canvas.getContext '2d'

    setImagesToData: (data, config) ->
        for item in data
            image = new Image()
            image.src = assetsUrl + '/' +config[item.index].image
            item.image = image
        return data

    drawItem: (item) ->
        if (item.width) then width = item.width else width = item.image.width
        if (item.height) then height = item.height else height = item.image.height
        @ctx.drawImage item.image,
            @canvas.width / 100 * item.pos.X,
            item.pos.Y / 100 * ( @canvas.height - height ),
            width,
            height

    loadPlayerImages: (players) ->
        images = {}
        for playerImage, id in players
            image = new Image()
            image.src = assetsUrl + '/' +playerImage.image
            images[id] = image
        return images


class controller

    windowWidth: window.innerWidth
    windowHeight: window.innerHeight
    acceleration: {
        y : 0,
        x: 0
    }
    canvas: null
    ctx: null

    initialize: ->
        @drawControllerCanvas
        window.ondevicemotion = (e) =>
            @acceleration.y = ( e.accelerationIncludingGravity.y * -1)
            @acceleration.y = -100 if @acceleration.y < -100
            @acceleration.y = 100 if @acceleration.y > 100

            @acceleration.x = ( e.accelerationIncludingGravity.x * -1)
            @acceleration.x = -100 if @acceleration.x < -100
            @acceleration.x = 100 if @acceleration.x > 100

        document.body.innerHTML = '<canvas width="' + @windowWidth / 4 + '" height="' + @windowHeight / 4 + '" style="width: ' + @windowWidth + 'px; height: ' + @windowHeight + 'px;"></canvas>'
        @canvas = document.getElementsByTagName('canvas')[0]
        @ctx = @canvas.getContext '2d'

        image = null
        points = 0
        socket.on 'image', (src) ->
            image = new Image()
            image.src = assetsUrl + '/' + src

        socket.on 'points', (data) ->
            points = data

        socket.on 'location', (data) ->
            window.location = data

        setInterval =>
            @ctx.clearRect 0, 0, @canvas.width, @canvas.height

            imageScale = @canvas.width / image.width
            @ctx.drawImage image, 0, 0, @canvas.width, imageScale * image.height if image?
            @ctx.fillText 'points: ' + points, 20, 20
            @ctx.beginPath()

         #   @ctx.moveTo @acceleration.x / 100 * @canvas.width, @acceleration.y / 100 * @canvas.height
         #   @ctx.lineTo @acceleration.x / 100 * @canvas.width, @acceleration.y / 100 * @canvas.height

            @ctx.stroke()
        , 33

        setInterval =>
            socket.emit 'acceleration', @acceleration
        , 100




socket = io.connect()
{
    '/controller': ->
        controller = new controller
        controller.initialize()

    '/map': ->
        $.ajax({
            url: assetsUrl + "/config.json",
            dataType: 'jsonp',
            crossDomain: true,
            jsonpCallback: 'loadConfig',
            success: (data) =>
                mapCanvas = new mapCanvas
                mapCanvas.drawMapCanvas(data)
            ,
            error: (data) ->
                console.log('failed to load data');
                console.log(data);
        });
    '/admin': ->
        console.log 'tussi'


}[window.location.pathname]()

