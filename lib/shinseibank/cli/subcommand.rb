require "yaml"

class ShinseiBank
  module CLI
    class Subcommand < Thor
      DEFAULT_CREDENTIALS_PATH = "./shinsei_account.yaml".freeze

      class_option :credentials, type: :string, aliases: "-c", default: DEFAULT_CREDENTIALS_PATH

      private

        def shinsei_bank
          @shinsei_bank ||= ShinseiBank.connect(credentials)
        end

        def logout
          puts "Logging out..."
          @shinsei_bank&.logout
        end

        def credentials
          YAML.load_file(options[:credentials])
        end
    end
  end
end
