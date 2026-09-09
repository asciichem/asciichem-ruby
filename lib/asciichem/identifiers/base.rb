# frozen_string_literal: true

module AsciiChem
  module Identifiers
    # Contract for convention validators: implement `.diagnostic(value)`
    # returning nil for a valid value or a human-readable reason
    # otherwise. `.valid?` derives from it. Register with
    # `register("convention")` in the class body.
    class Base
      class << self
        def register(convention)
          AsciiChem::Identifiers.register(convention, self)
        end

        def valid?(value)
          diagnostic(value).nil?
        end

        def diagnostic(_value)
          raise NotImplementedError, "#{name} must implement .diagnostic"
        end
      end
    end
  end
end
