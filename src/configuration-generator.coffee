_ = require 'lodash'
VIRTUAL_NODES =
  'meshblu-input':
    config: {}
    data: {}
  'meshblu-output':
    config: {}
    data: {}
  'start':
    config: {}
    data: {}
  'stop':
    config: {}
    data: {}

class ConfigurationGenerator
  constructor: (@flow) ->

  setupRouter: (flowNodes) =>
    router:
      config: @buildLinks flowNodes

  buildLinks: (flowNodes) =>
    _.mapValues flowNodes, (nodeConfig) =>
      links = _.filter @flow.links, from: nodeConfig.config?.id
      linkedTo = _.pluck links, 'to'

      linkedTo = ['meshblu-output'] if nodeConfig.config?.class == 'debug'

      type: "nanocyte-node-#{nodeConfig.config?.class}"
      linkedTo: linkedTo

  configure: (callback=->) =>
    flowNodes = _.indexBy @flow.nodes, 'id'
    flowConfig = _.mapValues flowNodes, (nodeConfig) =>
      config: nodeConfig
      data: {}
    flowConfig = _.assign flowConfig, @setupRouter(flowConfig)
    flowConfig = _.assign flowConfig, VIRTUAL_NODES
    callback null, flowConfig

module.exports = ConfigurationGenerator
