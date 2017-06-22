require "unicode/display_width"

class DisplayString < String
  def ljust_display(to_length, padstr = " ")
    self.class.new(self + padding(to_length, padstr))
  end

  def rjust_display(to_length, padstr = " ")
    self.class.new(padding(to_length, padstr) + self)
  end

  private

    def padding(to_length, padstr)
      padstr.to_str * padding_length(to_length)
    end

    def padding_length(to_length)
      [
        0,
        to_length - display_width
      ].max
    end

    def display_width
      Unicode::DisplayWidth.of(self)
    end
end
