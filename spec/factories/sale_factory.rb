# frozen_string_literal: true

FactoryBot.define do
  factory :sale do
    name { 'My Sale' }
    unit_price_cents { rand(99..999) }
  end
end
