require "yaml"

class ShinseiBank
  module CLI
    class Subcommand < Thor
      DEFAULT_CREDENTIALS_YAML = "./shinsei_account.yaml".freeze

      class_option :credentials, type: :string, aliases: "-c", default: DEFAULT_CREDENTIALS_YAML

      private

        def shinsei_bank
          @shinsei_bank ||= ShinseiBank.connect(credentials)
        end

        def logout
          puts "Logging out..."
          @shinsei_bank&.logout
        end

        def credentials
          env_credentials || yaml_credentials
        end

        def yaml_credentials
          YAML.load_file(options[:credentials])
        end

        def env_credentials
          return unless env_var(:account)
          {
            "account" => env_var(:account),
            "password" => env_var(:password),
            "pin" => env_var(:pin),
            "code_card" => env_var(:code_card).split(",")
          }
        end

        def env_var(key)
          ENV["SHINSEIBANK_#{key.upcase}"]
        end
    end
  end
end
