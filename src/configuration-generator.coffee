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
  configure: (flow, callback=->) =>
    flowNodes = _.indexBy flow.nodes, 'id'
    flowConfig = _.mapValues flowNodes, (nodeConfig) =>
      config: nodeConfig
      data: {}
    flowConfig = _.assign flowConfig, @_setupRouter(flow, flowConfig)
    flowConfig = _.assign flowConfig, VIRTUAL_NODES
    callback null, flowConfig

  _setupRouter: (flow, flowNodes) =>
    router:
      config: @_buildLinks flow.links, flowNodes

  _buildLinks: (links, flowNodes) =>
    _.mapValues flowNodes, (nodeConfig) =>
      nodeLinks = _.filter links, from: nodeConfig.config?.id
      linkedTo = _.pluck nodeLinks, 'to'

      linkedTo = ['meshblu-output'] if nodeConfig.config?.class == 'debug'

      type: "nanocyte-node-#{nodeConfig.config?.class}"
      linkedTo: linkedTo


module.exports = ConfigurationGenerator
