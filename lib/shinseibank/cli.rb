require "thor"
require "shinseibank"
Dir[File.join(__dir__, *%w(cli *.rb))].each { |f| require f }

class ShinseiBank
  module CLI; end
end
