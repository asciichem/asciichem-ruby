# frozen_string_literal: true

module AsciiChem
  module Inchi
    # Derived identity of a structure: the standard InChI string and
    # its InChIKey. Value object returned by engines.
    Identity = Struct.new(:inchi, :inchikey, keyword_init: true)
  end
end
