# frozen_string_literal: true

require 'spec_helper'
require 'chemicalml'
require 'asciichem/cml'

# Spectrum rides the aci: top-level text channel (the canonical text
# render inside `<aci:spectrum position="N">`, re-parsed on read) —
# the single-representation contract shared by crystal/spectrum/
# zmatrix/calculation/mechanism (ruby#167). Native <spectrum> wire is
# NOT emitted any more; the read side still accepts it for files
# written by pre-1.0 emits (chemicalml 0.3.0-era).
RSpec.describe 'Spectrum CML channel (aci: text carrier)' do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  let(:source) { %(spectrum[nmr](type=1H,solvent=CDCl3){1.2: 3H s "CH3"}) }

  def cml_of(src)
    AsciiChem.parse(src).to_cml
  end

  def parsed_formula(xml)
    AsciiChem::Cml.parse(xml)
  end

  describe 'emit' do
    it 'emits the single aci:spectrum channel (no native wire duplicate)' do
      xml = cml_of(source)
      expect(xml).to include('<aci:spectrum')
      expect(xml).not_to include('<spectrum>')
      expect(xml).not_to include('<molecule')
    end

    it 'carries the canonical text render at the node position' do
      canonical = AsciiChem.parse(source).to_text
      expect(cml_of(source)).to include(%(<aci:spectrum position="0">#{canonical}</aci:spectrum>))
    end
  end

  describe 'round-trip' do
    it 'preserves Spectrum identity on full CML round-trip' do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Spectrum)
    end

    it 'preserves spectrum type' do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.type).to eq('nmr')
    end

    it 'preserves params (type, solvent)' do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.params['type']).to eq('1H')
      expect(formula.nodes.first.params['solvent']).to eq('CDCl3')
    end

    it 'preserves peak data' do
      formula = parsed_formula(cml_of(source))
      peak = formula.nodes.first.peaks.first
      expect(peak.position).to eq('1.2')
      expect(peak.intensity).to eq('3H')
      expect(peak.multiplicity).to eq('s')
      expect(peak.assignment).to eq('CH3')
    end
  end

  describe 'backwards compat' do
    it 'still parses legacy aci: text-carrier Spectrum XML' do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:spectrum position="0">spectrum[legacy](type=x){1: 1H s "a"}</aci:spectrum>
        </cml>
      CML
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Spectrum)
      expect(formula.nodes.first.type).to eq('legacy')
    end

    it 'still parses the native <spectrum> wire written by pre-1.0 emits' do
      # The chemicalml 0.3.0-era emit wrapped Spectrum in a <molecule>
      # with a native <spectrum>/<peakList> child. FromCanonical keeps
      # reading that shape.
      xml = '<cml xmlns="http://www.xml-cml.org/schema"><molecule id="m1" title="spectrum:nmr">' \
            '<spectrum title="nmr" format="1H" condition="CDCl3"><peakList>' \
            '<peak title="CH3" xValue="1.2" yValue="3H" yMultiplicity="s"/>' \
            '</peakList></spectrum></molecule></cml>'
      spectrum = parsed_formula(xml).nodes.first
      expect(spectrum).to be_an(AsciiChem::Model::Spectrum)
      expect(spectrum.type).to eq('nmr')
      expect(spectrum.params['type']).to eq('1H')
      expect(spectrum.params['solvent']).to eq('CDCl3')
      expect(spectrum.peaks.first.position).to eq('1.2')
      expect(spectrum.peaks.first.assignment).to eq('CH3')
    end
  end
end
