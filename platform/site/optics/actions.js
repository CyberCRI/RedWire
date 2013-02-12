({
  clearBackground: {
    paramDefs: {
      "backgroundColor": "black"
    },
    update: function() {
      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
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
      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
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
      col: 0
    },
    update: function() {
      // This could be done by drawImage() if better expressions existed
      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.drawImage(this.assets[this.params.type], this.params.row * 50 + 33, this.params.col * 50 + 33);
    }
  },
});