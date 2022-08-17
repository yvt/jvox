### 
JVox Experimental Voxel Renderer

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
Utils =
	normalize2DArray: (x, y) ->
		sq = 1 / Math.sqrt(x * x + y * y)
		[x * sq, y * sq]

class VoxelField

	# Data is given as TypedArray or ARrayBuffer.
	constructor: (data, @width, @height) ->
		@data = new Uint8Array data

		# Create column index
		@addrIndex = []
		index = 0; d = @data
		for y in [0 .. @height - 1] by 1
			for x in [0 .. @width - 1] by 1
				@addrIndex.push index
				while d[index] != 0
					index += d[index] * 4
				index += (d[index + 2] - d[index + 1] + 2) << 2
		return

	getAddressForColumn: (x, y) ->
		return -1 if x < 0 or y < 0 or x >= @width or y >= @height
		@addrIndex[x + y * @width]

class PerspectiveCamera
	constructor: () ->
		@fovX = 90 * Math.PI / 180
		@fovY = 50 * Math.PI / 180
		@eye = {x: 0, y: 0, z: 0}
		@target = {x: 1, y: 1, z: 1}
		return

	renderColumnsForPseudoThreeD: (width, height, callback) ->
		frontX = @target.x - @eye.x
		frontY = @target.y - @eye.y
		[frontX, frontY] = Utils.normalize2DArray frontX, frontY
		sideX = frontY
		sideY = -frontX

		# Prepare to compute ray vector
		fovX = Math.tan(@fovX * 0.5)

		sideX *= fovX; sideY *= fovX

		dx = frontX - sideX
		dy = frontY - sideY
		ddx = sideX * 2 / width
		ddy = sideY * 2 / width

		# Prepare to computer Y screen coord
		fovY = Math.tan(@fovY * 0.5)
		eyeX = @eye.x
		eyeY = @eye.y
		eyeZ = @eye.z
		zScale = height / (fovY * 2)
		midY = height * 0.5
		offs = eyeX * frontX + eyeY * frontY - 0.00001
		yProjector = (x, y, z) ->
			viewZ = x * frontX + y * frontY - offs
			return (z - eyeZ) * zScale / viewZ + midY

		for x in [0 .. width - 1] by 1
			[ndx, ndy] = Utils.normalize2DArray dx, dy
			callback eyeX, eyeY, ndx, ndy, x, yProjector
			dx += ddx; dy += ddy
		return



class PseudoThreeDRenderer

	constructor: (@field, @width, @height) ->
		@width = @width | 0
		@height = @height | 0
		return

	renderColumn: (pixels, x, y, dx, dy, drawX, proj) ->
		drawW = @width; drawH = @height
		field = @field; fdata = field.data

		# Avoid denormals
		dx += 0.00001 if Math.abs(dx) < 0.0000001
		dy += 0.00001 if Math.abs(dy) < 0.0000001
		invDx = 1 / dx; invDy = 1 / dy

		ix = Math.floor x; iy = Math.floor y

		#invalidLastY = 114514
		#lastYs = (invalidLastY for _ in [0 .. 64])

		fill = (y1, y2, r, g, b) ->
			return if y1 >= y2
			y1 = 0 if y1 < 0
			y2 = drawH if y2 > drawH
			return if y1 >= drawH
			return if y2 <= 0
			y1 |= 0; y2 |= 0 # Rounding
			ind = drawX + y1 * drawW
			clr = b | (g << 8) | (r << 16) | 0xff000000
			for yy in [y1 .. y2 - 1] by 1
				if pixels[ind] == 0
					pixels[ind] = clr
				ind += drawW
			return

		for haltCheck in [0 .. 63]
			# Boundary test.
			if (if dx >= 0 then x >= field.width else x <= 0) or
			(if dy >= 0 then y >= field.height else y <= 0)
				return

			timeToNextX = (if dx >= 0 then ix + 1 - x else ix - x) * invDx
			timeToNextY = (if dy >= 0 then iy + 1 - y else iy - y) * invDy

			if timeToNextX < timeToNextY
				# X move
				time = timeToNextX

				nix = if dx >= 0 then ix + 1 else ix - 1
				niy = iy
				nx = if dx >= 0 then nix else ix
				ny = y + dy * time
			else
				# Y move
				time = timeToNextY

				nix = ix
				niy = if dy >= 0 then iy + 1 else iy - 1
				nx = x + dx * time
				ny = if dy >= 0 then niy else iy

			# Floor / Ceiling
			index = field.getAddressForColumn ix, iy
			if index >= 0
				loop
					numChunks = fdata[index]
					topColorStart = fdata[index + 1]
					topColorEnd = fdata[index + 2]
					z = topColorStart
					y1 = proj(nx, ny, z)
					y2 = proj(x, y, z)
					fill y1, y2, fdata[index + 4], fdata[index + 5], fdata[index + 6]
					
					break if numChunks == 0

					lenBottom = topColorEnd - topColorStart + 1
					lenTop = numChunks - 1 - lenBottom
					bottomColorEnd = fdata[index + numChunks * 4 + 3]
					bottomColorStart = bottomColorEnd - lenTop


					if bottomColorStart < bottomColorEnd
						index += numChunks * 4 - 4
						z = bottomColorEnd
						y1 = proj(x, y, z)
						y2 = proj(nx, ny, z)
						fill y1, y2, fdata[index], fdata[index + 1], fdata[index + 2]
						index += 4
					else
						z = topColorEnd + 1
						y2 = proj(nx, ny, z)
						y1 = proj(x, y, z)
						fill y1, y2, fdata[index + 4], fdata[index + 5], fdata[index + 6]
						index += numChunks * 4



			ix = nix; iy = niy
			x = nx; y = ny

			# Walls
			index = field.getAddressForColumn ix, iy
			if index >= 0
				loop
					numChunks = fdata[index]
					topColorStart = fdata[index + 1]
					topColorEnd = fdata[index + 2]
					colorIndex = index + 4

					y2 = proj(x, y, topColorStart)
					for z in [topColorStart .. topColorEnd] by 1
						y1 = y2
						y2 = proj(x, y, z + 1)
						fill y1, y2, 
						fdata[colorIndex] >> 1, fdata[colorIndex + 1] >> 1, fdata[colorIndex + 2] >> 1
						colorIndex += 4

					break if numChunks == 0

					index += numChunks * 4

					lenBottom = topColorEnd - topColorStart + 1
					lenTop = numChunks - 1 - lenBottom
					bottomColorEnd = fdata[index + 3]
					bottomColorStart = bottomColorEnd - lenTop

					if bottomColorEnd > bottomColorStart
						y2 = proj(x, y, bottomColorStart)
						for z in [bottomColorStart .. bottomColorEnd - 1] by 1
							y1 = y2
							y2 = proj(x, y, z + 1)
							fill y1, y2, 
							fdata[colorIndex] >> 1, fdata[colorIndex + 1] >> 1, fdata[colorIndex + 2] >> 1
							colorIndex += 4

		return

	render: (pixels, camera) ->
		# Fill with transparent
		for i in [0 .. @width * @height - 1] by 1
			pixels[i] = 0
		# Render
		camera.renderColumnsForPseudoThreeD @width, @height, 
		(x, y, dx, dy, drawX, proj) =>
			@renderColumn pixels, x, y, dx, dy, drawX, proj
			return
		return

# Optimize PseudoThreeDRenderer
do ->
	source = PseudoThreeDRenderer.prototype.renderColumn.toString()
	parts = source.split /fill\((.*?)\);/

	for i in [1 .. parts.length - 1] by 2
		arg = parts[i]
		args = arg.split ","
		newPart = "var clr, ind, yy, y1, y2;"
		newPart += "y1 = #{args[0]};"
		newPart += "y2 = #{args[1]};"
		newPart += "if (y1 < 0) y1 = 0;"
		newPart += "if (y2 > drawH) y2 = drawH;"
		newPart += "if (y1 < drawH && y2 > 0) {"
		newPart += "y1 |= 0; y2 |= 0;"
		newPart += "ind = drawX + y1 * drawW | 0;"
		newPart += "clr = 255 - (haltCheck << 2);";
		newPart += "clr = (#{args[4]}) | ((#{args[3]}) << 8) | ((#{args[2]}) << 16) | (clr << 24);"
		newPart += "for (yy = y1; yy < y2; yy = (yy + 1) | 0) {"
		newPart += "if (pixels[ind] === 0) pixels[ind] = clr;"
		newPart += "ind = (ind + drawW) | 0;"
		newPart += "}}"
		parts[i] = newPart;

	newSource = parts.join ""
	# console.log newSource
	PseudoThreeDRenderer.prototype.renderColumn = eval "(#{newSource})"

window.JVox =
	VoxelField: VoxelField
	PerspectiveCamera: PerspectiveCamera
	PseudoThreeDRenderer: PseudoThreeDRenderer





