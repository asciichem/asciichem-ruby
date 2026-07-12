# frozen_string_literal: true

module AsciiChem
  module Linter
    # Base class for linter checks. Subclasses implement `run(formula)`
    # and return an array of Diagnostic objects.
    #
    # Self-registration: subclasses call `register(:name)` inside their
    # class body. The Linter module triggers every autoload at load
    # time so each check file has a chance to register before any API
    # is queried.
    class Base
      class << self
        def register(name)
          AsciiChem::Linter::Registry.add(name, self)
        end
      end

      def run(_formula)
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      protected

      def error(message, node: nil)
        Diagnostic.new(severity: :error, message: message, node: node)
      end

      def warning(message, node: nil)
        Diagnostic.new(severity: :warning, message: message, node: node)
      end

      def info(message, node: nil)
        Diagnostic.new(severity: :info, message: message, node: node)
      end

      # Depth-first walk over every node in the formula. Yields each
      # node to the block. Uses `Node#children` — adding a new
      # container class means defining `children` on it; no edits here.
      def walk(formula)
        return enum_for(:walk, formula) unless block_given?

        walk_node(formula) { |c| yield c }
      end

      def walk_node(node)
        yield node
        node.children.each { |c| walk_node(c) { |x| yield x } }
      end
    end
  end
end
