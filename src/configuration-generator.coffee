_ = require 'lodash'
VIRTUAL_NODES =
  'meshblu-input': { }
  'meshblu-output': { }
  'start': { }
  'stop': { }
  'router': { }

class ConfigurationGenerator
  constructor: (@flow) ->

  configure: (callback=->) =>
    flowConfig = _.indexBy @flow.nodes, 'id'
    flowConfig = _.assign flowConfig, VIRTUAL_NODES
    callback null, flowConfig

module.exports = ConfigurationGenerator
