# frozen_string_literal: true

module CFONB
  class Parser
    using CFONB::Refinements::Strings

    CODES = [
      PREVIOUS_BALANCE_CODE = '01',
      OPERATION_CODE = '04',
      OPERATION_DETAIL_CODE = '05',
      NEW_BALANCE_CODE = '07',
    ].freeze

    def initialize(input)
      @input = input
    end

    def parse(optimistic: false)
      @statements = []
      @current_statement = nil
      @current_operation = nil
      @optimistic = optimistic

      each_line { parse_line(_1) }

      statements
    end

    def parse_operation(optimistic: false)
      @current_operation = nil
      @optimistic = optimistic

      each_line { parse_operation_line(_1) }

      current_operation
    end

    private

    attr_reader :input, :statements, :current_statement, :current_operation, :optimistic

    def each_line
      input.each_line do |line|
        (line.size / 120).times do |index|
          start = index * 120
          finish = start + 119

          yield line[start..finish]
        end
      end
    end

    def parse_line(line)
      return if line.strip.empty?
      raise InvalidCodeError.new("Invalid line code '#{line.first(2)}'") unless CODES.include?(line.first(2))

      line = CFONB::LineParser.parse(line)

      case line.code
      when PREVIOUS_BALANCE_CODE
        return handle_error(UnfinishedStatementError) if current_statement

        @current_statement = CFONB::Statement.new(line)
      when OPERATION_CODE
        return handle_error(UnstartedStatementError) unless current_statement

        current_statement.operations << current_operation if current_operation
        @current_operation = CFONB::Operation.new(line)
      when OPERATION_DETAIL_CODE
        return handle_error(UnstartedOperationError) unless current_operation

        current_operation.merge_detail(line)
      when NEW_BALANCE_CODE
        return handle_error(UnstartedStatementError) unless current_statement

        current_statement.operations << current_operation if current_operation
        current_statement.merge_new_balance(line)
        statements << current_statement

        @current_statement = nil
        @current_operation = nil
      end
    rescue CFONB::ParserError => e
      handle_error(e)
    end

    def parse_operation_line(line)
      line = CFONB::LineParser.parse(line)

      case line.code
      when OPERATION_CODE
        return handle_error(AlreadyDefinedOperationError) if current_operation

        @current_operation = CFONB::Operation.new(line)
      when OPERATION_DETAIL_CODE
        return handle_error(UnstartedOperationError) unless current_operation

        current_operation.merge_detail(line)
      else
        handle_error(UnhandledLineCodeError)
      end
    end

    def handle_error(error)
      raise error unless optimistic
    end
  end
end
