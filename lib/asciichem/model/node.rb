# frozen_string_literal: true

module AsciiChem
  module Model
    # Base class for every model node. Provides:
    #   - structural equality (class + declared attributes)
    #   - visitor dispatch (`accept`)
    #   - convenience formatter shortcuts (`to_mathml`, `to_text`, ...)
    #
    # Subclasses declare their comparable attributes by overriding
    # `value_attributes` (returns a hash of `{ name => value }`). This
    # avoids reflective instance-variable access and keeps equality
    # correct as fields are added.
    class Node
      def accept(visitor)
        visitor.public_send(:"visit_#{short_name}", self)
      rescue NoMethodError => e
        raise unless e.name == :"visit_#{short_name}"

        raise NotImplementedError,
              "#{visitor.class} does not implement visit_#{short_name}"
      end

      def ==(other)
        other.is_a?(self.class) && value_attributes == other.value_attributes
      end
      alias eql? ==

      def hash
        [self.class, value_attributes].hash
      end

      def to_mathml
        AsciiChem::Formatter.render(:mathml, self)
      end

      def to_text
        AsciiChem::Formatter.render(:text, self)
      end

      def to_html
        AsciiChem::Formatter.render(:html, self)
      end

      def to_latex
        AsciiChem::Formatter.render(:latex, self)
      end

      # Subclasses override to expose the attributes that participate in
      # equality. Default: empty (so two bare Nodes are equal).
      def value_attributes
        {}
      end

      # Symbol form of the class basename, used to derive the visitor
      # method (`Atom` -> `visit_atom`, `ElectronConfiguration` ->
      # `visit_electron_configuration`).
      def short_name
        snake = self.class.name.split("::").last
                    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        snake.downcase
      end
    end
  end
end
