class ShinseiBank
  class CLI < Thor
    class Subcommand < Thor
      class_option :credentials, required: true, type: :string

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
