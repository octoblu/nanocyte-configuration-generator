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
  constructor: (@meshbluJSON={}, dependencies={}) ->
    {@UUID} = dependencies
    @UUID ?= require 'node-uuid'

  configure: (flow, token, callback=->) =>
    virtualNodes = _.cloneDeep(VIRTUAL_NODES)
    virtualNodes['meshblu-output'].config = _.extend {}, @meshbluJSON, uuid: flow.flowId, token: token
    flowNodes = _.indexBy flow.nodes, 'id'
    flowConfig = _.mapValues flowNodes, (nodeConfig) =>
      config: nodeConfig
      data: {}
    flowConfig = _.assign flowConfig, @_setupRouter(flow, flowConfig)
    flowConfig = _.assign flowConfig, virtualNodes
    callback null, flowConfig

  _setupRouter: (flow, flowNodes) =>
    router:
      config: @_buildLinks flow.links, flowNodes

  _buildLinks: (links, flowNodes) =>
    flowNodeMap = {}
    result = {}
    _.each flowNodes, (nodeConfig, nodeUuid) =>
      config = nodeConfig.config ? {}
      nanocyteConfig = config.nanocyte ? {}
      composedOf = nanocyteConfig.composedOf ? {}

      _.each composedOf, (template, templateId) =>
        instanceId = @UUID.v1()
        composedConfig = _.cloneDeep template
        composedConfig.nodeUuid = nodeUuid
        composedConfig.templateId = templateId
        composedConfig.debug = config.debug
        flowNodeMap[instanceId] = composedConfig

    _.each flowNodeMap, (config, instanceId) =>
      nodeLinks = _.filter links, from: config.nodeUuid
      templateLinks = config.linkedTo
      linkedTo = []
      if config.linkedToNext
        linkUuids = _.pluck nodeLinks, 'to'
        _.each flowNodeMap, (data, key) =>
          if _.contains linkUuids, data.nodeUuid
            linkedTo.push key

      _.each config.linkedTo, (templateLinkId) =>
        _.each flowNodeMap, (data, key) =>
          if data.nodeUuid == config.nodeUuid && data.templateId == templateLinkId
            linkedTo.push key

      linkedTo.push 'engine-output', 'engine-pulse' if config.linkedToOutput
      linkedTo.push 'engine-data' if config.linkedToData
      linkedTo.push 'engine-debug' if config.debug

      result[instanceId] =
        type: config.type
        linkedTo: linkedTo
    result

module.exports = ConfigurationGenerator
