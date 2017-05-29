# Shinseibank-ruby

This is a Shinsei-bank PowerDirect (Shinsei-bank internet banking) library for Ruby.
- http://www.shinseibank.com/

## Usage

Provide account number, password, pin code and the security card grid.
```yaml
# shinsei_account.yaml
ID: "4009999999"
PASS: "********"
NUM: "1234"
GRID:
 - ZXCVBNMBNM
 - ASDFGHJKLL
 - QWERTYUIOP
 - 1234567890
 - ZXCVBNMBNM
```

```ruby
# shinseipowerdirect_sample.rb
#!/usr/bin/ruby -Ku
# -*- encoding: utf-8 -*-

require 'yaml'
require_relative 'shinseipowerdirect'

shinsei_account = YAML.load_file('shinsei_account.yaml')
powerdirect = ShinseiPowerDirect.new

# login
unless powerdirect.login(shinsei_account)
  puts 'LOGIN ERROR'
  exit
end

begin
  puts 'total: ' + powerdirect.total_balance.to_s
  powerdirect.recent.each do |row|
    p row
  end

  p powerdirect.accounts
ensure
  # logout
  powerdirect.logout
end

puts "ok"
```

### Transfer to a registered account

```
powerdirect.transfer_to_registered_account('registed_account_num', 50000)
```

With remitter information:
```
powerdirect.transfer_to_registered_account('registed_account_num', 50000, remitter_info: 'YEY', remitter_info_pos: :after)
```

- TODO: Use the confirm method to confirm the transaction

### Buy and sell funds

投資信託を買う(すでに買ってあるやつを追加で)

  fund = powerdirect.funds[0]
  req = powerdirect.buy_fund fund, 1000000
  powerdirect.confitm req

投資信託を解約

  fund = powerdirect.funds[0]
  req = powerdirect.sell_fund fund, 1230000
  powerdirect.confitm req


あらゆる動作は無保証です．実装と動作をよく確認して使ってください．

