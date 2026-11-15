# frozen_string_literal: true

module AsciiChem
  module Rinchi
    # The assembled reaction-identity record — the derive direction's
    # output (mirrors asciichem::rinchi's RinchiRecord): the
    # identifier, its RAuxInfo companion line, and the three RInChIKey
    # shapes (the short hashed one under `rinchikey`, per the shared
    # corpus's field naming). Every string is engine-verbatim — the
    # key headers included; the corpus records the keys headerless and
    # the runners strip.
    Record = Struct.new(:rinchi, :rauxinfo, :rinchikey, :long_key, :web_key,
                        keyword_init: true)
  end
end
