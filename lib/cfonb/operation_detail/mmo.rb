# frozen_string_literal: true

require 'bigdecimal'

module CFONB
  module OperationDetail
    class MMO
      ATTRIBUTES = %i[original_currency original_amount exchange_rate].freeze

      def self.apply(operation, line)
        operation.original_currency = line.detail[0..2]

        scale = line.detail[3].to_i
        sign = operation.amount <=> 0 # the detail amount is unsigned

        operation.original_amount = sign * BigDecimal(line.detail[4..17]) / (10**scale)
        exchange_rate_value = line.detail[26..29]
        operation.exchange_rate = BigDecimal(exchange_rate_value) / 1000 if exchange_rate_value
      end

      CFONB::OperationDetail.register('MMO', self)
    end
  end
end
