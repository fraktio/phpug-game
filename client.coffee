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
        points = 0
        socket.on 'image', (data) ->
            image = new Image()
            image.src = data
        socket.on 'points', (data) ->
          points = data
        setInterval ->
            ctx.clearRect 0, 0, c.width, c.height
            imageScale = c.width / image.width
            ctx.drawImage image, 0, 0, c.width, imageScale * image.height if image?
            ctx.fillText 'points: ' + points, 20, 20
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
        obstacles = []
        obstacleImages = []
        collectibles = []
        collectibleImages = []
        socket.on 'images', (data) ->
            images = {}
            for id, player of data
                image = new Image()
                image.src = player.image
                images[id] = image
        socket.on 'obstacleImages', (data) ->
          obstacleImages = []
          for obstacleImage in data
            image = new Image()
            image.src = obstacleImage
            obstacleImages.push image
        socket.on 'collectibleImages', (data) ->
          collectibleImages = []
          for collectibleImage in data
            image = new Image()
            image.src = collectibleImage
            collectibleImages.push image
        socket.on 'obstacles', (data) ->
          obstacles = data
        socket.on 'players', (data) ->
          players = data
        socket.on 'collectibles', (data) ->
          collectibles = data
        socket.emit 'map', {}
        setInterval ->
            ctx.clearRect 0, 0, c.width, c.height
            i = 0
            for obstacle in obstacles
              image = obstacleImages[obstacle.image]
              ctx.drawImage image, c.width/100*obstacle.speed, obstacle.pos/100*(c.height-image.height), image.width, image.height
            for collectible in collectibles
              image = collectibleImages[collectible.image]
              ctx.drawImage image, c.width/100*collectible.speed, collectible.pos/100*(c.height-image.height), image.width, image.height
            for id, player of players
              i += 1
              ctx.drawImage images[id], c.width/100*player.speed + 2*Math.cos(Date.now()/97+i), player.pos/100*(c.height-images[id].height/2) + 3*Math.sin(Date.now()/100+i), images[id].width/2, images[id].height/2 if images.hasOwnProperty id
        
    '/admin': ->
        console.log 'tussi'
}[window.location.pathname]()

