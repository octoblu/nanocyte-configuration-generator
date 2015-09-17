_ = require 'lodash'

VIRTUAL_NODES =
  'engine-input':
    config: {}
    data: {}
  'engine-output':
    config: {}
    data: {}
  'engine-data':
    config: {}
    data: {}
  'engine-debug':
    config: {}
    data: {}
  'engine-pulse':
    config: {}
    data: {}
  'router':
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
    virtualNodes['engine-output'].config = _.extend {}, @meshbluJSON, uuid: flow.flowId, token: token
    flowNodes = _.indexBy flow.nodes, 'id'
    flowConfig = _.mapValues flowNodes, (nodeConfig) =>
      config: nodeConfig
      data: {}

    flowConfig = _.assign flowConfig, virtualNodes
    flowConfig.router.config = @_buildLinks(flow.links, flowConfig)
    _.defer =>
      callback null, flowConfig

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

        if composedConfig.linkedToInput
          result[nodeUuid] ?=
            type: 'engine-input'
            linkedTo: []
          result[nodeUuid].linkedTo.push instanceId

        flowNodeMap[instanceId] = composedConfig

    _.each flowNodeMap, (config, instanceId) =>
      nodeLinks = _.filter links, from: config.nodeUuid
      templateLinks = config.linkedTo
      linkedTo = []
      if config.linkedToNext
        linkUuids = _.pluck nodeLinks, 'to'
        _.each flowNodeMap, (data, key) =>
          if _.contains linkUuids, data.nodeUuid
            linkedTo.push key if data.linkedToPrev

      _.each config.linkedTo, (templateLinkId) =>
        _.each flowNodeMap, (data, key) =>
          if data.nodeUuid == config.nodeUuid && data.templateId == templateLinkId
            linkedTo.push key

      linkedTo.push 'engine-output', 'engine-pulse' if config.linkedToOutput
      linkedTo.push 'engine-pulse' if config.linkedToNext
      linkedTo.push 'engine-data' if config.linkedToData
      linkedTo.push 'engine-debug' if config.debug

      result[instanceId] =
        type: config.type
        linkedTo: linkedTo

    @_addBlankVirtualNodesToRoutes result

    result

  _addBlankVirtualNodesToRoutes: (config) =>
    config['engine-output'] =
      type: 'engine-output'
      linkedTo: []
    config['engine-debug'] =
      type: 'engine-debug'
      linkedTo: []
    config['engine-pulse'] =
      type: 'engine-pulse'
      linkedTo: []
    config['engine-data'] =
      type: 'engine-data'
      linkedTo: []
    config


module.exports = ConfigurationGenerator
