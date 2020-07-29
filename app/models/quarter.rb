class Quarter
  include Comparable
  PARSE_REGEX = /\AQ(\d)-(\d{4})\z/

  def self.for_date(date)
    new(date: date)
  end

  def self.current
    new(date: Date.current)
  end

  def self.parse(string)
    match = string.match(PARSE_REGEX)
    raise ArgumentError, "String to parse as Quarter must match QX-YYYY format" unless match
    number = Integer(match[1])
    year = Integer(match[2])
    quarter_month = ((number - 1) * 3) + 1
    date = Date.new(year, quarter_month).beginning_of_month
    new(date: date)
  end

  attr_reader :date
  attr_reader :number
  attr_reader :year

  def initialize(date:)
    @date = date.freeze
    @year = date.year.freeze
    @number = QuarterHelper.quarter(date).freeze
    @to_s = "Q#{number}-#{year}".freeze
  end

  def next_quarter
    self.class.new(date: date.advance(months: 3))
  end

  alias succ next_quarter

  def previous_quarter
    self.class.new(date: date.advance(months: -3))
  end

  def downto(number)
    (1..number).inject([self]) do |quarters, number|
      quarters << quarters.last.previous_quarter
    end
  end

  def upto(number)
    (1..number).inject([self]) do |quarters, number|
      quarters << quarters.last.next_quarter
    end
  end

  def advance(months:)
    self.class.new(date: date.advance(months: months))
  end

  def inspect
    "#<Quarter:#{object_id} #{to_s.inspect}>"
  end

  def to_s
    @to_s
  end

  def to_date
    date
  end

  def ==(other)
    to_s == other.to_s
  end

  def <=>(other)
    return -1 if year < other.year
    return -1 if year == other.year && number < other.number
    return 0 if self == other
    return 1 if year > other.year
    return 1 if year == other.year && number > other.number
  end

  alias eql? ==

  def hash
    year.hash ^ number.hash
  end
end
