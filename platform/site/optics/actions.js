({
  clearBackground: {
    paramDefs: {
      "backgroundColor": "black"
    },
    update: function() {
      var canvas = $("#gameCanvas");
      var context = canvas[0].getContext("2d");
 
      // TODO: this shouldn't be necessary here, if a better drawing layer system existed
      context.globalCompositeOperation = 'source-over';

      context.setFillColor(this.params.backgroundColor);
      context.fillRect(0, 0, canvas.prop("width"), canvas.prop("height"));
    }
  },

  drawImage: {
    paramDefs: {
      image: null,
      x: 0,
      y: 0
    },
    update: function() {
      var canvas = $("#gameCanvas");
      var context = canvas[0].getContext("2d");
      context.drawImage(this.params.image, this.params.x, this.params.y);
    }
  },

  group: { 
    doc: "Just to place children under it"
  },

  drawPiece: {
    paramDefs: {
      type: null,
      row: 0,
      col: 0,
      rotation: 0
    },
    update: function() {
      // This could be done by drawImage() if better expressions existed
      var canvas = $("#gameCanvas");
      var context = canvas[0].getContext("2d");
      var x = this.params.col * 53 + 33 + 26;
      var y = this.params.row * 53 + 33 + 26;

      context.save();
      context.translate(x, y);
      // Convert to radians
      context.rotate(this.params.rotation * Math.PI / 180);
      context.drawImage(this.assets[this.params.type], -26, -26);
      context.restore();
    }
  },

  drawSelected: {
    paramDefs: {
      row: 0,
      col: 0
    },
    update: function() {
      // This could be done by drawImage() if better expressions existed
      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.strokeStyle = "yellow"
      context.strokeRect(this.params.col * 53 + 33, this.params.row * 53 + 33, 50, 50);
    }
  },

  calculateLight: {
    paramDefs: {
      "pieces": []
    },
    update: function() {
      var MARGIN = 30;
      var CELL_SIZE = 53;
      var GRID_SIZE = [14, 9];
      var MIRROR_ATTENUATION_FACTOR = 0.7;

      var that = this;

      function isInGrid(point)
      {
        return point[0] >= 0 && point[0] < GRID_SIZE[0] && point[1] >= 0 && point[1] < GRID_SIZE[1];        
      }

      // Attempts to find intersection with the given lines and returns it.
      // Else returns null.
      function findIntersection(origin, dest, lines)
      {
        var intersection = null;
        for(var i = 0; i < lines.length; i++)
        {
          intersection = Line.Segment.create(origin, dest).intersectionWith(Line.Segment.create(lines[i][0], lines[i][1]));
          if(intersection) return intersection.elements.slice(0, 2); // return only 2D part
        }

        return null;
      }

      // Returns an intersection point with walls, or null otherwise
      function intersectsBoundaries(origin, dest)
      {
        var boundaries = 
        [
          [[0, 0], [GRID_SIZE[0], 0]], // top
          [[GRID_SIZE[0], 0], [GRID_SIZE[0], GRID_SIZE[1]]], // right
          [[GRID_SIZE[0], GRID_SIZE[1]], [0, GRID_SIZE[1]]], // bottom
          [[0, GRID_SIZE[1]], [0, 0]] // left
        ];

        return findIntersection(origin, dest, boundaries);
      }

      // Returns an intersection point with walls, or null otherwise
      function intersectsCell(origin, dest, cellPos)
      {
        var boundaries = 
        [
          [[cellPos[0], cellPos[1]], [cellPos[0], cellPos[1] + 1]], // top
          [[cellPos[0], cellPos[1] + 1], [cellPos[0] + 1, cellPos[1] + 1]], // right
          [[cellPos[0] + 1, cellPos[1] + 1], [cellPos[0], cellPos[1] + 1]], // bottom
          [[cellPos[0], cellPos[1] + 1], [cellPos[0], cellPos[1]]] // left
        ];

        return findIntersection(origin, dest, boundaries);
      }

      function findGridElement(point)
      {
        for(var i in that.params.pieces)
        {
          var piece = that.params.pieces[i];
          if(piece.col == Math.floor(point[0]) && piece.row == Math.floor(point[1])) return piece; 
        }
        return null;
      }

      function handleGridElement()
      {
        if(element.type == "wall")
        {
          // find intersection with wall
          lightSegments[lightSegments.length - 1].destination = intersectsCell(lightSegments[lightSegments.length - 1].origin, origin, [element.col, element.row]);

          lightIntensity = 0;
        }
        else if(element.type == "mirror")
        {
          // find intersection with central line
          // HACK: adding 90 degrees to rotation seems to work, but doesn't seem necessary
          var rotation = (element.rotation + 90) * Math.PI / 180; 
          var centralLineDiff = [.5 * Math.cos(rotation), .5 * Math.sin(rotation)];
          var centralLine = [[element.col + 0.5 + centralLineDiff[0], element.row + 0.5 + centralLineDiff[1]], [element.col + 0.5 - centralLineDiff[0], element.row + 0.5 - centralLineDiff[1]]];
          var lineDestination = Vector.create(origin).add(Vector.create(lightDirection));
          if(intersection = findIntersection(lightSegments[lightSegments.length - 1].origin, lineDestination.elements, [centralLine]))
          {
            lightSegments[lightSegments.length - 1].destination = intersection;

            lightIntensity *= MIRROR_ATTENUATION_FACTOR;
            lightSegments.push({ origin: intersection, intensity: lightIntensity });

            // reflect around normal (from http://www.gamedev.net/topic/510581-2d-reflection/)
            // v' = 2 * (v . n) * n - v;
            var normal = Vector.create([-Math.sin(rotation), Math.cos(rotation)]);
            var oldLightDirection = Vector.create(lightDirection);
            lightDirection = normal.multiply(2 * oldLightDirection.dot(normal)).subtract(oldLightDirection).elements;

            updateLightDirection();
          }
        }
      }

      function updateLightDirection()
      {
        d = [Math.abs(lightDirection[0]), Math.abs(lightDirection[1])];
        s = [lightDirection[0] > 0 ? 1 : -1, lightDirection[1] > 0 ? 1 : -1];
        err = d[0] - d[1];
      }

      // all lines are in grid space, not in screen space
      function drawGradientLine(ctx, origin, dest, innerRadius, outerRadius, colorRgba)
      {
        ctx.save();

        var marginV = Vector.create([MARGIN, MARGIN]);

        // find normal to line (http://stackoverflow.com/questions/1243614/how-do-i-calculate-the-normal-vector-of-a-line-segment)
        var originV = Vector.create(origin).multiply(CELL_SIZE).add(marginV);
        var destV = Vector.create(dest).multiply(CELL_SIZE).add(marginV);
        var d = destV.subtract(originV);
        var normal = Vector.create([-d.elements[1], d.elements[0]]).toUnitVector();

        var strokeGradUpper = originV.add(normal.multiply(outerRadius));
        var strokeGradLower = originV.add(normal.multiply(-outerRadius));

        var transRgba = _.clone(colorRgba);
        transRgba[3] = 0;

        var strokeGrad = ctx.createLinearGradient(strokeGradUpper.elements[0], strokeGradUpper.elements[1], strokeGradLower.elements[0], strokeGradLower.elements[1]);
        strokeGrad.addColorStop(0, "rgba(" + transRgba.join(",") + ")");
        strokeGrad.addColorStop(innerRadius / outerRadius, "rgba(" + colorRgba.join(",") + ")");
        strokeGrad.addColorStop(1 - innerRadius / outerRadius, "rgba(" + colorRgba.join(",") + ")");
        strokeGrad.addColorStop(1, "rgba(" + transRgba.join(",") + ")");
        ctx.strokeStyle = strokeGrad;

        ctx.lineWidth = 2 * outerRadius;

        ctx.beginPath();
        ctx.moveTo(originV.elements[0], originV.elements[1]);
        ctx.lineTo(destV.elements[0], destV.elements[1]);
        ctx.stroke();

        // draw end caps
        // TODO: only draw half circles
        var fillGrad = ctx.createRadialGradient(originV.elements[0], originV.elements[1], 0, originV.elements[0], originV.elements[1], outerRadius);
        fillGrad.addColorStop(innerRadius / outerRadius, "rgba(" + colorRgba.join(",") + ")");
        fillGrad.addColorStop(1, "rgba(" + transRgba.join(",") + ")");
        ctx.fillStyle = fillGrad;

        ctx.moveTo(originV.elements[0], originV.elements[1]);
        ctx.arc(originV.elements[0], originV.elements[1], outerRadius, 0, 2 * Math.PI);
        ctx.fill(); 

        ctx.restore();
      }

      // Do everything in the "grid space" and change to graphic coordinates at the end

      // find source of light
      // TODO: this could be replacd by a WHERE bind expression
      var lightSource;
      for(var i in this.params.pieces)
      {
        var piece = this.params.pieces[i];
        if(piece.type == "laser-on") 
        {
          lightSource = piece;
          break;
        }
      }
      if(!lightSource) return;

      // calculate origin coordinates of light 
      // the piece starts vertically, so we rotate it 90 degrees clockwise by default
      var rotation = (lightSource.rotation - 90) * Math.PI / 180; 
      var lightDirection = [Math.cos(rotation), Math.sin(rotation)];
      // TODO: add color portions of light (3 different intensities)
      var lightIntensity = 1.0; // start at full itensity

      // follow light path through the grid, checking for intersections with pieces
      // Based on Bresenham's line algorithm (http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)      
      var d, s, r;
      updateLightDirection();

      var origin = [lightSource.col + .5, lightSource.row + .5]

      var lightSegments = [ { origin: [origin[0], origin[1]], intensity: lightIntensity }];
      var element;
      do
      { 
        var err2 = 2 * err;
        if(err2 > -d[1]) {
          err = err - d[1];
          origin[0] += s[0]
        }
        if(err2 < d[0]) {
          err = err + d[0];
          origin[1] += s[1]
        }

        if(!isInGrid(origin)) 
        {
          lightIntensity = 0;

          // find intersection with boundaries
          lightSegments[lightSegments.length - 1].destination = intersectsBoundaries(lightSegments[lightSegments.length - 1].origin, origin);
        }
        else if(element = findGridElement(origin))
        {
          handleGridElement();
        }
      } while(lightIntensity > 0);

      // DRAW SEGMENTS

      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.save();

      context.globalCompositeOperation = 'destination-out';

      // TODO: use method in fiddle: http://jsfiddle.net/wNYkX/3/

      for(var i = 0; i < lightSegments.length; i++)
      {
        drawGradientLine(context, lightSegments[i].origin, lightSegments[i].destination, 30, 40, [255, 255, 255, lightSegments[i].intensity]);
      }

      context.globalCompositeOperation = 'source-over';

      for(var i = 0; i < lightSegments.length; i++)
      {
        drawGradientLine(context, lightSegments[i].origin, lightSegments[i].destination, 4, 6, [255, 0, 0, lightSegments[i].intensity]);
      }

      context.restore();

      // TODO: move the composition stuff to a dedicated layout function
      context.globalCompositeOperation = 'destination-over';
    }
  }
});