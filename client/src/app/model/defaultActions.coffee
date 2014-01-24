
changeParameterThroughKeyboard =
  text: 'changeParameterThroughKeyboard'
  type: 'action'
  source:
    paramDefs:
      keysDown: null
      keyMap: null
      parameter:
        direction: 'inout'
    update: '''for (var keyCode in params.keyMap) {
      if (params.keysDown[keyCode]) {
        var value = params.keyMap[keyCode];
        if (_.isString(value) && value.length > 0 && (value[0] == '+' || value[0] == '-')) {
          params.parameter += Number(value);
        } else {
          params.parameter = value;
        }
        break;
      }
    }'''

clickListener =
  text: 'clickListener'
  type: 'action'
  source:
    paramDefs:
      boxedPieces: { direction: 'inout' }
      constants: { direction: 'in' }
      draggedPiece: { direction: 'inout' }
      keyboard: { direction: 'in' }
      leftMouseDown: { direction: 'inout', default: false }
      mouse: { direction: 'in' }
      originalPieceRotation: { direction: 'inout' }
      originalRotation: { direction: 'inout' }
      pieces: { direction: 'inout' }
      rotating: { direction: 'inout', default: false }
      selected: { direction: 'inout' }
      selectedPiece: { direction: 'inout' }
      rotating: { direction: 'out', default: '{}' }
    update: '''var that = this;
      function selectSquare(square, params) {
        if (that.tools.isInGrid(square, that.params.constants.gridSize)) {
          params.selected = {
            col: square[0],
            row: square[1]
          };
        }
      }
      function mouseDownOnPiece(piecePressed, params) {
        if (piecePressed) {
          params.selectedPiece = null;
          params.rotating = false;
          params.originalRotation = null;
          params.originalPieceRotation = null;
          if (that.tools.isMovable(piecePressed, that.params.constants.unmovablePieces)) {
            params.draggedPiece = piecePressed;
          }
        }
      }
      var newLeftMouseDown = params.mouse.down && !params.leftMouseDown;
      var newLeftMouseReleased = !params.mouse.down && params.leftMouseDown;
      var selected = params.selected;
      if (params.rotating && params.selectedPiece && params.mouse.position) {
        if (params.originalPieceRotation === null) {
          params.originalPieceRotation = params.selectedPiece.rotation;
        }
        var objectPosition = {};
        objectPosition.x = (params.selectedPiece.col + 0.5) * (params.constants.cellSize - 1) + params.constants.upperLeftBoardMargin;
        objectPosition.y = (params.selectedPiece.row + 0.5) * (params.constants.cellSize - 1) + params.constants.upperLeftBoardMargin;
        var hxPosition = params.mouse.position[0] - objectPosition.x;
        var hyPosition = params.mouse.position[1] - objectPosition.y;
        var omDistance = Math.sqrt(hxPosition * hxPosition + hyPosition * hyPosition);
        var ohyDistance = -hyPosition;
        var ratio = ohyDistance / omDistance;
        var angle = 0;
        if (omDistance !== 0) {
          var absValueAngle = Math.acos(ratio) * 180 / Math.PI;
          if (hxPosition <= 0) {
            angle = -absValueAngle;
          } else {
            angle = absValueAngle;
          }
        }
        if (params.originalRotation === null) {
          params.originalRotation = angle;
        }
        var piece = tools.findGridElement([
            params.selectedPiece.col,
            params.selectedPiece.row
          ], params.pieces);
        var newRotation = angle - params.originalRotation + params.originalPieceRotation;
        piece.rotation = newRotation % 360;
      }
      if (newLeftMouseDown || newLeftMouseReleased) {
        if (that.params.mouse.position) {
          var clickedColumn = tools.toBoardCoordinate(that.params.mouse.position[0], params.constants.upperLeftBoardMargin, params.constants.cellSize);
          var clickedRow = tools.toBoardCoordinate(that.params.mouse.position[1], params.constants.upperLeftBoardMargin, params.constants.cellSize);
          var boardCoordinates = [
              clickedColumn,
              clickedRow
            ];
          if (newLeftMouseDown) {
            params.leftMouseDown = true;
            if (!tools.isInGrid(boardCoordinates, params.constants.gridSize)) {
              var boxIndex = tools.getIndexInBox([
                  that.params.mouse.position[0],
                  that.params.mouse.position[1]
                ], params.constants.boxLeft, params.constants.boxTop, params.constants.boxCellSize, params.constants.boxRowsCount, params.constants.boxColumnsCount);
              if (boxIndex !== null) {
                var boxedPiece = params.boxedPieces[boxIndex];
                var pieceType = null;
                if (boxedPiece) {
                  pieceType = boxedPiece.type;
                  mouseDownOnPiece(boxedPiece, params);
                } else if (params.selectedPiece != null) {
                  params.selectedPiece = null;
                  params.rotating = false;
                  params.originalRotation = null;
                  params.originalPieceRotation = null;
                } else {
                }
              }
            } else {
              var pieceClickedOn = tools.findGridElement(boardCoordinates, params.pieces);
              if (params.selectedPiece) {
                var selectedPiecePosition = {};
                selectedPiecePosition.x = tools.toPixelCoordinate(params.selectedPiece.col, params.constants.upperLeftBoardMargin, params.constants.cellSize);
                selectedPiecePosition.y = tools.toPixelCoordinate(params.selectedPiece.row, params.constants.upperLeftBoardMargin, params.constants.cellSize);
                if (tools.distance(params.mouse.position, selectedPiecePosition) < params.constants.cellSize * 1.2 && tools.distance(params.mouse.position, selectedPiecePosition) > params.constants.cellSize * 0.7) {
                  params.rotating = true;
                  var rotatedPiece = tools.findGridElement([
                      params.selectedPiece.col,
                      params.selectedPiece.row
                    ], params.pieces);
                  params.originalPieceRotation = 0;
                  if (rotatedPiece)
                    params.originalPieceRotation = rotatedPiece.rotation;
                } else {
                  mouseDownOnPiece(pieceClickedOn, params);
                  selectSquare([
                    clickedColumn,
                    clickedRow
                  ], params);
                }
              } else {
                mouseDownOnPiece(pieceClickedOn, params);
                selectSquare([
                  clickedColumn,
                  clickedRow
                ], params);
              }
            }
          } else if (newLeftMouseReleased) {
            params.leftMouseDown = false;
            if (!tools.isInGrid(boardCoordinates, params.constants.gridSize)) {
              var boxIndex = tools.getIndexInBox([
                  that.params.mouse.position[0],
                  that.params.mouse.position[1]
                ], params.constants.boxLeft, params.constants.boxTop, params.constants.boxCellSize, params.constants.boxRowsCount, params.constants.boxColumnsCount);
              if (boxIndex !== null) {
                var boxedPiece = params.boxedPieces[boxIndex];
                var pieceType = null;
                if (boxedPiece !== undefined) {
                  params.draggedPiece = null;
                } else {
                  if (params.selectedPiece) {
                  } else if (params.draggedPiece) {
                    var put = tools.putPieceIntoBox(that.params.draggedPiece, params.pieces, params.boxedPieces);
                    params.pieces = put.pieces;
                    params.boxedPieces = put.boxedPieces;
                    params.draggedPiece = null;
                    params.selectedPiece = null;
                    params.rotating = false;
                    params.originalRotation = null;
                    params.originalPieceRotation = null;
                  } else {
                  }
                }
              } else {
                var put = tools.putPieceIntoBox(that.params.draggedPiece, params.pieces, params.boxedPieces);
                params.pieces = put.pieces;
                params.boxedPieces = put.boxedPieces;
                params.draggedPiece = null;
                params.selectedPiece = null;
                params.rotating = false;
                params.originalRotation = null;
                params.originalPieceRotation = null;
              }
            } else {
              var pieceReleasedOn = tools.findGridElement(boardCoordinates, params.pieces);
              if (pieceReleasedOn) {
                if (params.draggedPiece && params.draggedPiece.col == boardCoordinates[0] && params.draggedPiece.row == boardCoordinates[1]) {
                  params.selectedPiece = pieceReleasedOn;
                } else if (!params.draggedPiece && !params.selectedPiece) {
                  params.selectedPiece = pieceReleasedOn;
                } else {
                  params.selectedPiece = null;
                  params.rotating = false;
                  params.originalRotation = null;
                  params.originalPieceRotation = null;
                }
                params.draggedPiece = null;
              } else {
                if (params.selectedPiece) {
                  if (params.rotating) {
                    params.rotating = false;
                    params.originalRotation = null;
                    params.originalPieceRotation = null;
                  } else {
                    params.selectedPiece = null;
                    params.rotating = false;
                    params.originalRotation = null;
                    params.originalPieceRotation = null;
                  }
                } else if (params.draggedPiece) {
                  selectSquare([
                    clickedColumn,
                    clickedRow
                  ], params);
                  var move = tools.movePieceTo(params.draggedPiece, [
                      clickedColumn,
                      clickedRow
                    ], params.pieces, params.boxedPieces, params.constants.gridSize, params.constants.unmovablePieces);
                  _.extend(params, move);
                } else {
                }
              }
            }
          }
        }
      }'''

detectMouse =
  text: 'detectMouse'
  type: 'action'
  source:
    update:'for (var keyCode in params.keyMap) {\n  if (params.keysDown[keyCode]) {\n    var value = params.keyMap[keyCode];\n    if (_.isString(value) && value.length > 0 && (value[0] == '+' || value[0] == '-')) {\n      params.parameter += Number(value);\n    } else {\n      params.parameter = value;\n    }\n    break;\n  }\n}'
    paramDefs:
      dragStartPosition: { direction: 'inout' }
      minimumDragDistance: { default: '5' }
      mouseDown: null
      mousePosition: null
      shape: { direction: 'inout' }
      shapes: null
      state: { direction: 'inout' }
    update: '''if (!params.state)
        params.state = 'none';
      switch (params.state) {
      case 'none':
        if (params.mousePosition) {
          for (var i in params.shapes) {
            if (tools.pointIntersectsShape(params.mousePosition, params.shapes[i])) {
              log(GE.logLevels.INFO, 'Entering hover mode. Old state = ' + params.state);
              params.state = 'hover';
              params.shape = params.shapes[i];
              break;
            }
          }
        }
        break;
      case 'hover':
        if (!params.mousePosition || !tools.pointIntersectsShape(params.mousePosition, params.shape)) {
          params.state = 'none';
          params.shape = null;
          log(GE.logLevels.INFO, 'Leaving hover mode');
        } else if (params.mouseDown) {
          params.dragStartPosition = params.mousePosition;
          params.state = 'pressed';
          log(GE.logLevels.INFO, 'Entering presed mode');
        }
        break;
      case 'pressed':
        if (!params.mouseDown) {
          params.state = 'click';
          params.dragStartPosition = null;
          log(GE.logLevels.INFO, 'Leaving pressed mode');
        } else if (Vector.create(params.dragStartPosition).distanceFrom(Vector.create(params.mousePosition)) >= params.minimumDragDistance) {
          params.state = 'startDrag';
          params.dragStartPosition = null;
          log(GE.logLevels.INFO, 'Entering drag mode');
        }
        break;
      case 'click':
        params.state = 'hover';
        break;
      case 'startDrag':
        params.state = 'drag';
        break;
      case 'drag':
        if (!params.mouseDown) {
          params.state = 'endDrag';
          params.dragStartPosition = null;
          log(GE.logLevels.INFO, 'Leaving drag mode');
        }
        break;
      case 'endDrag':
        params.state = 'hover';
        break;
      default:
        throw new Error('Unknown state \'' + params.state + '\'');
      }'''

angular.module('gamEvolve.model.defaultActions', [])

.factory 'defaultActions', ->

  list: [
    changeParameterThroughKeyboard
    clickListener
    detectMouse
  ]