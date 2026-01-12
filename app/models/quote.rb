# typed: false
# frozen_string_literal: true

class Quote < ApplicationRecord
  # TODO: Refactor to support multiple travelers per quote
  # 		Current limitation: Quote stores a single `age` field, limiting to one traveler.
  # 		This doesn't reflect real-world travel insurance where families/groups travel together.
  # 		Recommended approach:
  # 		  1. Create Traveller model to replace age that represents a single traveller
  # 		  2. Quote has_many :travellers
  # 		Some validations will be easy to do.

  CHILD_AGE_LIMIT_YEARS = 16.freeze # 16 years
  MAX_TRIP_ADVANCE_DAYS = 547.86375.freeze # 18 months
  MAX_TRIP_DURATION_ONE_WAY_DAYS = 365.freeze # 1 year
  MAX_TRIP_DURATION_DAYS = 730.485.freeze   # 2 years

  has_many :quotes_to_destinations, class_name: "QuotesToDestination"
  has_many :destinations, through: :quotes_to_destinations, source: :destination, join_table: :quotes_to_destinations, class_name: "Destination"

  belongs_to :trip_type, class_name: "TripType", optional: false, required: true
  belongs_to :excess, class_name: "Excess", optional: false, required: true
  belongs_to :cover, class_name: "Cover", optional: true

  validates :age, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 84,
    message: "must be between 0 and 84"
  }

  validates :trip_type, presence: true
  validates :excess, presence: true
  validates :start_date, presence: true, allow_blank: false
  validates :end_date, presence: true, allow_blank: false
  validates :snow_start_date, presence: true, if: :snow?
  validates :snow_end_date, presence: true, if: :snow?

  validate :validate_snow_dates, if: :snow?
  validate :validate_trip_dates
  validate :validate_trip_start_in_advance_window
  validate :validate_destinations

  delegate :calculate_all_covers,
           to: :calculator, allow_nil: false

  before_save :unset_snow_dates, unless: :snow?

  def calculator = @calculator ||= PremiumCalculatorService.new(self)

  def allow_travel_free? = (0..16).include?(age)

  def snow_date_range
    return unless snow_start_date && snow_end_date

    snow_start_date..snow_end_date
  end

  def days_in_advance = start_date ? (start_date - Date.today).to_i : 0

  # Calculates the number of days between start_date and end_date.
  #
  # @return [Integer] number of days in the date range
  def duration_days
    return unless start_date || end_date

    duration = (end_date - start_date).to_i
    duration.zero? ? 1 : duration
  end

  # Returns the highest zone number from quote destinations.
  #
  # @return [Destination, nil] highest zone or nil if no destinations
  def highest_zone_destination = destinations.order(zone: :desc).first

  # Returns the destination matching the given zone.
  #
  # @param zone_number [Integer] zone number
  # @return [Destination, nil] destination in the specified zone
  def destination_for_zone(zone_number) = destinations.find_by(zone: zone_number)

  def requires_adult_supervision? = age.present? && age < CHILD_AGE_LIMIT_YEARS
  private

  def validate_trip_dates
    return if start_date.blank? || end_date.blank?
    return errors.add(:end_date, "must be after start date") if end_date < start_date
    return errors.add(:start_date, "cannot be in the past") if start_date < Date.today
    return unless trip_type

    max_duration = MAX_TRIP_DURATION_ONE_WAY_DAYS.days
    if trip_type.one_way? && duration_days > max_duration.in_days
      errors.add(:end_date, "trip duration cannot exceed #{humanize_duration(max_duration)}")
    end
  end

  def validate_trip_start_in_advance_window
    max_advance = MAX_TRIP_ADVANCE_DAYS.days

    if days_in_advance > max_advance.in_days
      errors.add(:start_date, "cannot be more than #{humanize_duration(max_advance)} in advance")
    end
  end

  def validate_children_require_adults
    # TODO: I could add a ready attribute so that validation errors are only displayed after the user attempts to
    #       confirm.
    errors.add(:base, "Children under 16 require an adult (21+) traveler") if requires_adult_supervision?
  end

  def validate_snow_dates
    return unless snow?
    return unless snow_end_date && snow_start_date

    if snow_end_date < snow_start_date
      errors.add(:snow_end_date, "must be after ski start date")
    end

    unless (start_date..end_date).cover?(snow_start_date..snow_end_date)
      errors.add(:base, "Ski dates must fall within trip dates")
    end
  end

  def validate_destinations
    errors.add(:base, "At least one destination must be selected") if destinations.empty?
  end

  def unset_snow_dates
    self.snow_end_date = self.snow_start_date = nil
  end

  def humanize_duration(duration) = ActiveSupport::Duration.build(duration).inspect
end
