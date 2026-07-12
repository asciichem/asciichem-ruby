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
        visitor.public_send(:"visit_#{self.class.short_name}", self)
      rescue NoMethodError => e
        raise unless e.name == :"visit_#{self.class.short_name}"

        raise NotImplementedError,
              "#{visitor.class} does not implement visit_#{self.class.short_name}"
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

      def to_svg
        AsciiChem::Formatter.render(:svg, self)
      end

      # Subclasses override to expose the attributes that participate in
      # equality. Default: empty (so two bare Nodes are equal).
      def value_attributes
        {}
      end

      # Child nodes for traversal. Default: no children. Container
      # classes (Formula, Molecule, Group, Reaction, ReactionCascade)
      # override to expose their contents; leaves (Atom, Bond,
      # EmbeddedMath, Text) inherit the empty default.
      #
      # Used by Linter::Base#walk. Adding a new container class means
      # defining `children` on it — no edits to the linter.
      def children
        []
      end

      # Snake-case form of the class basename, used to derive the visitor
      # method (`Atom` -> `visit_atom`, `ElectronConfiguration` ->
      # `visit_electron_configuration`). Memoised per class so the
      # string transformation runs once per class, not once per visit.
      def self.short_name
        @short_name ||= begin
          snake = name.split("::").last
                      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          snake.downcase
        end
      end
    end
  end
end
