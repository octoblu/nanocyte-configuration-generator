_ = require 'lodash'

class ConfigurationUtilities
  constructor: (@config) ->

  findNanocytesByType: (type) =>
    nanocytes = []
    _.each @config, (nanocyte, id) ->
      return true unless nanocyte.type == type
      nanocytes.push {nanocyte, id}

    return nanocytes

  findLinkedToNanocytes: (id) =>
    return _.filter @config, (nanocyte) => _.contains nanocyte.linkedTo, id

module.exports = ConfigurationUtilities
