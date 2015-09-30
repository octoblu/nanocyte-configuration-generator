_ = require 'lodash'
debug = require('debug')('nanocyte-configuration-generator')
ChannelConfig = require './channel-config'

DEFAULT_REGISTRY_URL = 'https://raw.githubusercontent.com/octoblu/nanocyte-node-registry/master/registry.json'
METRICS_DEVICE_ID = 'f952aacb-5156-4072-bcae-f830334376b1'

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
  'engine-start':
    config: {}
    data: {}
  'engine-stop':
    config: {}
    data: {}

class ConfigurationGenerator
  constructor: (options, dependencies={}) ->
    {@registryUrl, @meshbluJSON, @metricsDeviceId} = options
    @registryUrl ?= DEFAULT_REGISTRY_URL
    @metricsDeviceId ?= METRICS_DEVICE_ID

    {@UUID, @request, @channelConfig} = dependencies
    @UUID    ?= require 'node-uuid'
    @request ?= require 'request'
    @channelConfig ?= new ChannelConfig
      accessKeyId:     options.accessKeyId
      secretAccessKey: options.secretAccessKey

  configure: (options, callback=->) =>
    {flowData, flowToken, userData, deploymentUuid} = options

    debug 'configuring flow...', flowData

    debug 'fetching registry'
    @channelConfig.fetch (error) =>
      return callback error if error?

      @_getNodeRegistry (error, nodeRegistry) =>
        return callback error if error?
        debug 'fetched registry', nodeRegistry

        flowMetricNode =
          id: @UUID.v4()
          category: 'flow-metrics'
          flowUuid: flowData.flowId
          deviceId: @metricsDeviceId
          deploymentUuid: deploymentUuid

        flowData.nodes.push flowMetricNode

        flowNodes = _.indexBy flowData.nodes, 'id'

        flowConfig = _.mapValues flowNodes, (nodeConfig) =>
          config: nodeConfig
          data: {}

        flowConfig = _.assign flowConfig, _.cloneDeep(VIRTUAL_NODES)
        instanceMap = @_generateInstances flowData.links, flowConfig, nodeRegistry, userData

        _.each instanceMap, (instanceConfig, instanceId) =>
          {config,data} = flowConfig[instanceConfig.nodeUuid]

          oauthConfig = @_ohThatOauth userData, _.cloneDeep(config)
          config = _.defaultsDeep {}, config, oauthConfig

          flowConfig[instanceId] = {config: config, data: data}

        links = @_buildLinks(flowData.links, instanceMap)
        flowConfig.router.config = links

        flowConfig['engine-data'].config  = @_buildNodeMap instanceMap
        flowConfig['engine-pulse'].config = @_buildNodeMap instanceMap
        flowConfig['engine-debug'].config = @_buildNodeMap instanceMap
        flowConfig['engine-input'].config = @_buildMeshblutoNodeMap flowConfig, instanceMap
        flowConfig['engine-output'].config = _.extend {}, @meshbluJSON, uuid: flowData.flowId, token: flowToken


        flowStopConfig = _.cloneDeep flowConfig
        delete flowStopConfig['engine-input']
        flowStopConfig['router']['config'] = _.pick flowConfig['router']['config'], 'engine-stop', 'engine-output'

        callback null, flowConfig, flowStopConfig

  _buildNodeMap: (flowNodeMap) =>
    _.mapValues flowNodeMap, (flowNode) =>
      nodeId: flowNode.nodeUuid

  _buildMeshblutoNodeMap: (flowConfig, instanceMap) =>
    inputInstances = _.where instanceMap, linkedToInput: true

    nodeMap = {}
    _.each inputInstances, (instance) =>
      nodeConfig = flowConfig[instance.nodeUuid]
      nodeMap[nodeConfig.config.uuid] ?= []
      nodeMap[nodeConfig.config.uuid].push {nodeId: instance.nodeUuid}
    return nodeMap

  _generateInstances: (links, flowNodes, nodeRegistry, userData) =>
    flowNodeMap = {}
    _.each flowNodes, (nodeConfig, nodeUuid) =>
      config = nodeConfig.config ? {}
      nanocyteConfig = config.nanocyte ? {}

      type = config.category
      type = config.type.replace('operation:', '') if type == 'operation'
      nodeFromRegistry = nodeRegistry[type] ? {}

      composedOf = nodeFromRegistry.composedOf ? {}

      _.each composedOf, (template, templateId) =>
        instanceId = @UUID.v4()
        composedConfig = _.cloneDeep template
        composedConfig.nodeUuid = nodeUuid
        composedConfig.templateId = templateId
        composedConfig.debug = config.debug

        flowNodeMap[instanceId] = composedConfig

    return flowNodeMap

  _getNodeRegistry: (callback) =>
    @request.get @registryUrl, json: true, (error, response, nodeRegistry) =>
      callback error, nodeRegistry

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

  _ohThatOauth: (userData, template) =>
    userApiMatch = _.findWhere(userData.api, type: template.type)
    return {} unless userApiMatch?

    channelApiMatch = @channelConfig.get template.type
    return {} unless channelApiMatch?

    channelConfig = _.pick channelApiMatch,
      'bodyFormat'
      'followAllRedirects'
      'skipVerifySSL'
      'hiddenParams'
      'auth_header_key'
      'bodyParams'

    config = _.defaults {}, template, channelConfig

    # if userApiMatch.token_crypt
    #   userApiMatch.secret = textCrypt.decrypt userApiMatch.secret_crypt
    #   userApiMatch.token  = textCrypt.decrypt userApiMatch.token_crypt

    config.apikey = userApiMatch.apikey

    userToken = userApiMatch.token ? userApiMatch.key

    userOAuth =
      access_token: userToken
      access_token_secret: userApiMatch.secret
      refreshToken: userApiMatch.refreshToken
      expiresOn: userApiMatch.expiresOn
      defaultParams: userApiMatch.defaultParams

    channelOauth =  channelApiMatch.oauth?[process.env.NODE_ENV]
    channelOauth ?= channelApiMatch.oauth
    channelOauth ?= {tokenMethod: channelApiMatch.auth_strategy}

    config.oauth = _.defaults {}, userOAuth, template.oauth, channelOauth

    if channelApiMatch.overrides
      config.headerParams = _.extend {}, template.headerParams, channelApiMatch.overrides.headerParams

    config.oauth.key ?= config.oauth.clientID
    config.oauth.key ?= config.oauth.consumerKey

    config.oauth.secret ?= config.oauth.clientSecret
    config.oauth.secret ?= config.oauth.consumerSecret

    return JSON.parse JSON.stringify config # removes things that are undefined

module.exports = ConfigurationGenerator
