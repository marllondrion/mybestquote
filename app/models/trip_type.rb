# typed: false
# frozen_string_literal: true

class TripType < ApplicationRecord
  has_many :quotes, class_name: "Quote", dependent: :destroy, foreign_key: :id

  def return? = :trip_type == :return
  def one_way? = :trip_type == :one_way
end
