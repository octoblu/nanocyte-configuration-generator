debug = require('debug')('nanocyte-configuration-generator')
_ = require 'lodash'

REGISTRY_URL = 'https://raw.githubusercontent.com/octoblu/nanocyte-node-registry/master/registry.json'
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
    debug 'configuring flow...', flow
    virtualNodes = _.cloneDeep(VIRTUAL_NODES)
    virtualNodes['engine-output'].config = _.extend {}, @meshbluJSON, uuid: flow.flowId, token: token
    flowNodes = _.indexBy flow.nodes, 'id'
    debug 'flowNodes', flowNodes

    flowConfig = _.mapValues flowNodes, (nodeConfig) =>
      config: nodeConfig
      data: {}

    flowConfig = _.assign flowConfig, virtualNodes
    instanceMap = @_generateInstances flow.links, flowConfig

    _.each instanceMap, (config, instanceId) =>
      flowConfig[instanceId] = flowConfig[config.nodeUuid]

    links = @_buildLinks(flow.links, instanceMap)
    flowConfig.router.config = links

    flowConfig['engine-data'].config  = @_buildNodeMap instanceMap
    flowConfig['engine-pulse'].config = @_buildNodeMap instanceMap
    flowConfig['engine-debug'].config = @_buildNodeMap instanceMap

    _.defer =>
      callback null, flowConfig

  _buildNodeMap: (flowNodeMap) =>
    _.mapValues flowNodeMap, (flowNode) =>
      nodeId: flowNode.nodeUuid

  _generateInstances: (links, flowNodes, nodeRegistry) =>
    flowNodeMap = {}
    _.each flowNodes, (nodeConfig, nodeUuid) =>
      config = nodeConfig.config ? {}
      nanocyteConfig = config.nanocyte ? {}
      nodeFromRegistry = nodeRegistry[config.class] ? {}
      composedOf = nodeFromRegistry.composedOf ? {}

      _.each composedOf, (template, templateId) =>
        instanceId = @UUID.v1()
        composedConfig = _.cloneDeep template
        composedConfig.nodeUuid = nodeUuid
        composedConfig.templateId = templateId
        composedConfig.debug = config.debug

        flowNodeMap[instanceId] = composedConfig
    return flowNodeMap

  _buildLinks: (links, flowNodeMap) =>
    debug 'building links with', links
    result = {}
    _.each flowNodeMap, (config, instanceId) =>
      nodeLinks = _.filter links, from: config.nodeUuid
      templateLinks = config.linkedTo
      linkedTo = []

      if config.linkedToInput
        result[config.nodeUuid] ?=
          type: 'engine-input'
          linkedTo: []
        result[config.nodeUuid].linkedTo.push instanceId

      if config.linkedFromStart
        result['engine-start'] ?=
          type: 'engine-start'
          linkedTo: []
        result['engine-start'].linkedTo.push instanceId

      if config.linkedFromStop
        result['engine-stop'] ?=
          type: 'engine-stop'
          linkedTo: []
        result['engine-stop'].linkedTo.push instanceId

      if config.linkedToNext
        linkUuids = _.pluck nodeLinks, 'to'
        _.each flowNodeMap, (data, key) =>
          if _.contains linkUuids, data.nodeUuid
            linkedTo.push key if data.linkedToPrev

      _.each config.linkedTo, (templateLinkId) =>
        _.each flowNodeMap, (data, key) =>
          if data.nodeUuid == config.nodeUuid && data.templateId == templateLinkId
            linkedTo.push key

      linkedTo.push 'engine-output' if config.linkedToOutput
      linkedTo.push 'engine-pulse' if config.linkedToNext || config.linkedToPulse || config.linkedToOutput
      linkedTo.push 'engine-data' if config.linkedToData
      linkedTo.push 'engine-debug' if config.debug

      result[instanceId] =
        type: config.type
        linkedTo: linkedTo

    result['engine-output'] =
      type: 'engine-output'
      linkedTo: []
    result['engine-debug'] =
      type: 'engine-debug'
      linkedTo: []
    result['engine-pulse'] =
      type: 'engine-pulse'
      linkedTo: []
    result['engine-data'] =
      type: 'engine-data'
      linkedTo: []

    debug 'router config is', result

    return result

module.exports = ConfigurationGenerator
