### 
JVox Demo Program

----
The MIT License (MIT)

Copyright (c) 2014 yvt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

class CanvasImaging
	constructor: ->
		@pool = []
	getCanvas: (width, height) ->
		for c,idx in @pool when c.width == width && c.height == height
			@pool.splice idx, 1
			return c

		c = document.createElement 'canvas'
		c.width = width
		c.height = height
		return c
	returnCanvas: (canvas) ->
		@pool.push canvas
		return
	makeOpaque: (canvas, fillStyle) ->
		width = canvas.width
		height = canvas.height
		newCanvas = @getCanvas width, height
		ctx = newCanvas.getContext '2d'
		ctx.fillStyle = fillStyle
		ctx.fillRect 0, 0, width, height
		ctx.drawImage canvas, 0, 0
		return newCanvas

	shrinkHalf: (canvas) ->
		width = canvas.width
		height= canvas.height
		newWidth = (canvas.width + 1) >> 1
		newHeight = (canvas.height + 1) >> 1
		newCanvas = @getCanvas newWidth, newHeight
		ctx = newCanvas.getContext '2d'
		ctx.drawImage canvas, 0, 0, width, height, 0, 0, newWidth, newHeight
		ctx.globalAlpha = 1 / 2
		ctx.drawImage canvas, 1, 0, width, height, 0, 0, newWidth, newHeight
		ctx.globalAlpha = 1 / 3
		ctx.drawImage canvas, 0, 1, width, height, 0, 0, newWidth, newHeight
		ctx.globalAlpha = 1 / 4
		ctx.drawImage canvas, 1, 1, width, height, 0, 0, newWidth, newHeight
		ctx.globalAlpha = 1
		return newCanvas

	convolute1D: (canvas, kernel, center, vertical) ->
		width = canvas.width
		height = canvas.height
		newCanvas = @getCanvas width, height
		ctx = newCanvas.getContext '2d'
		i = -center
		sum = 0
		for vl in kernel
			sum += vl
			ctx.globalAlpha = vl / sum
			if vertical
				ctx.drawImage canvas, 0, i
			else
				ctx.drawImage canvas, i, 0
			++i
		ctx.globalAlpha = 1
		return newCanvas




$ ->
	canvas = $ '#canvas'

	context = canvas[0].getContext '2d'
	canvasWidth = canvas[0].width
	canvasHeight = canvas[0].height
	imgData = context.getImageData 0, 0, canvasWidth, canvasHeight
	backBuffer = new ArrayBuffer canvasWidth * canvasHeight * 4
	backBuffer32 = new Int32Array backBuffer
	backBuffer8 = new Uint8Array backBuffer

	imaging = new CanvasImaging

	field = null
	renderer = null

	cameraAngle = 0
	eyePos = {x: 326, y: 256, z: 55.2}

	getTime = -> new Date().getTime()
	lastFrameTime = getTime()

	startTime = null

	frameNext = ->
		t = getTime()
		dt = Math.min(t - lastFrameTime, 100) / 1000
		if renderer?
			per = 1 - Math.pow(0.2, dt)
			mouseXSmoothed += (mouseX - mouseXSmoothed) * per
			mouseYSmoothed += (mouseY - mouseYSmoothed) * per

			vel = -mouseYSmoothed * dt * 40
			eyePos.x += Math.sin(cameraAngle) * vel
			eyePos.y += Math.cos(cameraAngle) * vel
			cameraAngle -= mouseXSmoothed * dt * 3
			eyePos.x = Math.max(Math.min(eyePos.x, 512-16), 16)
			eyePos.y = Math.max(Math.min(eyePos.y, 512-16), 16)
		else
			if loadProgress?
				per = 1 - Math.pow(0.02, dt)
				loadProgressSmoothed += (loadProgress - loadProgressSmoothed) * per
		lastFrameTime = t


	render = ->
		frameNext()
		winWidth = $(window).width()
		winHeight = $(window).height()

		if renderer?
			canvasActualWidth = winWidth * 1.3
			canvasActualHeight = winHeight * 1.3

			camera = new JVox.PerspectiveCamera
			camera.fovX = -80 * Math.PI / 180
			ratio = canvasActualHeight / canvasActualWidth
			camera.fovY = Math.atan(Math.tan(camera.fovX * -0.5) * ratio) * 2;

			camera.eye = {x: eyePos.x, y: eyePos.y, z: eyePos.z}
			camera.target = {x: 280, y: 350, z: 44.2}
			camera.eye.z += mouseYSmoothed * -0.2

			camera.target.x = camera.eye.x + Math.sin(cameraAngle)
			camera.target.y = camera.eye.y + Math.cos(cameraAngle)

			renderer.render backBuffer32, camera
			imgData.data.set backBuffer8, 0
			context.putImageData imgData, 0, 0

			if false
				opq = imaging.makeOpaque canvas[0], map.fogColor
				half1 = imaging.shrinkHalf opq
				imaging.returnCanvas opq
				half2 = imaging.shrinkHalf half1
				imaging.returnCanvas half1
				half3 = imaging.shrinkHalf half2
				imaging.returnCanvas half2

				gaussianKernel = [
					0.09242116269661459
					0.24137602468441252
					0.33240562523794576
					0.24137602468441252
					0.09242116269661459
				]

				gauss1 = imaging.convolute1D half3, gaussianKernel, 2, false
				imaging.returnCanvas half3

				gauss2 = imaging.convolute1D gauss1, gaussianKernel, 2, true
				imaging.returnCanvas half1

				context.globalAlpha = map.bloomAlpha
				context.globalCompositeOperation = map.bloom
				context.drawImage gauss2, 0, 0, canvasWidth, canvasHeight
				context.globalAlpha = 1
				context.globalCompositeOperation = 'source-over'
				imaging.returnCanvas gauss2

			t = (getTime() - startTime) / 2000
			if t < 1
				context.fillStyle = "rgba(0,0,0,#{1-t})"
				context.fillRect 0, 0, canvasWidth, canvasHeight

			# canvas.css 'transform', "rotate(#{mouseXSmoothed*-5}deg)"
			canvas.css 
				left: -canvasWidth * 0.5, top: -canvasHeight * 0.5
				translate: "#{winWidth*0.5},#{winHeight*0.5}"
				scale: "#{canvasActualWidth/canvasWidth},#{canvasActualHeight/canvasHeight}"
				perspective: '1000px'
				rotate: -mouseXSmoothed * 10
				rotateX: mouseYSmoothed * 20,
		else
			# Not yet loaded
			context.fillStyle = "black"
			context.fillRect 0, 0, canvasWidth, canvasHeight

			prgW = 200; prgH = 3
			prgX = (canvasWidth - prgW) >> 1
			prgY = (canvasHeight - prgH) >> 1

			context.fillStyle = '#333333'
			context.fillRect prgX, prgY, prgW, prgH
			if loadProgress?
				context.fillStyle = '#777777'
				context.fillRect prgX, prgY, prgW * loadProgressSmoothed, prgH
			else
				t = getTime() / 1000
				spread = 50
				center = (t - Math.floor(t)) * (prgW + spread * 2) * 4 - spread
				for x in [0 .. prgW - 2] by 2
					alp = (spread - Math.abs(x - center)) / spread
					if alp >= 0
						context.fillStyle = "rgba(120,120,120,#{alp})"
						context.fillRect prgX + x, prgY, 2, prgH

			canvas.css
				left: (winWidth - canvasWidth) / 2,
				top: (winHeight - canvasHeight) / 2
			return

	# Mouse input
	mouseX = 0; mouseY = 0
	mouseXSmoothed = 0; mouseYSmoothed = 0
	$('#inputView').mousemove (e) ->
		pageW = $(window).width()
		pageH = $(window).height()
		mouseX = (e.pageX / pageW) - 0.5
		mouseY = (e.pageY / pageH) - 0.5
		return
	$('#inputView').mouseout (e) ->
		mouseX = mouseY = 0
		return
	$(window).blur (e) ->
		mouseX = mouseY = 0
		return

	# Touch input support
	currentTouch = null
	touchStartX = null
	touchStartY = null
	$('html').bind 'touchstart', (e) ->
		evt = e.originalEvent
		evt.preventDefault()
		return if currentTouch?
		currentTouch = evt.changedTouches[0].identifier
		touchStartX = evt.changedTouches[0].pageX
		touchStartY = evt.changedTouches[0].pageY
		mouseX = 0; mouseY = 0
		return
	$('html').bind 'touchmove', (e) ->
		evt = e.originalEvent
		evt.preventDefault()
		if currentTouch?
			for touch in evt.touches when touch.identifier == currentTouch
				dx = touch.pageX - touchStartX
				dy = touch.pageY - touchStartY
				dx /= 100; dy /= 100
				sq = Math.sqrt(dx * dx + dy * dy)
				if sq > 1
					dx /= sq; dy /= sq
				else
					dx *= sq; dy *= sq

				mouseX = dx; mouseY = dy

		return
	$('html').bind 'touchend', (e) ->
		evt = e.originalEvent
		evt.preventDefault()
		if currentTouch?
			for touch in evt.changedTouches when touch.identifier == currentTouch
				mouseX = 0; mouseY = 0
				currentTouch = null
		return
	$('html').bind 'touchcancel', (e) ->
		evt = e.originalEvent
		evt.preventDefault()
		if currentTouch?
			for touch in evt.changedTouches when touch.identifier == currentTouch
				mouseX = 0; mouseY = 0
				currentTouch = null
		return

	loadProgress = null
	loadProgressSmoothed = 0

	maps =
		metropolis:
			url: "Metropolis.vxl"
			message: '"Metropolis" by Ki11aWi11'
			fogColor: '#a0a8b8'
			z: 55.2
			bloom: 'source-over'
			bloomAlpha: 0.3
		spitfire:
			url: "spitfire.vxl"
			message: '"Spitfire" by Lostmotel'
			fogColor: '#304070'
			z: 49.2
			bloom: 'lighter'
			bloomAlpha: 0.3
		mesa:
			url: "mesa.vxl"
			message: '"Mesa" by Triplefox'
			fogColor: '#90c0f0'
			z: 38.2
			bloom: 'lighter'
			bloomAlpha: 0.2

	map = maps["metropolis"]

	# Specify map by query
	result = String(window.location).match /\?([a-z]*)/
	if result? and maps[result[1]]?
		map = maps[result[1]]

	xhr = new XMLHttpRequest()
	xhr.open 'GET', map.url, true
	xhr.responseType = 'arraybuffer';
	$('#copyView').text map.message
	$('#canvas').css 'background-color', map.fogColor
	eyePos.z = map.z
	xhr.onprogress = (e) ->
		if e.lengthComputable
			loadProgress = e.loaded / e.total
		else
			loadProgress = null
		return

	xhr.onload = (e) ->
		data = @response
		if not data?
			alert "Invalid data."
			return

		setTimeout (->
			startMap data
		), 1000

		return

	startMap = (data) ->
		field = new JVox.VoxelField data, 512, 512
		renderer = new JVox.PseudoThreeDRenderer field, canvasWidth, canvasHeight
		$('#copyView').delay(2000).fadeTo(1000, 1);
		startTime = getTime()
		return

	setInterval render, 0

	xhr.send()

	return
