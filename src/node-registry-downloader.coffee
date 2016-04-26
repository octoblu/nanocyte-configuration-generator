_       = require 'lodash'
request = require 'request'

class NodeRegistryDownloader
  constructor: ->
    @cached = false
    @etag = null
    @data = null
    @_checkEtag = _.throttle @_checkEtagImmediately, 60*1000*5, leading: true, trailing: false

  setOptions: ({@registryUrl}) =>

  update: (callback) =>
    @_checkEtag()
    return callback null, @data if @cached

    request.get @registryUrl, json: true, (error, response, @data) =>
      return callback error if error?
      @etag = response.headers.etag
      @cached = true
      callback null, @data

  _checkEtagImmediately: =>
    request.head @registryUrl, json: true, (error, response) =>
      return if error?
      return if @etag == response.headers.etag
      @etag = response.headers.etag
      @cached = false

module.exports = NodeRegistryDownloader
