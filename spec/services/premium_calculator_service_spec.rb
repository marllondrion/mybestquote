# frozen_string_literal: true

require "rails_helper"

RSpec.describe PremiumCalculatorService do
  let(:quote) do
    quote = Quote.new(age: 35)
    allow(quote).to receive(:persisted?).and_return(true)
    allow(quote).to receive(:allow_travel_free?).and_return(false)
    quote
  end
  let(:calculator) { described_class.new(quote) }


  describe "#calculate_base_premium" do
    context "when traveler allows free travel" do
      before { allow(quote).to receive(:allow_travel_free?).and_return(true) }

      it "returns 0.0" do
        expect(calculator.calculate_base_premium).to eq(0.0)
      end
    end

    context "when traveler does not allow free travel" do
      before do
        allow(quote).to receive(:allow_travel_free?).and_return(false)
        allow(calculator).to receive(:base_amount_multiplier).and_return(100.0)
        allow(calculator).to receive(:excess_multiplier).and_return(1.0)
        allow(calculator).to receive(:age_multiplier).and_return(1.0)
        allow(calculator).to receive(:duration_multiplier).and_return(1.0)
        allow(calculator).to receive(:destination_multiplier).and_return(1.0)
        allow(calculator).to receive(:trip_type_multiplier).and_return(1.0)
        allow(calculator).to receive(:cover_multiplier).and_return(1.0)
      end

      it "multiplies all multiplier methods together" do
        expect(calculator.calculate_base_premium).to eq(100.0)
      end

      it "returns BigDecimal result" do
        result = calculator.calculate_base_premium
        expect(result).to be_a(BigDecimal)
      end

      context "with various multiplier combinations" do
        before do
          allow(calculator).to receive(:base_amount_multiplier).and_return(100.0)
          allow(calculator).to receive(:excess_multiplier).and_return(1.5)
          allow(calculator).to receive(:age_multiplier).and_return(2.0)
          allow(calculator).to receive(:duration_multiplier).and_return(1.2)
          allow(calculator).to receive(:destination_multiplier).and_return(1.5)
          allow(calculator).to receive(:trip_type_multiplier).and_return(1.0)
          allow(calculator).to receive(:cover_multiplier).and_return(1.0)
        end

        it "calculates correctly" do
          # 100 * 1.5 * 2.0 * 1.2 * 1.5 * 1.0 * 1.0 = 540.0
          expect(calculator.calculate_base_premium).to eq(BigDecimal("540.0"))
        end
      end
    end
  end
end
