require 'blockscore/dispatcher'
require 'blockscore/util'
require 'blockscore/errors/api_error'
require 'blockscore/errors/authentication_error'
require 'blockscore/errors/error'
require 'blockscore/errors/invalid_request_error'

module BlockScore
  module Responder
    def handle_response(response)
      case response.code
      when 200, 201
        BlockScore::Dispatcher.new(resource, response).call
      else
        api_error response
      end
    end

    private

    def api_error(response)
      obj = Util.parse_json(response.body)

      case response.code
      when 400, 404
        fail InvalidRequestError.new(obj, response.code)
      when 401
        fail AuthenticationError.new(obj, response.code)
      else
        fail APIError.new(obj, response.code)
      end
    end
  end
end
