# frozen_string_literal: true

# Internal XML helper. Currently a thin marker module kept for parity
# with future formatters that need XML construction without Nokogiri
# (e.g. JRuby). The Mathml formatter uses Nokogiri directly.
module AsciiChem
  module XmlBuilder
  end
end
