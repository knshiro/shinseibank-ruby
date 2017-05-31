require "ostruct"
require "shinseibank/cli/subcommand"

class ShinseiBank
  module CLI
    class Account < Subcommand
      FULL_WIDTH_REGEXP = /[^ -~｡-ﾟ]/.freeze

      desc "show", "Show your account details"
      def show
        non_empty_accounts.each do |account|
          puts format_account(account)
        end
        logout
      end

      desc "history [ACCOUNT_ID]", "Display the transaction history of an account (defaults to the first checkings account)"
      option :from, type: :string, aliases: "-f"
      option :to, type: :string, aliases: "-t"
      def history(account_id = nil)
        puts history_header

        shinsei_bank.get_history(from: from, to: to, id: account_id).each do |tx|
          puts format_transaction(tx)
        end
      end

      private

        def non_empty_accounts
          shinsei_bank.accounts.values.select do |account|
            account[:balance] > 0
          end
        end

        def format_account(account)
          OpenStruct.new(account).instance_eval do
            "#{description} - #{id} (#{type}):\t#{currency} #{balance}"
          end
        end

        def history_header
          format_transaction(
            date: "Date",
            ref_no: "Reference",
            description: "Description",
            debit: "Debit",
            credit: "Credit",
            balance: "Balance"
          )
        end

        def format_transaction(transaction)
          [
            transaction[:date].to_s.ljust(10),
            transaction[:ref_no].to_s.ljust(10),
            pad_zenkaku(transaction[:description], 50),
            transaction[:debit].to_s.rjust(10),
            transaction[:credit].to_s.rjust(10),
            transaction[:balance].to_s.rjust(12),
          ].join(" | ")
        end

        def pad_zenkaku(string, to_length)
          length = string.length + string.scan(FULL_WIDTH_REGEXP).count
          padding = to_length - length
          if padding >= 0
            string + " " * padding
          else
            string
          end
        end

        def from
          return unless options[:from]
          Date.parse(options[:from])
        end

        def to
          return unless options[:to]
          Date.parse(options[:to])
        end
    end
  end
end
