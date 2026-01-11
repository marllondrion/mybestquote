# typed: false
# frozen_string_literal: true

class Duration < ApplicationRecord
  # Finds durations covering the specified number of days.
  #
  # @param days [Integer] number of days within the duration range
  # @return [ActiveRecord::Relation] matching duration records
  def self.within_range(days) = where("minimum_days <= ? AND maximum_days >= ?", days, days)
end
