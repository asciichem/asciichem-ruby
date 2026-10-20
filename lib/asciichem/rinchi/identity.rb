# frozen_string_literal: true

module AsciiChem
  module Rinchi
    # Derived identity of a reaction: the standard RInChI string and
    # its long/short InChIKeys. Value object returned by engines.
    Identity = Struct.new(:rinchi, :short_rinchikey, :long_rinchikey,
                          keyword_init: true)
  end
end
