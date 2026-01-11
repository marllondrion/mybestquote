# frozen_string_literal: true

class PremiumCalculatorService
  class InvalidQuoteError < StandardError; end

  DEFAULT_BASE_AMOUNT = 100.0.freeze
  DEFAULT_EXCESS_MULTIPLIER = 1.0.freeze
  DEFAULT_AGE_MULTIPLIER = 1.freeze
  DEFAULT_DURATION_MULTIPLIER = 1.0.freeze
  DEFAULT_DESTINATION_MULTIPLIER = 1.0.freeze
  DEFAULT_TRIP_TYPE_MULTIPLIER = 1.0.freeze
  DEFAULT_COVER_MULTIPLIER = 1.0.freeze
  DEFAULT_SNOW_DAILY_RATE = 10.0.freeze
  DEFAULT_ZONE_VALUE = 1.freeze

  attr_reader :quote, :cover_override

  def initialize(quote, cover_override: nil)
    @quote = quote
    @cover_override = cover_override
    validate_quote!
  end

  # Calculates the base premium by multiplying all applicable factors.
  # Base Premium: (Base X Excess × Age × Duration × Destination × Trip Type × Level of Cover)
  #
  # @return [Float] calculated base premium
  def calculate_base_premium
    return 0.0 if quote.allow_travel_free?

    @calculate_base_premium ||= multiplier_methods.map do |method_name|
        value = send(method_name)
        value ||= 0
        BigDecimal(value.to_s)
      end.reduce(:*)
  end

  CoverData = Data.define(:cover_type, :cover_label, :base_premium, :cruise_addon, :snow_addon, :final_premium)

  # Calculate all cover levels at once
  def calculate_all_covers
    Cover.all.map do |cover|
      calculator = self.class.new(quote, cover_override: cover)
      CoverData.new(
        cover.cover_type,
        cover.label,
        calculator.calculate_base_premium,
        calculator.calculate_cruise_addon,
        calculator.calculate_snow_addon,
        calculator.calculate_final_premium
      )
    end
  end

  def calculate_snow_addon
    return 0 unless quote.snow? && quote.snow_date_range

    ski_days = quote.snow_date_range.then { |r| (r.end - r.begin).to_i + 1 }
    ski_rate = quote.highest_zone_destination&.ski_per_day_amount || DEFAULT_SNOW_DAILY_RATE

    ski_days * ski_rate
  end

  # Cruise addon: flat amount per traveler based on highest zone
  def calculate_cruise_addon
    return 0.0 unless quote.cruise?

    quote.highest_zone_destination&.cruise_add_on_amount || 0.0
  end

  def calculate_final_premium
    [ calculate_base_premium,
     calculate_cruise_addon,
     calculate_snow_addon ]
      .map { |v| BigDecimal(v.to_s) }
     .sum
  end

  private

  def premium_type
    # TODO: Verify if premium_type should map to cover.cover_type
    #       Currently defaulting to :base - confirm with business requirements

    (cover_override || quote.cover)&.cover_type || :base
  end

  def premium_scope = Premium.where(premium_type: premium_type)

  def base_premium = @base_premium ||= premium_scope.first

  def validate_quote!
    raise InvalidQuoteError, "Quote cannot be nil" if quote.nil?
    raise InvalidQuoteError, "Quote must be persisted" unless quote.persisted?
  end

  # Logic for each multiplier. Methods with '_multiplier' suffix are called automatically
  def multiplier_methods = private_methods.grep(/_multiplier$/)

  def base_amount_multiplier = @base_amount_multiplier ||= base_premium&.multiplier || DEFAULT_BASE_AMOUNT

  def excess_multiplier = @excess_multiplier ||= quote.excess&.multiplier || DEFAULT_EXCESS_MULTIPLIER

  def age_multiplier
    return @age_multiplier if defined?(@age_multiplier)

    @age_multiplier = Age.for_age(quote.age).first&.multiplier || DEFAULT_AGE_MULTIPLIER
  end

  def duration_multiplier
    return @duration_multiplier if defined?(@duration_multiplier)

    days = quote.duration_days
    @duration_multiplier = DEFAULT_DURATION_MULTIPLIER unless days

    @duration_multiplier ||= Duration.within_range(days).first&.multiplier || DEFAULT_DURATION_MULTIPLIER
  end

  def destination_multiplier
    @destination_multiplier ||= quote.destination_for_zone(quote.highest_zone_destination.zone || 1)&.multiplier || DEFAULT_DESTINATION_MULTIPLIER
  end

  def trip_type_multiplier = quote.trip_type&.multiplier || DEFAULT_TRIP_TYPE_MULTIPLIER

  def cover_multiplier
    cover = @cover_override || quote.cover
    cover&.multiplier || DEFAULT_COVER_MULTIPLIER
  end
end
