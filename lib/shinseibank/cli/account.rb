require "ostruct"
require "shinseibank/cli/subcommand"

class ShinseiBank
  class CLI < Thor
    class Account < Subcommand
      desc "show", "Show your account details"
      def show
        login
        non_empty_accounts.each do |account|
          puts format_account(account)
        end
      end

      desc "history [ACCOUNT_ID]", "Display the transaction history of an account (defaults to the first checkings account)"
      def history(account_id = nil)
        puts "ID: #{account_id}"
        puts options
      end

      private

        def non_empty_accounts
          shinseibank.accounts.values.select do |account|
            account[:balance] > 0
          end
        end

        def format_account(account)
          OpenStruct.new(account).instance_eval do
            "#{description} - #{id} (#{type}):\t#{currency} #{balance}"
          end
        end
    end
  end
end
