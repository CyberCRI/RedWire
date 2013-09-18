({
  // Add a shape to be drawn to graphics
  drawShape: function(shape, oldShapes) 
  {
    var shapes = oldShapes || {};
    shapes[_.uniqueId()] = shape;
    return shapes; 
  },

  // Checks if a point intersects a shape.
  // Currently does not take rotation into account, and only supports circles and rectangles.
  // Requires Sylvester.js
  pointIntersectsShape: function(point, shape)
  {
    if(!shape.fillStyle && !shape.strokeStyle) return false;

    switch(shape.type)
    {
      case "circle":
        var center = Vector.create(shape.center);
        if(shape.translation) center = center.add(shape.translation);
        var lineWidth = shape.lineWidth || 1;
        var scale = shape.scale || 1;
        var minDistance = shape.fillStyle ? 0 : shape.radius - lineWidth;
        var maxDistance = shape.strokeStyle ? shape.radius + lineWidth : shape.radius;
        var distance = center.distanceFrom(Vector.create(point));
        return distance >= minDistance * scale && distance <= maxDistance * scale;

      case "rectangle":
        // Move the point to the frame of the shape
        var pointInShapeFrame = Vector.create(point);
        if(shape.translation) pointInShapeFrame = pointInShapeFrame.subtract(shape.translation);
        return pointInShapeFrame.elements[0] >= shape.position[0] && pointInShapeFrame.elements[0] <= shape.position[0] + shape.size[0] &&
          pointInShapeFrame.elements[1] >= shape.position[1] && pointInShapeFrame.elements[1] <= shape.position[1] + shape.size[1];

      default:
        throw new Error("Shape type '" + shape.type + "' is not supported");
    }
  },

  //returns a copy of 'tab' without the element at position 'index'
  removeElement: function(tab, index)
  {
    // By all logic, this should work. But after days of testing it, I give up...
    //   return tab.slice(0, index).concat(tab.slice(index + 1));
    // Here's the slow but foolproof way
    var newArray = [];
    for(var i = 0; i < tab.length; i++) {
      if(i != index) newArray.push(tab[i]);
    }
    return newArray;
  },

  gridCellAtPoint: function(grid, point) {
    if(point === null) return null;

    var gridPos = [
      Math.floor((point[0] - grid.upperLeft[0]) / grid.cellSize[0]),
      Math.floor((point[1] - grid.upperLeft[1]) / grid.cellSize[1])
    ];

    if(grid.type != "infinite" && (gridPos[0] < 0 || gridPos[0] > grid.gridSize[0] || gridPos[1] < 0 || gridPos[1] > grid.gridSize[1])) 
      return null;
    else
      return gridPos;
  },

  gridCellToPoint: function(grid, cell, proportions) {
    return [
      (cell[0] + proportions[0]) * grid.cellSize[0] + grid.upperLeft[0], 
      (cell[1] + proportions[1]) * grid.cellSize[1] + grid.upperLeft[1]
    ];
  },

  gridCellUpperLeft: function(grid, cell) { return this.gridCellToPoint(grid, cell, [0, 0]); },

  gridCellCenter: function(grid, cell) { return this.gridCellToPoint(grid, cell, [0.5, 0.5]); },

  // the meta is optional
  gridCellRectangle: function(grid, cell, meta) {
    return {
      type: "rectangle",
      position: this.gridCellUpperLeft(grid, cell),
      size: grid.cellSize,
      meta: meta
    };
  },

  gridSizeInPixels: function(grid) {
    return [grid.cellSize[0] * grid.gridSize[0], grid.cellSize[1] * grid.gridSize[1]];
  },

  gridIndexToCell: function(grid, index) {
    // Assumes that cells are laid out from left to right, then top to bottom 
    return [index % grid.gridSize[0], Math.floor(index / grid.gridSize[0])];
  },

  calculateRotationAngle: function (center, mousePosition) {
    var h = [mousePosition[0] - center[0], mousePosition[1] - center[1]];
    var omDistance = Math.sqrt(h[0]*h[0] + h[1]*h[1]);
    var ratio = -h[1]/omDistance;
    var angle = 0;
    if(omDistance !== 0) {
      var absValueAngle = Math.acos(ratio)*180/Math.PI;
      if(h[0] <= 0) {
        angle = -absValueAngle;
      } else {
        angle = absValueAngle;
      }
    }
    return angle;
  },

  calculateRotationOffset: function(rotation, center, mousePosition) {
    return rotation - this.calculateRotationAngle(center, mousePosition);
  },

  calculateRotation: function(rotationOffset, center, mousePosition) {
    return this.calculateRotationAngle(center, mousePosition) + rotationOffset;
  },

  // Returns an array containing the index of the first child that is equal to the correct value, or an empty array
  childByName: function(children, value) {
    var childIndex = GE.indexOf(children, value);
    return childIndex != -1 ? [childIndex] : []; 
  },

  makeFilledRectangle: function(grid, cell, meta) {
    return _.extend(this.gridCellRectangle(grid, cell, meta), {
      strokeStyle: "white",
      fillStyle: "white"
    });
  },

  makeGridCoveringRectangle: function(grid, meta) {
    return {
      meta: meta,
      type: "rectangle",
      position: grid.upperLeft,
      size: this.gridSizeInPixels(grid),
      strokeStyle: "white",
      fillStyle: "white"
    };
  },

  meanOfCoordinates: function(coordinates) {
    var sum = _.reduce(coordinates, function(memo, cell) { return [memo[0] + cell[0], memo[1] + cell[1]]; }, [0, 0]);
    return [sum[0] / coordinates.length, sum[1] / coordinates.length];
  },

  findCenterOfCells: function(grid, cells) {
    if(cells.length == 0) return [0, 0];

    var gridCenter = this.gridCenter(grid);
    var sum = _.reduce(cells, function(memo, cell) { return [memo[0] + cell[0] + 0.5, memo[1] + cell[1] + 0.5]; }, [0, 0]);
    return [sum[0] * grid.cellSize[0] / cells.length - gridCenter[0], sum[1] * grid.cellSize[1] / cells.length - gridCenter[1]];
  },

  listBlockCenters: function(grid, blocks) {
    return _.map(blocks, function(block) { 
      return [(block[0] + 0.5) * grid.cellSize[0], (block[1] + 0.5) * grid.cellSize[1]];
    });
  },

  gridCenter: function(grid) {
    return [grid.cellSize[0] * grid.gridSize[0] / 2, grid.cellSize[1] * grid.gridSize[1] / 2];
  },

  makeBlockShapes: function(grid, blocks, blockColor, blockSize) {
    var that = this;
    return _.map(blocks, function(block) { 
      return _.extend(that.gridCellRectangle(grid, block, block), { 
        layer: 'blocks', 
        fillStyle: blockColor,
        size: blockSize
      });
    });
  },

  makeMovableBlockShapes: function(grid, blocks, blockColor, blockSize) {
    var that = this;
    var movableBlocks = _.filter(blocks, function(block) { return that.canMoveBlock(blocks, block); });
    return _.map(movableBlocks, function(block) { 
      return _.extend(that.gridCellRectangle(grid, block, block), { 
        layer: 'blocks', 
        fillStyle: blockColor,
        size: blockSize
      });
    });
  },

  makeDraggedShape: function(size, color, mousePosition) {
    return { 
      layer: 'drag', 
      type: "rectangle",
      position: [mousePosition[0] - size[0] / 2, mousePosition[1] - size[1] / 2],
      size: size,
      fillStyle: color 
    };
  },

  drawShapes: function(shapes) 
  {
    var that = this;
    return _.reduce(shapes, function(memo, shape) { return that.drawShape(shape, memo); }, {});
  },

  blocksAreNeighbors: function(a, b) {
    // Find the difference between the two block coordinates
    var diff = [Math.abs(a[0] - b[0]), Math.abs(a[1] - b[1])];
    return diff[0] == 1 && diff[1] == 0 || diff[0] == 0 && diff[1] == 1; 
  },

  makeAdjacencyList: function(blocks) {
    // Pre-allocate array of empty arrays
    var adjList = _.map(blocks, function() { return []; });

    // Enumerate every pair of blocks
    for(var i = 0; i < blocks.length - 1; i++) {
      for(var j = i + 1; j < blocks.length; j++) {
        if(this.blocksAreNeighbors(blocks[i], blocks[j])) {
          adjList[i].push(j);
          adjList[j].push(i);
        }
      }
    }

    return adjList;
  },

  visitBlocks: function(adjList, startingIndices) {
    var visited = [startingIndices];
    // Loop until return call
    while(true) {
      // add all neighbors to 'toVisit'
      var toVisit = _.reduce(visited[visited.length - 1], function(memo, visitingIndex) { return memo.concat(adjList[visitingIndex]); }, []);
      // remove duplicates
      toVisit = _.uniq(toVisit);
      // take out previously visited ones
      toVisit = _.difference.apply(_, [toVisit].concat(visited));

      if(toVisit.length > 0) {
        visited.push(toVisit);
      }
      else
      {
        return visited;
      }
    }
  },

  canMoveBlock: function(blocks, block) {
    // The block can be moved if all other blocks are connected without the block in question
    var blocksWithout = this.removeElement(blocks, GE.indexOf(blocks, block));
    var adjList = this.makeAdjacencyList(blocksWithout);
    var visited = this.visitBlocks(adjList, [0]);
    return _.flatten(visited).length == blocksWithout.length; 
  },

  findFreeBlockPositions: function(blocks) {
    // Generate all neighbors of blocks
    var freePositions = [];
    _.each(blocks, function(block) {
      freePositions.push([block[0] + 1, block[1]]);
      freePositions.push([block[0] - 1, block[1]]);
      freePositions.push([block[0], block[1] + 1]);
      freePositions.push([block[0], block[1] - 1]);
    });

    // Take out duplicates
    freePositions = GE.uniq(freePositions);

    // Remove existing block positions
    return GE.difference(freePositions, blocks);
  },

  distanceBetweenPoints: function(a, b) {
    return Vector.create(a).distanceFrom(Vector.create(b));
  },

  translateShapes: function(translation, shapes) {
    var newShapes =  _.map(shapes, function(shape) { 
      return _.extend(shape, {
        position: [shape.position[0] + translation[0], shape.position[1] + translation[1]]
      });
    });
    return newShapes;
  },

  translatePoint: function(translation, point) {
    return [point[0] + translation[0], point[1] + translation[1]];
  },

  inverseVector: function(vector) { return [-vector[0], -vector[1]]; },

  subtractVectors: function(a, b) { return [a[0] - b[0], a[1] - b[1]]; },

  makeSelectionGalleryGrids: function(selectionGrid, galleryGrid, gallery) { 
    var that = this;
    return _.map(_.range(gallery.length), function(index) {
      var cell = that.gridIndexToCell(selectionGrid, index);
      return {
        type: "infinite",
        "upperLeft": that.gridCellUpperLeft(selectionGrid, cell),
        "cellSize": galleryGrid.cellSize,
        "gridSize": galleryGrid.gridSize
      };
    });
  },

  makeSelectionGalleryShapes: function(selectionGrids, selectedGalleryIndexes) {
    var that = this;
    return _.map(selectionGrids, function(selectionGrid, index) {
      return _.extend(that.makeGridCoveringRectangle(selectionGrid, index), {
        fillStyle: GE.contains(selectedGalleryIndexes, index) ? 'red' : 'grey',
        strokeStyle: 'white',
        layer: 'gallery'
      });
    });
  },

  serializeBlocks: function(blocks) {
    /*  The first ten integers are the ten possible rows of output (for a cubicle of size ten).
        Each integer is the decimal form of the binary number showing the occupancy of a row.
        For example take the first entry: 1023 is 1111111111 i.e. The first row is completely filled with tiles. All the other rows are 0 because they are empty. In the second entry the first row is 1022 = '1111111110' and the second row is 2 = '0000000010'; i.e. the rightmost tile has been moved down and left.
    */

    // Find the top-most (lowest) row and the left-most (lowest) column block coordinates
    var min = _.reduce(blocks, function(memo, block) { 
      return [Math.min(memo[0], block[0]), Math.min(memo[1], block[1])];
    }, [Infinity, Infinity]);

    // Initialize the row numbers to zero
    var rowNumbers = _.map(_.range(10), function() { return 0; });
    // Check off each block in binary
    _.each(blocks, function(block) { 
      var index = block[1] - min[1];
      rowNumbers[index] = rowNumbers[index] | (1 << (9 - (block[0] - min[0]))); 
    });

    // Return as a string of space-seperated decimal numbers 
    return rowNumbers;
  },

  makeTimestamp: function(ms) {
    // Ugly timestamp: yyyymmdd-hhmmss-ms
    //year()+nf(month(),2)+nf(day(),2)+"-"+nf(hour(),2)+nf(minute(),2)+nf(second(),2)+"-"+millis();
    return new Date(ms).toUTCString();
  },

  findDroppedPosition: function(grid, blocks, mousePosition) {
    var that = this;
    var hoveredCell = this.gridCellAtPoint(grid, mousePosition);
    if(!hoveredCell) return blocks; // Outside of the grid, don't make any changes 

    var freeBlockPositions = this.findFreeBlockPositions(blocks);
    // Find the closest free position to the mouse position
    return _.min(freeBlockPositions, function(block) { return that.distanceBetweenPoints(hoveredCell, block); });
  },

  makeBlockGroupsToBeHighlighted: function(blocks, newPosition) {
    this.log(GE.logLevels.INFO, "makeBlockGroupsToBeHighlighted", arguments);
    var newBlocks = GE.appendToArray(blocks, newPosition);
    var adjList = this.makeAdjacencyList(newBlocks);
    var visitedBlockIndexes = _.rest(this.visitBlocks(adjList, [newBlocks.length - 1]));
    return _.map(visitedBlockIndexes, function(blockIndexes) {
      return _.map(blockIndexes, function(index) { 
        return newBlocks[index];
      });
    });
  },

  adjustShapesByMeta: function(shapes, meta, properties) {
    return _.map(shapes, function(shape) {
      if(_.isEqual(shape.meta, meta)) {
        return _.extend(GE.clone(shape), properties);
      } else {
        return shape;
      }
    });
  },

  interpolateVector: function(start, end, fraction) { 
    return _.map(_.zip(start, end), function(pair) {
      return pair[0] + fraction * (pair[1] - pair[0]);
    });
  },

  cyclicInterpolate: function(start, end, fraction) {
    return fraction < 0.5 ? this.interpolateVector(start, end, fraction / 0.5) : this.interpolateVector(end, start, (fraction - 0.5) / 0.5)
  },

  rgbColorString: function(colorArray) { 
    var flooredArray = _.map(colorArray, function(value) { return Math.floor(value); });
    return "rgb(" + flooredArray.join(", ") + ")"; 
  },

  makeTrackingString: function(player, events) {
    return JSON.stringify({ player: player, events: events });
  }

})