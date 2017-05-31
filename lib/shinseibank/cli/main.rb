class ShinseiBank
  module CLI
    class Main < Thor
      register(Account, "account", "account <command>", "Get informations about your account.")
      register(Fund, "fund", "fund <command>", "Get informations about your funds.")
    end
  end
end
