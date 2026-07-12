# frozen_string_literal: true

module AsciiChem
  module Formatter
    # Visitor base class. Subclasses implement one `visit_<node_name>`
    # method per Model::Node subclass. Missing visits raise
    # NotImplementedError so gaps surface at first use, not silently.
    class Base
      def render(node)
        node.accept(self)
      end

      private

      def not_implemented_for(node)
        raise NotImplementedError,
              "#{self.class} cannot render #{node.class.name}"
      end
    end
  end
end
