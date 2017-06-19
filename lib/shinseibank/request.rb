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
      @response = client.public_send(type, URL, data)
      response_data
    end

    def response_data
      js_code_match = body.lines.first.
        match(/(?<=<script language="JavaScript">).*(?=<\/script>)/)

      return {} unless js_code_match

      js_code_match[0].to_enum(:scan, (/(\w+)(?:\[(\d+)\])?=(.*?)(?=;)/)).
        inject({}) do |data|

        key, index, value = Regexp.last_match.captures

        value = parse_value(value)

        if index
          data[key] ||= []
          data[key][index.to_i] = value
        else
          data[key] = value
        end

        data
      end
    end

    private

      def client
        @_client ||= HTTPClient.new(agent_name: USER_AGENT)
      end

      def body
        @response.body
      end

      def parse_value(value)
        if value == "new Array()"
          []
        else
          match_numeric(match_string(value))
        end
      end

      def match_string(value)
        value.match(/^('|"|)(.*)\1$/)[2]
      end

      def match_numeric(value)
        match = value.match /^\d{1,3}(,\d{3})*(\.\d*)?$/
        return value unless match
        if match[2]
          value.tr(",", "").to_f
        else
          value.tr(",", "").to_i
        end
      end
  end
end
