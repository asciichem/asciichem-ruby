# frozen_string_literal: true

module AsciiChem
  module Linter
    Diagnostic = Struct.new(:severity, :message, :node, keyword_init: true) do
      def to_s
        context = node_context
        if context
          "[#{severity}] #{context}: #{message}"
        else
          "[#{severity}] #{message}"
        end
      end

      private

      def node_context
        return nil unless node

        case node
        when AsciiChem::Model::Atom
          "Atom(#{node.element})"
        when AsciiChem::Model::Molecule
          "Molecule"
        when AsciiChem::Model::Reaction
          "Reaction"
        when AsciiChem::Model::Group
          "Group"
        else
          node.class.name.split("::").last
        end
      end
    end
  end
end
