class ShinseiBank
  class Request
    URL = "https://pdirect04.shinseibank.com/FLEXCUBEAt/LiveConnect.dll".freeze
    USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 5.1;) PowerDirectBot/0.1".freeze

    attr_reader :type, :data, :response

    def initialize(type, data = {})
      unless client.respond_to?(type)
        raise ArgumentError, "Invalid request type: #{type}"
      end
      @type = type
      @data = data
    end

    def perform
      Response.new(client.public_send(type, URL, encoded_data))
    end

    private

      def client
        @_client ||= HTTPClient.new(agent_name: USER_AGENT)
      end

      def encoded_data
        data.map do |pair|
          pair.map do |value|
            value.dup.to_s.force_encoding(Encoding::ASCII_8BIT)
          end
        end.to_h
      end
  end
end
