socket = io.connect()

{
    '/controller': ->
        accel = 0
        window.ondevicemotion = (e) ->
            accel = (e.accelerationIncludingGravity.y + 10)*5
            accel = 0 if accel < 0
            accel = 100 if accel > 100
        w = window.innerWidth
        h = window.innerHeight

        document.body.innerHTML = '<canvas width="' + w/4 + '" height="' + h/4 + '" style="width: ' + w + 'px; height: ' + h + 'px;"></canvas>'
        c = document.getElementsByTagName('canvas')[0]
        ctx = c.getContext '2d'
        image = null
        socket.on 'image', (data) ->
            image = new Image()
            image.src = data
        setInterval ->
            ctx.clearRect 0, 0, c.width, c.height
            ctx.drawImage image, 0, 0, image.width/4, image.height/4 if image?
            ctx.beginPath()
            ctx.moveTo 0, accel/100*c.height
            ctx.lineTo c.width, accel/100*c.height
            ctx.stroke()
        , 33
        setInterval ->
            socket.emit 'pos', accel
        , 100
    '/map': ->
        w = window.innerWidth
        h = window.innerHeight
        document.body.innerHTML = '<canvas width="' + w + '" height="' + h + '" style="width: ' + w + 'px; height: ' + h + 'px;"></canvas>'
        c = document.getElementsByTagName('canvas')[0]
        ctx = c.getContext '2d'
        players = {}
        images = {}
        socket.on 'images', (data) ->
            images = {}
            for id, player of data
                image = new Image()
                image.src = player.image
                images[id] = image
        socket.on 'players', (data) ->
            players = data
        socket.emit 'map', {}
        setInterval ->
            ctx.clearRect 0, 0, c.width, c.height
            for id, player of players
                ctx.drawImage images[id], 0, player.pos/100*(c.height-images[id].height/2), images[id].width/2, images[id].height/2 if images.hasOwnProperty id
        , 33
        
    '/admin': ->
        console.log 'tussi'
}[window.location.pathname]()

