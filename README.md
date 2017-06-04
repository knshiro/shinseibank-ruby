# Shinseibank-ruby

This is a Shinsei-bank PowerDirect (Shinsei-bank internet banking) library for Ruby.
http://www.shinseibank.com/

Forked from: https://github.com/binzume/shinseibank-ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shinseibank'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shinseibank

## Usage

### Command Line Interface

```sh
bundle exec exe/shinseibank --help
```

There are multiple ways to pass credentials.

#### YAML file

```yaml
account: "4009999999"
password: "********"
pin: "1234"
code_card:
 - "ZXCVBNMBNM"
 - "ASDFGHJKLL"
 - "QWERTYUIOP"
 - "1234567890"
 - "ZXCVBNMBNM"
```

The CLI will load `./shinsei_account.yaml` by default, but you can pass your own
credentials file using the `--credentials` option.

#### Environment variables

```sh
SHINSEIBANK_ACCOUNT=4009999999
SHINSEIBANK_PASSWORD=********
SHINSEIBANK_PIN=1234
SHINSEIBANK_CODE_CARD=ZXCVBNMBNM,ASDFGHJKLL,QWERTYUIOP,1234567890,ZXCVBNMBNM
bundle exec exe/shinseibank --help
```

You can also use [`envchain`](https://github.com/sorah/envchain) to store these
values securely.

```sh
brew install envchain

envchain --set my-shinsei SHINSEIBANK_ACCOUNT SHINSEIBANK_PASSWORD SHINSEIBANK_PIN SHINSEIBANK_CODE_CARD
# Here, set your credential values one by one.

envchain my-shinsei bundle exec exe/shinseibank account show
```

### Library

Provide account number, password, pin code and the security card grid.

```ruby
require_relative 'shinseibank'

powerdirect = ShinseiBank.connect(
  account: "4009999999",
  password: "********",
  pin: "1234",
  code_card: [
    "ZXCVBNMBNM",
    "ASDFGHJKLL",
    "QWERTYUIOP",
    "1234567890",
    "ZXCVBNMBNM"
  ]
)

# login
unless powerdirect
  puts 'LOGIN ERROR'
  exit
end

begin
  puts 'total: ' + powerdirect.total_balance.to_s
  powerdirect.recent.each do |row|
    p row
  end

  puts "accounts:"
  powerdirect.accounts.values.find_all{|a|a[:balance]>0}.each{|a|
    p a
  }
  puts "funds:"
  powerdirect.funds.each{|f|
    p f
  }

  # 登録済み口座に振り込み 200万円まで？？
  # powerdirect.transfer_to_registered_account('登録済み振込先の口座番号7桁(仮)', 50000)

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

```ruby
fund = powerdirect.funds[0]
req = powerdirect.buy_fund fund, 1000000
powerdirect.confitm req
```

投資信託を解約

```ruby
fund = powerdirect.funds[0]
req = powerdirect.sell_fund fund, 1230000
powerdirect.confitm req
```

あらゆる動作は無保証です．実装と動作をよく確認して使ってください．

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/knshiro/shinseibank-ruby.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

