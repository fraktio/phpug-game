assetsUrl = "http://assets.phpug.tunk.io/scifi"

socket = io.connect()
{
    windowWidth: window.innerWidth
    windowHeight: window.innerHeight
    ctx: null
    canvas: null
    obstacles: {}
    collectibles: {}
    players: {}

    '/controller': ->
        accel = 0
        window.ondevicemotion = (e) ->
            accel = ( e.accelerationIncludingGravity.y + 10 ) * 5
            accel = 0 if accel < 0
            accel = 100 if accel > 100

        document.body.innerHTML = '<canvas width="' + @windowWidth / 4 + '" height="' + @windowHeight / 4 + '" style="width: ' + @windowWidth + 'px; height: ' + @windowHeight + 'px;"></canvas>'
        @initializeCanvas()

        image = null
        points = 0
        socket.on 'image', (data) ->
            image = new Image()
            image.src = data
        socket.on 'points', (data) ->
            points = data
        socket.on 'location', (data) ->
            window.location = data
        setInterval ->
            @ctx.clearRect 0, 0, @canvas.width, @canvas.height
            imageScale = @canvas.width / image.width
            @ctx.drawImage image, 0, 0, @canvas.width, imageScale * image.height if image?
            @ctx.fillText 'points: ' + points, 20, 20
            @ctx.beginPath()
            @ctx.moveTo 0, accel / 100 * @canvas.height
            @ctx.lineTo @canvas.width, accel / 100 * @canvas.height
            @ctx.stroke()
        , 33
        setInterval ->
            socket.emit 'ypos', accel
        , 100

    '/map': ->
        $.ajax({
            url: assetsUrl + "/config.json",
            dataType: 'jsonp',
            crossDomain: true,
            jsonpCallback: 'loadConfig',
            success: (data) =>
                @drawMapCanvas(data)
            ,
            error: (data) ->
                console.log('failed to load data');
                console.log(data);
        });
    '/admin': ->
        console.log 'tussi'



    initialize: ->
        @canvas = document.getElementsByTagName('canvas')[0]
        @ctx = @canvas.getContext '2d'

    drawMapCanvas: (assets) ->

        document.body.querySelector('#canvas-container').innerHTML = '<canvas width="' + @windowWidth + '" height="' + @windowHeight + '" style="width: ' + @windowWidth + 'px; height: ' + @windowHeight + 'px;"></canvas>'
        @initialize()

        images = {}
        images = @loadPlayerImages(assets.players)
        socket.on 'players', (data) =>
            @players = data

        socket.on 'obstacles', (data) =>
            @obstacles = data;
            @setImagesToData(@obstacles, assets['obstacles'])

        socket.on 'collectibles', (data) =>
            @collectibles = data;
            @setImagesToData(@collectibles, assets['collectibles'])

        socket.emit 'map', {}
        setInterval =>
            @ctx.clearRect 0, 0, @canvas.width, @canvas.height
            i = 0

            for obstacle in @obstacles
                @drawItem(obstacle)

            for collectible in @collectibles
                @drawItem(collectible)

            for id, player of @players
                i += 1
                @ctx.drawImage images[id], @canvas.width / 100 * player.xpos + 2 * Math.cos( Date.now() / 97 + i ), player.ypos / 100 * ( @canvas.height - images[id].height / 2 ) + 3 * Math.sin( Date.now() / 100 + i ), images[id].width / 2, images[id].height / 2 if images.hasOwnProperty id


    setImagesToData: (data, asset) ->
        for item in data
            image = new Image()
            image.src = assetsUrl + '/' +asset[0].image
            item.image = image
        return data

    drawItem: (item) ->
        @ctx.drawImage item.image,
        @canvas.width / 100 * item.xpos,
        item.ypos / 100 * ( @canvas.height - item.image.height ),
        item.image.width,
        item.image.height


    loadPlayerImages: (players) ->
        images = {}
        for playerImage, id in players
            image = new Image()
            image.src = assetsUrl + '/' +playerImage
            images[id] = image

        return images



}[window.location.pathname]()