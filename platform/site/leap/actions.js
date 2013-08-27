({
  doInParallel: { 
    doc: "Just to place children under it"
  },

  changeParameterThroughKeyboard: {
    paramDefs: {
      "parameter": { direction: "inout" },
      "keysDown": null,
      "keyMap": null // Keymap must be in a form like { "37": "-10", "39": 3, "41": "hello" }
    },
    update: function() {
      for(var keyCode in this.params.keyMap)
      {
        // is the key down?
        if(this.params.keysDown[keyCode])
        {
          // Parse value of keyMap
          var value = this.params.keyMap[keyCode];
          if(_.isString(value) && value.length > 0 && (value[0] == "+" || value[0] == "-")) 
          {
            // Treat it as a numerical difference
            this.params.parameter += Number(value);
          }
          else
          {
            this.params.parameter = value;
          }
          // only treat a single keycode
          break;
        }
      } 
    }
  },

  doInSequence: {
    paramDefs: {
      activeChild: { direction: "inout", default: 0 },
    },
    listActiveChildren: function() { return [this.params.activeChild]; },
    handleSignals: function() { 
      if(this.signals[this.params.activeChild] == GE.signals.DONE)
        this.params.activeChild++;

      if(this.params.activeChild > this.children.length - 1)
      {
        this.params.activeChild = 0;
        return GE.signals.DONE;
      }
    } 
  },

  doForSomeTime: {
    paramDefs: {
      time: null,
      timer: { direction: "inout" }
    },
    update: function() { 
      if(this.params.timer++ >= this.params.time) {
        this.params.timer = 0;
        return GE.signals.DONE;
      }
    }
  },

  doWhile: {
    paramDefs: {
      value: null
    },
    update: function() { 
      if(!this.params.value) return GE.signals.DONE;
    }
  },

  when: {
    paramDefs: {
      value: null
    },
    listActiveChildren: function() { 
      return this.tools.childByName(this.children, this.params.value);
    }
  },

  // Selects the first branch if the expression is truthy, else the second (if it exists)
  "if": {
    paramDefs: {
      value: null
    },
    listActiveChildren: function() { 
      return this.params.value ? [0] : this.children.length > 1 ? [1] : []; 
    }
  },

  sandwich: {
    paramDefs: {
      condition: null,
      started: { direction: "inout" }
    },
    listActiveChildren: function() { 
      if(!this.params.track)
      {
        if(!this.params.condition) {
          return [0];
        } else {
          this.params.track = true;
          return [1];
        }
      } else {
        if(this.params.condition) {
          return [1];
        } else {
          this.params.track = false;
          return [2];
        }
      }
    }
  },

  detectMouse: {
    paramDefs: {
      "shapes": null,
      "shape": { direction: "inout" },
      "mousePosition": null,
      "mouseDown": null,
      "state": { direction: "inout" },
      "dragStartPosition": { direction: "inout" },
      "minimumDragDistance": { default: "5" }
    },
    update: function() { 
      // Implement a state machine, starting at the "none" state
      if(!this.params.state) this.params.state = "none";

      //this.log(GE.logLevels.INFO, "shapes", this.params.shapes);

      switch(this.params.state) {
        case "none":
          if(this.params.mousePosition) {
            for(var i in this.params.shapes) {
              if(this.tools.pointIntersectsShape(this.params.mousePosition, this.params.shapes[i])) {
                this.log(GE.logLevels.INFO, "Entering hover mode. Old state = " + this.params.state);
                this.params.state = "hover";
                this.params.shape = this.params.shapes[i];
                break;
              }
            }
          } 
          break;
        case "hover":
          if(!this.params.mousePosition || !this.tools.pointIntersectsShape(this.params.mousePosition, this.params.shape)) {
            this.params.state = "none";
            this.params.shape = null;
            this.log(GE.logLevels.INFO, "Leaving hover mode")
          } else if(this.params.mouseDown) {
            this.params.dragStartPosition = this.params.mousePosition;
            this.params.state = "pressed";
            this.log(GE.logLevels.INFO, "Entering presed mode")
          }
          break;
        case "pressed":
          if(!this.params.mouseDown) {
            this.params.state = "click";
            this.params.dragStartPosition = null;
            this.log(GE.logLevels.INFO, "Leaving pressed mode")
          } else if(Vector.create(this.params.dragStartPosition).distanceFrom(Vector.create(this.params.mousePosition)) >= this.params.minimumDragDistance) {
            this.params.state = "startDrag";
            this.params.dragStartPosition = null;
            this.log(GE.logLevels.INFO, "Entering drag mode")
          }
          break;
        case "click":
          this.params.state = "hover";
          break;
        case "startDrag":
          this.params.state = "drag";
          break;
        case "drag":
          if(!this.params.mouseDown) {
            this.params.state = "endDrag";
            this.params.dragStartPosition = null;
            this.log(GE.logLevels.INFO, "Leaving drag mode")
          }
          break;
        case "endDrag":
          this.params.state = "hover";
          break;
        default:
          throw new Error("Unknown state '" + this.params.state + "'");
      }
    }
  },

  updateHtmlForm: {
    paramDefs: {
      "htmlService": { direction: "inout" },
      "modelValues": { direction: "inout" },
      "assetName": null,
      "formName": null
    },
    update: function() { 
      if(!this.params.htmlService.in[this.params.formName]) {
        // If the form does not exist in the service, use the model values as a default
        this.params.htmlService.out[this.params.formName] = { asset: this.params.assetName, values: this.params.modelValues };
      } else {
        // Otherwise update the model from what the service provides, and then re-stablish the form
        this.params.modelValues = this.params.htmlService.in[this.params.formName].values;
        this.params.htmlService.out[this.params.formName] = this.params.htmlService.in[this.params.formName]
      }
    }
  }

});
