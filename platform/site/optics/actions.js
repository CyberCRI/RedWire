({
  clearBackground: {
    paramDefs: {
      "color": "black",
      "graphics": null
    },
    update: function() {
      this.params.graphics.shapes.push({
        type: "rectangle",
        layer: "bg",
        fillStyle: this.params.color,
        position: [0, 0],
        size: this.params.graphics.size
      });
    }
  },

  drawImage: {
    paramDefs: {
      graphics: null,
      image: null,
      x: 0,
      y: 0
    },
    update: function() {
      this.params.graphics.shapes.push({
        type: "image",
        layer: "bg",
        asset: this.params.image,
        position: [this.params.x, this.params.y]
      });
    }
  },

  drawText: {
    paramDefs: {
      text: "",
      x: 0,
      y: 12,
      style: "black",
      font: "12px Arial",
      "graphics": null
    },
    update: function() { 
      this.params.graphics.shapes.push({
        type: "text",
        layer: "text",
        text: this.params.text,
        style: this.params.style,
        font: this.params.font,
        position: [this.params.x, this.params.y]
      });
    }
  },

  group: { 
    doc: "Just to place children under it"
  },

  drawPiece: {
    paramDefs: {
      graphics: null,
      type: null,
      row: 0,
      col: 0,
      rotation: 0
    },
    update: function() {
      this.params.graphics.shapes.push({
        type: "image",
        layer: "pieces",
        asset: this.params.type,
        position: [-26, -26],
        translation: [this.params.col * 53 + 33 + 26, this.params.row * 53 + 33 + 26],
        rotation: this.params.rotation // In degrees 
      });
    }
  },

  drawSelected: {
    paramDefs: {
      graphics: null,
      row: 0,
      col: 0
    },
    update: function() {
      this.params.graphics.shapes.push({
        type: "rectangle",
        layer: "selection",
        position: [this.params.col * 53 + 33, this.params.row * 53 + 33],
        size: [50, 50],
        strokeStyle: "yellow",
        lineWidth: 4
      });
    }
  },

  incrementNumber: {
    paramDefs: {
      number: 0
    },
    update: function() {
      this.params.number++;
    }
  },

  drawLight: {
    paramDefs: {
      "graphics": null,
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
          lightSegments[lightSegments.length - 1].destination = intersectsCell(lightSegments[lightSegments.length - 1].origin, currentCell, [element.col, element.row]);

          lightIntensity = 0;
        }
        else if(element.type == "mirror")
        {
          // find intersection with central line
          // HACK: adding 90 degrees to rotation seems to work, but doesn't seem necessary
          var rotation = (element.rotation + 90) * Math.PI / 180; 
          var centralLineDiff = [.5 * Math.cos(rotation), .5 * Math.sin(rotation)];
          var centralLine = [[element.col + 0.5 + centralLineDiff[0], element.row + 0.5 + centralLineDiff[1]], [element.col + 0.5 - centralLineDiff[0], element.row + 0.5 - centralLineDiff[1]]];
          var lineDestination = Vector.create(currentCell).add(Vector.create(lightDirection));
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
      // options override default values for all drawn shapes (layer, composition, etc.)
      function drawGradientLine(origin, dest, innerRadius, outerRadius, colorRgba, options)
      {
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

        strokeGrad = {
          type: "linearGradient",
          startPosition: strokeGradUpper.elements,
          endPosition: strokeGradLower.elements,
          colorStops: [
            { position: 0, color: "rgba(" + transRgba.join(",") + ")" },
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1 - innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        that.params.graphics.shapes.push(_.extend({
          type: "path",
          layer: "light",
          strokeStyle: strokeGrad,
          lineWidth: 2 * outerRadius,
          points: [originV.elements, destV.elements]
        }, options));

        fillGrad = {
          type: "radialGradient",
          start: {
            position: originV.elements,
            radius: 0
          },
          end: {
            position: originV.elements,
            radius: outerRadius
          },
          colorStops: [
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        that.params.graphics.shapes.push(_.extend({
          type: "circle",
          layer: "light",
          fillStyle: fillGrad,
          position: originV.elements,
          radius: outerRadius
        }, options));

        fillGrad = {
          type: "radialGradient",
          start: {
            position: destV.elements,
            radius: 0
          },
          end: {
            position: destV.elements,
            radius: outerRadius
          },
          colorStops: [
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        that.params.graphics.shapes.push(_.extend({
          type: "circle",
          layer: "light",
          fillStyle: fillGrad,
          position: destV.elements,
          radius: outerRadius
        }, options));
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
      // Based on Bresenham's "simplified" line algorithm (http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)      
      var d, s, r;
      updateLightDirection();

      var origin = [lightSource.col + .5, lightSource.row + .5]
      var currentCell = [lightSource.col + .5, lightSource.row + .5]

      var lightSegments = [ { origin: [currentCell[0], currentCell[1]], intensity: lightIntensity }];
      var element;
      do
      { 
        var err2 = 2 * err;
        if(err2 > -d[1]) {
          err = err - d[1];
          currentCell[0] += s[0]
        }
        if(err2 < d[0]) {
          err = err + d[0];
          currentCell[1] += s[1]
        }

        if(!isInGrid(currentCell)) 
        {
          lightIntensity = 0;

          // find intersection with boundaries
          lightSegments[lightSegments.length - 1].destination = intersectsBoundaries(lightSegments[lightSegments.length - 1].origin, currentCell);
        }
        else if(element = findGridElement(currentCell))
        {
          handleGridElement();
        }
      } while(lightIntensity > 0);

      // DRAW SEGMENTS

      // Draw black mask that we will cut away from
      // based on the method of this fiddle: http://jsfiddle.net/wNYkX/3/
      that.params.graphics.shapes.push({
        type: "rectangle",
        layer: "mask",
        fillStyle: "black",
        position: [0, 0],
        size: that.params.graphics.size,
        order: 0
      });

      // now cut away, using 'destination-out' composition
      var maskOptions = { 
        layer: "mask", 
        composition: "destination-out", 
        order: 1 
      };
      for(var i = 0; i < lightSegments.length; i++)
      {
        drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 30, 40, [255, 255, 255, lightSegments[i].intensity], maskOptions);
      }

      // draw light ray normally
      for(var i = 0; i < lightSegments.length; i++)
      {
        drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 4, 6, [255, 0, 0, lightSegments[i].intensity]);
      }
    }
  },

  rotateSelectedPiece: {
    paramDefs: {
      "selected": null,
      "pieces": [],
      "keyboard": null,
      "rotationAmount": 1 // degrees
    },
    update: function() {
      var that = this;
      function findGridElement(point)
      {
        for(var i in that.params.pieces)
        {
          var piece = that.params.pieces[i];
          if(piece.col == Math.floor(point[0]) && piece.row == Math.floor(point[1])) return piece; 
        }
        return null;
      }

      var selectedPiece = findGridElement([this.params.selected.col, this.params.selected.row]);
      if(!selectedPiece) return; // nothing selected, so can't rotate


      var keysDown = this.params.keyboard.keysDown; // alias
      if(keysDown[37]) { // left
        selectedPiece.rotation -= this.params.rotationAmount;
      } else if(keysDown[39]) { // right
        selectedPiece.rotation += this.params.rotationAmount;
      }
    }
  }
});