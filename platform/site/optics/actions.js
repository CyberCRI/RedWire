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
      image: null
    },
    update: function() {
      canvas = $("#gameCanvas");
      context = canvas[0].getContext("2d");
      context.drawImage(this.params.image, 0, 0);
    }
  }
});