# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchases', type: :request do
  include Requests

  describe 'POST /create' do
    subject(:request!) { post '/purchases', params: params }

    shared_examples 'using logged in user present into the cart' do
      context 'and there is a user present in cart' do
        let!(:user) { create(:user) }

        it 'does not create a guest user' do
          expect { request! }.not_to change(User, :count)
        end
      end
    end

    shared_examples 'creating a new guest user' do
      context 'and there is no user present in cart, user params are valid' do
        let(:user) { nil }
        let(:params) do
          {
            gateway: gateway,
            cart_id: cart_id,
            user: {
              email: 'user@spec.io',
              first_name: 'John',
              last_name: 'Doe'
            }
          }
        end

        it 'creates new user' do
          expect { request! }.to change(User, :count).by(1)
        end

        it 'created user should be guest' do
          request!

          expect(User.last).to be_guest
        end
      end
    end

    shared_examples 'validating guest user info is valid' do
      context 'and there is no user present in cart, user params are not valid' do
        let(:user) { nil }
        let(:params) do
          {
            gateway: gateway,
            cart_id: cart_id,
            user: {}
          }
        end

        it 'does not create a guest user' do
          expect { request! }.not_to change(User, :count)
        end

        it 'returns proper errors' do
          request!

          expect(response_body_as_json).to eq(
            errors: [
              { message: "Email can't be blank" },
              { message: "First name can't be blank" },
              { message: "Last name can't be blank" }
            ]
          )
        end
      end
    end

    context 'when gateway is PayPal' do
      let(:gateway) { :paypal }
      let(:params) { { gateway: gateway, cart_id: cart_id } }

      context 'and cart does not exist' do
        let(:cart_id) { 1 }

        before { request! }

        it 'returns :unprocessable_entity' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns proper errors' do
          expect(response_body_as_json).to eq(
            errors: [{ message: 'Cart not found!' }]
          )
        end
      end

      context 'and cart exists' do
        let!(:cart_id) { create(:cart, user: user).id }

        include_examples 'using logged in user present into the cart'

        include_examples 'creating a new guest user'

        include_examples 'validating guest user info is valid'
      end

      context 'and the purchase is successfull' do
        let!(:user) { create(:user) }
        let!(:cart) { create(:cart, user: user) }
        let!(:cart_id) { cart.id }

        let(:sale) { create(:sale, name: 'My Sale V', unit_price_cents: 1_900) }

        before do
          create(:cart_item, cart: cart, sale: sale, quantity: 3)
        end

        it 'creates order' do
          expect { request! }.to change(Order, :count).by(1)
        end

        it 'creates order line items' do
          expect { request! }.to change(OrderLineItem, :count).by(3)
        end

        it 'create order line items with proper attributes' do
          request!

          expect(
            OrderLineItem.pluck(:unit_price_cents, :shipping_costs_cents, :taxes_cents, :paid_price_cents)
          ).to eq([[1_900, 100, 0, 2_000], [1_900, 100, 0, 2_000], [1_900, 100, 0, 2_000]])
        end

        it "calculates order's subtotal_cents properly" do
          request!

          expect(Order.last.subtotal_cents).to eq 5_700
        end

        it "calculates order's total properly" do
          request!

          expect(Order.last.total_cents).to eq 6_000
        end
      end
    end

    context 'when gateway is Stripe' do
      let(:gateway) { :stripe }
      let(:params) { { gateway: gateway, cart_id: cart_id } }

      context 'and cart does not exist' do
        let(:cart_id) { 1 }

        before { request! }

        it 'returns :unprocessable_entity' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns proper errors' do
          expect(response_body_as_json).to eq(
            errors: [{ message: 'Cart not found!' }]
          )
        end
      end

      context 'and cart exists' do
        let!(:cart_id) { create(:cart, user: user).id }

        include_examples 'using logged in user present into the cart'

        include_examples 'creating a new guest user'

        include_examples 'validating guest user info is valid'
      end

      context 'and the purchase is successfull' do
        let!(:user) { create(:user) }
        let!(:cart) { create(:cart, user: user) }
        let!(:cart_id) { cart.id }

        let(:sale) { create(:sale, name: 'My Sale V', unit_price_cents: 1_900) }

        before do
          create(:cart_item, cart: cart, sale: sale, quantity: 3)
        end

        it 'creates order' do
          expect { request! }.to change(Order, :count).by(1)
        end

        it 'creates order line items' do
          expect { request! }.to change(OrderLineItem, :count).by(3)
        end

        it 'create order line items with proper attributes' do
          request!

          expect(
            OrderLineItem.pluck(:unit_price_cents, :shipping_costs_cents, :taxes_cents, :paid_price_cents)
          ).to eq([[1_900, 100, 0, 2_000], [1_900, 100, 0, 2_000], [1_900, 100, 0, 2_000]])
        end

        it "calculates order's subtotal_cents properly" do
          request!

          expect(Order.last.subtotal_cents).to eq 5_700
        end

        it "calculates order's total properly" do
          request!

          expect(Order.last.total_cents).to eq 6_000
        end
      end
    end

    context 'when gateway is unknown' do
      let(:params) { { gateway: :unknown } }

      before { request! }

      it 'returns :unprocessable_entity' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns proper errors' do
        expect(response_body_as_json).to eq(
          errors: [{ message: 'Gateway not supported!' }]
        )
      end
    end
  end
end
