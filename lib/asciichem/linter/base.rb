# frozen_string_literal: true

module AsciiChem
  module Linter
    # Base class for linter checks. Subclasses implement `run(formula)`
    # and return an array of Diagnostic objects.
    #
    # Self-registration: subclasses call `register(:name)` at the bottom
    # of the file. This adds them to the Registry when the file loads.
    class Base
      def self.register(name)
        AsciiChem::Linter::Registry.add(name, self)
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

      # Walk every model node in the formula, depth-first. Yields each
      # node to the block.
      def walk(formula)
        return enum_for(:walk, formula) unless block_given?

        formula.nodes.each { |n| walk_node(n) { |c| yield c } }
      end

      def walk_node(node)
        yield node
        case node
        when AsciiChem::Model::Molecule
          node.nodes.each { |c| walk_node(c) { |x| yield x } }
        when AsciiChem::Model::Group
          node.nodes.each { |c| walk_node(c) { |x| yield x } }
        when AsciiChem::Model::Reaction
          node.reactants.each { |c| walk_node(c) { |x| yield x } }
          node.products.each { |c| walk_node(c) { |x| yield x } }
        when AsciiChem::Model::ReactionCascade
          node.steps.each { |c| walk_node(c) { |x| yield x } }
        end
      end
    end
  end
end
