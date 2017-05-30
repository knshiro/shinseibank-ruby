require "thor"
require "shinseibank"
require "shinseibank/cli/account"
require "shinseibank/cli/fund"

class ShinseiBank
  class CLI < Thor
    register(Account, "account", "account <command>", "Get informations about your account.")
    register(Fund, "fund", "fund <command>", "Get informations about your funds.")
  end
end
