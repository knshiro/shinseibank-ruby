require "thor"
require "shinseibank"
Dir[File.join(__dir__, *%w(cli *.rb))].each { |f| require f }

class ShinseiBank
  module CLI
    class Main < Thor
      register(Account, "account", "account <command>", "Get informations about your account.")
      register(Transfer, "transfer", "transfer <command>", "Issue transfers to registered accounts.")
      register(Fund, "fund", "fund <command>", "Get informations about your funds.")
    end
  end
end
