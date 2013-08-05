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

  //returns a copy of 'pieces' with the piece 'oldPiece' replaced by 'newPiece' if 'oldPiece' was present in 'pieces'
  replace: function(oldPiece, newPiece, pieces)
  {
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.col === oldPiece.col && piece.row === oldPiece.row) {
        result = pieces.slice(0, i).concat(newPiece).concat(pieces.slice(i+1, pieces.length));
        return result;
      } 
    }
    return pieces;
  },

  //converts a pixel coordinate to a board coordinate
  //assumes that the board is made out of squares
  toBoardCoordinate: function(pixelCoordinate, upperLeftBoardMargin, cellSize)
  {
    var res = Math.floor((pixelCoordinate - upperLeftBoardMargin)/cellSize);
    return res;
  },

  //does the opposite of toBoardCoordinate
  toPixelCoordinate: function(boardCoordinate, upperLeftBoardMargin, cellSize)
  {
    return (boardCoordinate + 0.5)*(cellSize-1) + upperLeftBoardMargin;
  },

  //returns the piece at position 'square' on the board, or null if there is none
  findGridElement: function(square, pieces)
  {
    if(square === null) return null;

    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.col == square[0] && piece.row == square[1]) {
        return piece;
      } 
    }
    return null;
  },

  isMovable: function(piece, unmovablePieces)
  {
    return (piece && unmovablePieces.indexOf(piece.type) == -1);
  },

  //moves a piece from the board or the box to a square on the board
  //@piece: if on board has attributes "type", "col", "row" and "rotation"; if in box: has attributes "type" and "index"
  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  //which is determined by examining the attributes of "piece"
  //
  //returns {piece, pieces, boxedPiece}
  //piece is the updated piece
  //pieces is the update table of board pieces
  //boxedPieces is the update table of boxed pieces
  movePieceTo: function(piece, newSquare, pieces, boxedPieces, gridSize, unmovablePieces)
  {
    //this.log(GE.logLevels.INFO, "starting movePieceTo(piece=", piece, ", newSquare=", newSquare, ", pieces=", pieces, ", boxedPieces=", boxedPieces, ")");

    var newPiece = GE.cloneData(piece);
    var newPieces = GE.cloneData(pieces);
    var newBoxedPieces = GE.cloneData(boxedPieces);

    if(this.isMovable(piece, unmovablePieces)) {
      if(newSquare != null) { //defensive code
        if(this.findGridElement(newSquare, pieces) == null) {
          if ((piece.col !== undefined) && (piece.row !== undefined)) { //the piece was on the board, let's change its coordinates
            //this.log(GE.logLevels.INFO, "movePieceTo the piece was on the board, let's change its coordinates");
            //var movedPiece = findGridElement([piece.col, piece.row], pieces);
            //movedPiece.col = newSquare[0];
            //movedPiece.row = newSquare[1];
            newPiece.col = newSquare[0];
            newPiece.row = newSquare[1];
            newPieces    = this.replace(piece, newPiece, pieces);
            //this.log(GE.logLevels.INFO, "piece", piece, "newPiece", newPiece, "newPieces", newPieces);
          } else { //the piece was in the box, let's put it on the board  
            //this.log(GE.logLevels.INFO, "movePieceTo the piece was in the box, let's put it on the board");
            //remove the piece from the "boxedPieces"
            newBoxedPieces = this.takePieceOutOfBox(piece.type, boxedPieces);

            //add it to the "pieces" with the appropriate coordinates
            newPiece = {
              "col": newSquare[0],
              "row": newSquare[1],
              "type": piece.type,
              "rotation": 0
            };
            newPieces = pieces.concat([newPiece]);
          }
        }
      } else {
        //the new square position is outside of the board: let's box the piece
        //this.log(GE.logLevels.INFO, "movePieceTo the new square position is outside of the board: let's box the piece");
        var put = this.putPieceIntoBox(piece, pieces, boxedPieces);
        newPiece = put.piece;
        newPieces = put.pieces;
        newBoxedPieces = put.boxedPieces;
      }
      //this.log(GE.logLevels.INFO, "finished movePieceTo(piece=", piece, ", newSquare=", newSquare, ", pieces=", pieces, ", boxedPieces=", boxedPieces, ")");
    } else {
      //this.log(GE.logLevels.INFO, "finished movePieceTo(piece=", piece, ", newSquare=", newSquare, ", pieces=", pieces, ", boxedPieces=", boxedPieces, ")");
    }

    var toReturn = {};
    toReturn.piece                  = newPiece;
    toReturn.pieces                 = newPieces;
    toReturn.boxedPieces            = newBoxedPieces;

    toReturn.selectedPiece          = null; //draggedPiece ?
    toReturn.draggedPiece           = null;
    toReturn.rotating               = false;
    toReturn.originalRotation       = null;
    toReturn.originalPieceRotation  = null;

    return toReturn;
  },

  //returns boxedPieces minus a piece of type "pieceType"
  //besides, boxedPieces is still sorted afterwards
  takePieceOutOfBox: function(pieceType, boxedPieces)
  {
    //console.log("takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
    for(var i in boxedPieces)
    {
      var piece = boxedPieces[i];
      if(piece.type === pieceType) {
        return this.removeElement(boxedPieces, i);
        //console.log("finished takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
        //console.log("takePieceOutOfBox("+pieceType+", "+this.piecesToString(boxedPieces)+")="+this.piecesToString(res));
      }
    }
    //console.log("failed takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
  },

  //takes a piece 'piece' from the board, i.e. 'pieces', and puts it into the box, i.e. 'boxedPieces'
  //@piece: the piece to be moved
  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  //returns {boxedPiece, pieces, boxedPieces}
  putPieceIntoBox: function(piece, pieces, boxedPieces)
  {
    //console.log("putPieceIntoBox(piece="+this.pieceToString(piece)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+")");

    var res = {};

    if(piece.row !== undefined) { //source of movement isn't the box
      //console.log("putPieceIntoBox: source of movement isn't the box");
      res.boxedPiece = {
        "type": piece.type
      };
      //put at the right place
      res.boxedPieces = boxedPieces.concat(res.boxedPiece);
      res.pieces = this.removeElement(pieces, GE.indexOfEquals(pieces, piece));
    } else { //the piece was moved from the box
      //console.log("putPieceIntoBox: the piece was moved from the box");
      //console.log("finished putPieceIntoBox(piece="+this.pieceToString(piece)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+") - did nothing");
      res.boxedPiece = piece;
      res.pieces = pieces;
      res.boxedPieces = boxedPieces;
    }

    return res;
  },

  //returns the coordinates of the square that was clicked on in the box, or null if outside of the box
  //@position: array of coordinates in pixels
  //@position: warning: needed attributes are not checked!
  getIndexInBox: function(position, boxLeft, boxTop, boxCellSize, boxRowsCount, boxColumnsCount)
  {
    //tests whether is in box or not
    var relativeX = position[0] - boxLeft;
    var relativeY = position[1] - boxTop;

    var col = Math.floor(relativeX/boxCellSize[0]);
    var row = Math.floor(relativeY/boxCellSize[1]);

    if((0 <= col) && (boxColumnsCount > col) && (0 <= row) && (boxRowsCount > row)) {
      var index = 2*row+col;

      //console.log("getIndexInBox returns "+index);
      return index;
    }
    //console.log("getIndexInBox: out of box");
    return null;
  },

  //2D coordinates
  coordinatesToString: function(coordinates) {
    var x = coordinates[0] || coordinates.x;
    var y = coordinates[1] || coordinates.y;
    return "["+x+", "+y+"]";
  },

  pieceToString: function(piece) {
    if(piece) return "{col:"+piece.col+", row:"+piece.row+", type:"+piece.type+"}";
    else return piece;
  },

  piecesToString: function(pieces) {
    var printed = "{";
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(printed !== "{") {
        printed += ", ";
      }
      printed += this.pieceToString(piece);
    }
    printed += "}";
    return printed;
  },

  distance: function(point1, point2) {
    var point1x = point1[0] || point1.x;
    var point1y = point1[1] || point1.y;
    var point2x = point2[0] || point2.x;
    var point2y = point2[1] || point2.y;
    var diffX = point1x - point2x;
    var diffY = point1y - point2y;
    return Math.sqrt(diffX*diffX + diffY*diffY);        
  },

  areSamePiece: function(piece1, piece2) {
    return (piece1 && piece2 && (piece1.col == piece2.col) && (piece1.row == piece2.row))
  },

  //tests whether a given position is inside the board or not
  //@positionOnBoard: array of coordinates as column and row position
  isInGrid: function(point, gridSize)
  {
    return (point[0] >= 0) && (point[0] < gridSize[0]) && (point[1] >= 0) && (point[1] < gridSize[1]);        
  },

  // Attempts to find intersection with the given lines and returns it.
  // Else returns null.
  findIntersection: function(origin, dest, lines, extendLinesFactor)
  {
    var closestIntersection = null;
    var distanceToClosestIntersection = Infinity;
    for(var i = 0; i < lines.length; i++)
    {
      // extend lines slightly
      var a = Vector.create(lines[i][0]);
      var b = Vector.create(lines[i][1]);
      var aToB = b.subtract(a);
      var midpoint = a.add(aToB.multiply(0.5));
      var newLength = (1 + extendLinesFactor) * aToB.modulus();
      var unit = aToB.toUnitVector();
      var aExtend = midpoint.add(unit.multiply(-0.5 * newLength));
      var bExtend = midpoint.add(unit.multiply(0.5 * newLength));

      var intersection = Line.Segment.create(origin, dest).intersectionWith(Line.Segment.create(aExtend, bExtend));
      if(intersection) 
      {
        // the intersection will be in 3D, so we need to cast the origin to 3D as well or distance calculation will fail (returns null)
        var distanceToIntersection = Vector.create(origin).to3D().distanceFrom(intersection);
        if(distanceToIntersection < distanceToClosestIntersection) 
        {
          closestIntersection = intersection;
          distanceToClosestIntersection = distanceToIntersection;
        }
      }
    }

    return closestIntersection === null ? null : closestIntersection.elements.slice(0, 2); // return only 2D part
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsBoundaries: function(origin, dest, gridSize, extendLinesFactor)
  {
    var boundaries = 
    [
      [[0, 0], [gridSize[0], 0]], // top
      [[gridSize[0], 0], [gridSize[0], gridSize[1]]], // right
      [[gridSize[0], gridSize[1]], [0, gridSize[1]]], // bottom
      [[0, gridSize[1]], [0, 0]] // left
    ];

    return this.findIntersection(origin, dest, boundaries, extendLinesFactor);
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsCell: function(origin, dest, cellPos, extendLinesFactor)
  {
    var boundaries = 
    [
      [[cellPos[0], cellPos[1]], [cellPos[0], cellPos[1] + 1]], // top
      [[cellPos[0], cellPos[1] + 1], [cellPos[0] + 1, cellPos[1] + 1]], // right
      [[cellPos[0] + 1, cellPos[1] + 1], [cellPos[0] + 1, cellPos[1]]], // bottom
      [[cellPos[0] + 1, cellPos[1]], [cellPos[0], cellPos[1]]] // left
    ];

    return this.findIntersection(origin, dest, boundaries, extendLinesFactor);
  },

  isRotatable: function(piece, unrotatablePieces)
  {
    return (piece && unrotatablePieces.indexOf(piece.type) == -1)
  },

  getBoxedPiece: function(index, boxedPieces) {
    return index === null ? null : boxedPieces[index];
  },

  // Not really generic, assumes that there are 2 cells per row and that they should be laid out row-first
  // TODO: why check the array length?
  gridCellToIndex: function(array, cell) {
    if(array === null || cell === null) return null;

    var index = 2 * cell[1] + cell[0];
    return index < array.length ? index : null;
  },

  // Not really generic, assumes that there are 2 cells per row and that they should be laid out row-first
  gridIndexToCell: function(index) {
    if(index === null) return null;

    return [index % 2, Math.floor(index / 2)];
  },

  gridCellAtPoint: function(grid, point) {
    //this.log(GE.logLevels.INFO, "point", point, "grid", grid);
    if(point === null) return null;

    var gridPos = [
      Math.floor((point[0] - grid.upperLeft[0]) / grid.cellSize[0]),
      Math.floor((point[1] - grid.upperLeft[1]) / grid.cellSize[1])
    ];

    if(gridPos[0] < 0 || gridPos[0] > grid.gridSize[0] || gridPos[1] < 0 || gridPos[1] > grid.gridSize[1]) 
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

  // Returns { segments: [ { origin: , destination: }, ... ], cells: [ cell, ... ]}
  makeLightPath: function(pieces, gridSize, mirrorAttenuationFactor, minimumAttenuation) {
    var that = this;
    var EXTEND_LINES_FACTOR = Sylvester.precision;

    function handleGridElement()
    {
      if(element.type == "wall")
      {
        // find intersection with wall
        var wallIntersection = that.intersectsCell(lightSegments[lightSegments.length - 1].origin, lightDestination, [element.col, element.row], EXTEND_LINES_FACTOR);
        if(wallIntersection === null) throw new Error("Cannot find intersection with wall");
        lightSegments[lightSegments.length - 1].destination = wallIntersection;

        lightIntensity = 0;
      }
      else if(element.type == "mirror")
      {
        // find intersection with central line
        var rotation = element.rotation * Math.PI / 180; 
        var centralLineDiff = [.5 * Math.cos(rotation), .5 * Math.sin(rotation)];
        var centralLine = [[element.col + 0.5 + centralLineDiff[0], element.row + 0.5 + centralLineDiff[1]], [element.col + 0.5 - centralLineDiff[0], element.row + 0.5 - centralLineDiff[1]]];
        if(intersection = that.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [centralLine], EXTEND_LINES_FACTOR))
        {
          lightSegments[lightSegments.length - 1].destination = intersection;

          lightIntensity *= mirrorAttenuationFactor;
          if(lightIntensity < minimumAttenuation)
          {
            lightIntensity = 0;
          }
          else
          {
            lightSegments.push({ origin: intersection, intensity: lightIntensity });

            // reflect around normal
            // normal caluclation from http://www.gamedev.net/topic/510581-2d-reflection/)
            // reflection calculation from http://paulbourke.net/geometry/reflected/ 
            // Rr = Ri - 2 N (Ri . N)
            var normal = Vector.create([-Math.sin(rotation), Math.cos(rotation)]);
            var oldLightDirection = Vector.create(lightDirection);
            lightDirection = oldLightDirection.subtract(normal.multiply(2 * oldLightDirection.dot(normal))).elements;

            lightDirectionUpdated();
          }
        }
      }
    }

    function lightDirectionUpdated()
    {
      lightSigns = [lightDirection[0] > 0 ? 1 : -1, lightDirection[1] > 0 ? 1 : -1];

      var distanceOutOfGrid = Math.sqrt(gridSize[0]*gridSize[0] + gridSize[1]*gridSize[1]);
      var lastOrigin = lightSegments[lightSegments.length - 1].origin;
      lightDestination = Sylvester.Vector.create(lastOrigin).add(Sylvester.Vector.create(lightDirection).multiply(distanceOutOfGrid)).elements.slice();
    }

    // Do everything in the "grid space" and change to graphic coordinates at the end

    // find source of light
    var lightSource;
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.type == "laser-on") 
      {
        lightSource = piece;
        break;
      }
    }
    if(!lightSource) {
      return [];
    }

    // calculate origin coordinates of light 
    // the piece starts vertically, so we rotate it 90 degrees clockwise by default
    var rotation = (lightSource.rotation - 90) * Math.PI / 180; 
    var lightDirection = [Math.cos(rotation), Math.sin(rotation)];
    // TODO: add color portions of light (3 different intensities)
    var lightIntensity = 1.0; // start at full itensity

    // follow light path through the grid, checking for intersections with pieces
    // Based on Bresenham's "simplified" line algorithm (http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)      
    var currentCell = [lightSource.col, lightSource.row]
    var lightSegments = [ { origin: [currentCell[0] + 0.5, currentCell[1] + 0.5], intensity: lightIntensity }];

    var lightSigns;
    var lightDestination; // represents a point outside of the grid that the light could reach if unimpeded 
    lightDirectionUpdated();

    var element;
    var nextCells = [];
    var touchedCells = [ currentCell ];
    do
    { 
      var verticalIntersection = null;
      if(Math.abs(lightDirection[0]) > Sylvester.precision)
      {
        var x = currentCell[0] + (lightDirection[0] > 0 ? 1 : 0);
        var line = [[x, currentCell[1]], [x, currentCell[1] + 1]];
        verticalIntersection = this.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [line], EXTEND_LINES_FACTOR);
      } 
      var horizontalIntersection = null;
      if(Math.abs(lightDirection[1]) > Sylvester.precision)
      {
        var y = currentCell[1] + (lightDirection[1] > 0 ? 1 : 0);
        var line = [[currentCell[0], y], [currentCell[0] + 1, y]]
        horizontalIntersection = this.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [line], EXTEND_LINES_FACTOR);
      } 

      if(verticalIntersection && horizontalIntersection)
      {
        // move diagonally
        currentCell = [currentCell[0] + lightSigns[0], currentCell[1] + lightSigns[1]];
      }
      else if(verticalIntersection)
      {
        // move horizontally
        currentCell = [currentCell[0] + lightSigns[0], currentCell[1]];          
      }
      else if(horizontalIntersection)
      {
        // move vertically
        currentCell = [currentCell[0], currentCell[1] + lightSigns[1]];          
      }
      else 
      {
        // this is WEIRD!
        throw new Error("Light vector is NULL");
      }

      touchedCells.push(currentCell);

      if(!this.isInGrid(currentCell, gridSize))
      {
        lightIntensity = 0;

        // find intersection with boundaries
        var boundaryIntersection = this.intersectsBoundaries(lightSegments[lightSegments.length - 1].origin, lightDestination, gridSize, EXTEND_LINES_FACTOR);
        if(boundaryIntersection === null) throw new Error("Cannot find intersection with boundaries");
        lightSegments[lightSegments.length - 1].destination = boundaryIntersection;
      }
      else if(element = this.findGridElement(currentCell, pieces))
      {
        handleGridElement();
      }
    } while(lightIntensity > 0);

    return { segments: lightSegments, cells: touchedCells };
  },

  drawLightPath: function(grid, lightSegments) {
    var that = this;

    // all lines are in grid space, not in screen space
    // options override default values for all drawn shapes (layer, composition, etc.)
    function drawGradientLine(origin, dest, innerRadius, outerRadius, colorRgba, options)
    {
      var marginV = Vector.create(grid.upperLeft);

      // find normal to line (http://stackoverflow.com/questions/1243614/how-do-i-calculate-the-normal-vector-of-a-line-segment)`
      // does not work if cells are not square
      var originV = Vector.create(origin).multiply(grid.cellSize[0]).add(marginV);
      var destV = Vector.create(dest).multiply(grid.cellSize[0]).add(marginV);
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

      shapes = that.drawShape(_.extend({
        type: "path",
        layer: "light",
        strokeStyle: strokeGrad,
        lineWidth: 2 * outerRadius,
        points: [originV.elements, destV.elements]
      }, options), shapes);

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

      shapes = that.drawShape(_.extend({
        type: "circle",
        layer: "light",
        fillStyle: fillGrad,
        position: originV.elements,
        radius: outerRadius
      }, options), shapes);

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

      shapes = that.drawShape(_.extend({
        type: "circle",
        layer: "light",
        fillStyle: fillGrad,
        position: destV.elements,
        radius: outerRadius
      }, options), shapes);
    }

     // DRAW SEGMENTS

    var shapes = {};

    // Draw black mask that we will cut away from
    // based on the method of this fiddle: http://jsfiddle.net/wNYkX/3/
    shapes = this.drawShape({
      type: "rectangle",
      layer: "mask",
      fillStyle: "black",
      position: grid.upperLeft,
      size: this.gridSizeInPixels(grid),
      order: 0
    }, shapes);

    // now cut away, using 'destination-out' composition
    var maskOptions = { 
      layer: "mask", 
      composition: "destination-out", 
      order: 1 
    };
    for(var i = 0; i < lightSegments.length; i++)
    {
      //TODO extract 30 and 40 values
      drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 30, 40, [255, 255, 255, lightSegments[i].intensity], maskOptions);
    }

    // draw light ray normally
    for(var i = 0; i < lightSegments.length; i++)
    {
      //TODO extract 4 and 6 values
      drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 4, 6, [255, 0, 0, lightSegments[i].intensity]);
    }

    return shapes;
  },

  reachedGoal: function(touchedCells, pieces) {
    for(var i in touchedCells)
    {
      var element = this.findGridElement(touchedCells[i], pieces);
      if(element && element.type === "squarePrism") return true;
    }
    return false;
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
    var childIndex = GE.indexOfEquals(children, value);
    return childIndex != -1 ? [childIndex] : []; 
  },

  pieceIsMovable: function(piece, unmovablePieceTypes) {
    return !_.contains(unmovablePieceTypes, piece.type);
  },

  pieceIsRotatable: function(piece, unrotatablePieceTypes) {
    return !_.contains(unrotatablePieceTypes, piece.type);
  },

  makeFilledRectangle: function(grid, cell, meta) {
    return _.extend(this.gridCellRectangle(grid, cell, meta), {
      strokeStyle: "white",
      fillStyle: "white"
    });
  },

  makeBoardShapes: function(boardGrid, boardPieces) {
    var that = this;
    return boardShapes = _.map(boardPieces, function(piece) { return that.makeFilledRectangle(boardGrid, [piece.col, piece.row], piece) });
    var boxShapes = _.map(_.range(boxedPieces.length), function(index) { return makeFilledRectangle(boxGrid, that.gridIndexToCell(index), boxedPieces[index]); });
    return GE.concatenate(boardShapes, boxShapes); 
  },

  makeBoxShapes: function(boxGrid, boxedPieces) {
    var that = this;
    return boxShapes = _.map(_.range(boxedPieces.length), function(index) { return that.makeFilledRectangle(boxGrid, that.gridIndexToCell(index), boxedPieces[index]); });
  },

  makeRotateShape: function(boardGrid, selectedCell) {
    return { 
      type: 'circle', 
      radius: 0.8 * boardGrid.cellSize[0], 
      center: this.gridCellCenter(boardGrid, selectedCell), 
      strokeStyle: 'white', 
      lineWidth: 15,
      meta: "rotate"
    };    
  }, 

  findPieceAtCell: function(boardPieces, cell) {
    return _.findWhere(boardPieces, { col: cell[0], row: cell[1] });
  },

  makeDetectableShapes: function(boardGrid, boardPieces, boxGrid, boxedPieces, selectedCell, unrotatablePieceTypes) {
    var shapes = GE.concatenate(this.makeBoardShapes(boardGrid, boardPieces), this.makeBoxShapes(boxGrid, boxedPieces));
    if(selectedCell)
    {
      var selectedPiece = this.findPieceAtCell(boardPieces, selectedCell);
      if(selectedPiece && this.pieceIsRotatable(selectedPiece, unrotatablePieceTypes)) shapes.push(this.makeRotateShape(boardGrid, selectedCell));
    }
    return shapes;
  }
})