class ShinseiBank
  class CLI < Thor
    class Subcommand < Thor
      DEFAULT_CREDENTIALS_PATH = "./shinsei_bank.yaml".freeze

      class_option :credentials, required: true, type: :string, aliases: "-c", default: DEFAULT_CREDENTIALS_PATH

      private

        def shinseibank
          @_shinseibank ||= ShinseiBank.new
        end

        def login
          shinseibank.login(options[:credentials])
        end
    end
  end
end
