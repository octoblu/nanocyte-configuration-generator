module.exports = {
  "trigger":
    "composedOf":
      "Trigger":
        "type": "nanocyte-node-trigger"
        "linkedToInput": true
        "linkedToNext": true
  "debug":
    "composedOf":
      "Debug":
        "type": "nanocyte-node-debug"
        "linkedToPrev": true
  "interval":
    "composedOf":
      "Interval-1":
        "type": "nanocyte-node-interval"
        "linkedToInput": true
        "linkedToNext": true
  "device":
    "composedOf":
      "pass-through":
        "type": "nanocyte-component-pass-through"
        "linkedToInput": true
        "linkedToNext": true
  "channel":
    "composedOf":
      "pass-through":
        "type": "nanocyte-component-channel"
        "linkedToPrev": true
        "linkedToNext": true
      "stopper":
        "type": "node-component-unregister"
        "linkedFromStop": true
  "flow-metrics":
    "composedOf":
      "pass-through":
        "type": "nanocyte-component-flow-metrics-start"
        "linkedFromStart": true
        "linkedToOutput": true
  "get-key":
    "composedOf":
      "http-formatter":
        "type": "nanocyte-component-http-formatter"
        "linkedToPrev": true
        "linkedToNext": true
  "set-key":
    "composedOf":
      "http-formatter":
        "type": "nanocyte-component-http-formatter"
        "linkedToPrev": true
        "linkedToNext": true

}
