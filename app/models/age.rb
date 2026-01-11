# typed: false
# frozen_string_literal: true

class Age < ApplicationRecord
  # Finds premiums whose age range includes the given age.
  #
  # @param age [Integer] age to match within age_minimum and age_maximum (inclusive)
  # @return [ActiveRecord::Relation] records where age_minimum <= age <= age_maximum
  def self.for_age(age) = where("age_minimum <= ? AND age_maximum >= ?", age, age)
end
