class ZenkakuString < String
  FULL_WIDTH_REGEXP = /[^ -~｡-ﾟ]/.freeze

  def ljust(length, padstr = " ")
    just(length, padstr, :left)
  end

  def rjust(length, padstr = " ")
    just(length, padstr, :right)
  end

  def width
    length + full_width_count
  end

  private

    def just(length, padstr, side)
      raise ArgumentError.new unless %w(left right).include?(side.to_s)

      padding_width = length - width
      return self.dup unless padding_width > 0

      padding = padstr * padding_width

      if side.to_s == "left"
        self + padding
      else
        padding + self
      end
    end

    def full_width_count
      scan(FULL_WIDTH_REGEXP).count
    end
end
