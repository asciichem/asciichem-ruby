# frozen_string_literal: true

module AsciiChem
  module Wire
    # Common base for wire nodes: declares the `type` discriminator
    # attribute and registers the class under its wire type string.
    # The converter sets `type` explicitly on construction because
    # lutaml-model omits default values on serialisation.
    class Base < Lutaml::Model::Serializable
      class << self
        def wire_type(name = nil)
          return @wire_type if name.nil?

          @wire_type = name.to_s
          AsciiChem::Wire::REGISTRY[name.to_s] = self
        end
      end

      attribute :type, :string
      json do
        map "type", to: :type
      end
    end
  end
end
