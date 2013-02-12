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
      var x = this.params.row * 52 + 33 + 26;
      var y = this.params.col * 52 + 33 + 26;

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
      context.strokeRect(this.params.row * 52 + 33, this.params.col * 52 + 33, 52, 52);
    }
  }
});