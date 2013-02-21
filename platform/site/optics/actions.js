({
  clearBackground: {
    paramDefs: {
      "backgroundColor": "black"
    },
    update: function() {
      var canvas = $("#gameCanvas");
      var context = canvas[0].getContext("2d");
      context.setFillColor(this.params.backgroundColor);
      context.fillRect(0, 0, canvas.width(), canvas.height());
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

      var that = this;

      function isInGrid(point)
      {
        return point[0] >= 0 && point[0] < GRID_SIZE[0] && point[1] >= 0 && point[1] < GRID_SIZE[1];        
      }

      // Returns an intersection point with walls, or null otherwise
      function intersectsBoundaries(origin, dest)
      {
        var boundaries = 
        [
          Line.Segment.create([0, 0], [GRID_SIZE[0], 0]), // top
          Line.Segment.create([GRID_SIZE[0], 0], [GRID_SIZE[0], GRID_SIZE[1]]), // right
          Line.Segment.create([GRID_SIZE[0], GRID_SIZE[1]], [0, GRID_SIZE[1]]), // bottom
          Line.Segment.create([0, GRID_SIZE[1]], [0, 0]) // left
        ];

        var intersection = null;
        for(var i = 0; i < boundaries.length; i++)
        {
          intersection = Line.Segment.create(origin, dest).intersectionWith(boundaries[i]);
          if(intersection) return intersection.elements;
        }

        return null;
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

      function handleGridElement(element, intensity, direction)
      {
        return [intensity, direction];
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
      var origin = [lightSource.col + .5, lightSource.row + .5]
      var d = [Math.abs(lightDirection[0]), Math.abs(lightDirection[1])];
      var s = [lightDirection[0] > 0 ? 1 : -1, lightDirection[1] > 0 ? 1 : -1];
      var err = d[0] - d[1];

      var lightSegments = [ { origin: [origin[0], origin[1]], intensity: lightIntensity }];
      do
      {
        //points.push([origin[0], origin[1]]);

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
          var results = handleGridCell(element, lightIntensity, lightDirection);
          lightIntensity = results[0];
          lightDirection = results[1];
        }
      } while(lightIntensity > 0);

      console.log("lightSegments: ", lightSegments)

      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.save();
      context.strokeStyle = "red"

      context.beginPath();
      context.moveTo(lightSegments[0].origin * CELL_SIZE + MARGIN, lightSegments[0].origin * CELL_SIZE + MARGIN);
      for(var i = 0; i < lightSegments.length; i++)
      {
        context.lineTo(lightSegments[i].origin[0] * CELL_SIZE + MARGIN, lightSegments[i].origin[1] * CELL_SIZE + MARGIN);
        context.lineTo(lightSegments[i].destination[0] * CELL_SIZE + MARGIN, lightSegments[i].destination[1] * CELL_SIZE + MARGIN);
      }
      context.stroke();

      context.restore();
    }
  }
});