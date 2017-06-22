require "shinseibank/cli/subcommand"
require "shinseibank/display_string"

class ShinseiBank
  module CLI
    class Transfer < Subcommand
      desc "history", "Show your past transfers history"
      def history
        puts history_header

        shinsei_bank.get_transfer_history.each do |transfer|
          puts format_transfer(transfer)
        end
        logout
      end

      private

        def history_header
          format_transfer(
            date: "Date",
            reference: "Reference",
            payee_name: "Payee",
            payee_account_id: "Account",
            remarks: "Remarks",
            amount: "Amount",
            fee: "Fee",
            status: "Status"
          )
        end

        def format_transfer(transfer)
          [
            transfer[:date].to_s.ljust(10),
            transfer[:reference].to_s.ljust(10),
            DisplayString.new(transfer[:payee_name].to_s).ljust_display(30),
            transfer[:payee_account_id].to_s.ljust(7),
            transfer[:amount].to_s.rjust(10),
            DisplayString.new(transfer[:remarks].to_s).ljust_display(50),
            transfer[:fee].to_s.rjust(5),
            transfer[:status].to_s.ljust(10),
          ].join(" | ")
        end
    end
  end
end
