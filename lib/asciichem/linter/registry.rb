# frozen_string_literal: true

module AsciiChem
  module Linter
    # Check registry. Each check self-registers at file-load time via
    # `Registry.add(:name, Klass)`. The registry is a Hash; iteration
    # order is insertion order.
    module Registry
      @checks = []

      class << self
        def add(name, klass)
          @checks << [name, klass] unless @checks.any? { |n, _k| n == name }
        end

        def all
          @checks.map { |(_name, klass)| klass }
        end

        def names
          @checks.map { |(name, _klass)| name }
        end

        # For testing: clear the registry.
        def reset
          @checks.clear
        end
      end
    end
  end
end
