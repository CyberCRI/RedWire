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
      var x = this.params.col * 52 + 33 + 26;
      var y = this.params.row * 52 + 33 + 26;

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
      context.strokeRect(this.params.col * 52 + 33, this.params.row * 52 + 33, 52, 52);
    }
  },

  calculateLight: {
    paramDefs: {
      "pieces": []
    },
    update: function() {
      var MARGIN = 33 + 26;
      var CELL_SIZE = 52;
      var GRID_SIZE = [14, 9];

      function handleGridCell(point, intensity, direction)
      {
        console.log("point: ", point[0], point[1]);

        if(point[0] < 0 || point[0] > GRID_SIZE[0] || point[1] < 0 || point[1] > GRID_SIZE[1]) return [0, [0, 0]];

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

      var points = []; 
      do
      {
        points.push([origin[0], origin[1]]);

        var err2 = 2 * err;
        if(err2 > -d[1]) {
          err = err - d[1];
          origin[0] += s[0]
        }
        if(err2 < d[0]) {
          err = err + d[0];
          origin[1] += s[1]
        }

        var results = handleGridCell(origin, lightIntensity, lightDirection);
        lightIntensity = results[0];
        lightDirection = results[1];
      } while(lightIntensity > 0);

      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.save();
      context.strokeStyle = "red"
      context.strokeRect(this.params.col * 52 + 33, this.params.row * 52 + 33, 52, 52);

      context.moveTo(points[0][0], points[0][1]);
      context.beginPath();
      for(var i = 1; i < points.length; i++)
      {
        context.lineTo(points[i][0] * CELL_SIZE + MARGIN, points[i][1] * CELL_SIZE + MARGIN);
      }
      context.stroke();

      context.restore();
    }
  }
});