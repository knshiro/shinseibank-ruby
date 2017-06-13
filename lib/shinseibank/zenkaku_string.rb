class ZenkakuString < String
  FULL_WIDTH_REGEXP = /[^ -~｡-ﾟ]/.freeze

  def ljust(to_length, padstr = " ")
    self.class.new super(adjusted_just_length(to_length), padstr)
  end

  def rjust(to_length, padstr = " ")
    self.class.new super(adjusted_just_length(to_length), padstr)
  end

  private

    def adjusted_just_length(to_length)
      [to_length - full_width_count, 0].max
    end

    def full_width_count
      scan(FULL_WIDTH_REGEXP).count
    end
end
