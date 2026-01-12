# frozen_string_literal: true

class QuotesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :premiums
  before_action :load_form_data
  helper_method :trip_date_max
  before_action :set_quote, only: [ :show, :premiums ]

  def new
    @quote = Quote.new
    @quote.excess = @excesses.first
    @quote.trip_type = @trip_types.first
    @quote.cover = covers.first
  end

  def create
    @quote = Quote.new(quote_params)
    @quote.destination_ids = params[:quote]&.dig(:destination_ids)&.reject(&:blank?) || []

    if @quote.save
      redirect_to quote_path(@quote), notice: "Quote created successfully! Select add-ons below."
    else

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("form-frame", partial: "quotes/form", locals: { quote: @quote }),
            turbo_stream.update("errors-display", partial: "shared/errors", locals: { errors: @quote.errors.full_messages })
          ]
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
    covers
    @premiums = @quote.calculate_all_covers
  end

  # Updates addons and returns ALL cover premiums
  # Responds to: PATCH
  def premiums
    # check if the :id is the same as @quote.id

    @premiums = @quote.calculate_all_covers
    if addon_params.present? && @quote.update(addon_params)

      @premiums = @quote.calculate_all_covers
      load_form_data

      respond_to do |format|
        format.json do
          render json: { success: true, premiums: @premiums,
                         quote: {
              cruise: @quote.cruise,
              snow: @quote.snow,
              snow_start_date: @quote.snow_start_date,
              snow_end_date: @quote.snow_end_date
            }
          }
        end

        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("premiums-display", partial: "quotes/premiums", locals: { premiums: @premiums })
          ]
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            errors: @quote.errors.full_messages.presence || [ "No valid parameters provided" ]
          }, status: :unprocessable_entity
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream
                                 .update("errors-display",
                                         partial: "shared/errors",
                                         locals: { errors: @quote.errors.full_messages })
        end
      end
    end
  end

  private

  def trip_date_max
    @trip_date_max ||= Date.today + @quote.class::MAX_TRIP_ADVANCE_DAYS.days
  end

  def set_quote
    @quote = Quote.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to new_quote_path, alert: "Quote not found" }
      format.json { render json: { error: "Quote not found" }, status: :not_found }
    end
  end

  def load_form_data
    covers
    @excesses = Excess.all.order(:value)
    @destinations = Destination.all.order(:label)
    @trip_types = TripType.all.order(:label)
  end

  def destinations
    return @destinations if defined? @destinations

    @destinations = (@quote.persisted? ? @quote.destinations : Destination.all).order(:label)
  end

  def covers =@covers ||= Cover.all.order(:multiplier)

  def all_cover_premiums = @quote.calculate_all_covers

  def quote_params
    params.require(:quote).permit(
      :age, :start_date, :end_date, :cover_id, :excess_id,
      :trip_type_id, destination_ids: []
    )
  end

  def addon_params
    addon_params = params.require(:quote).permit(:cruise, :snow, :snow_start_date, :snow_end_date)
    snow = ActiveModel:: Type:: Boolean.new.cast(addon_params[:snow])

    if snow
      addon_params[:snow_start_date] ||= @quote.start_date
      addon_params[:snow_end_date] ||= @quote.end_date
    else
      addon_params[:snow_start_date] = addon_params[:snow_end_date] = nil
    end

    addon_params
  end
end
