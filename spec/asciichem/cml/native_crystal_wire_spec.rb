# frozen_string_literal: true

require 'spec_helper'
require 'chemicalml'
require 'asciichem/cml'

# Crystal rides the aci: top-level text channel (the canonical text
# render inside `<aci:crystal position="N">`, re-parsed on read) — the
# single-representation contract shared by crystal/spectrum/zmatrix/
# calculation/mechanism (ruby#167). Native <crystal> wire is NOT
# emitted any more; the read side still accepts it for files written
# by pre-1.0 emits (chemicalml 0.3.0-era).
RSpec.describe 'Crystal CML channel (aci: text carrier)' do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  let(:source) do
    'crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m)' \
      '{Na@f(0,0,0) Cl@f(0.5,0.5,0.5)}'
  end

  def cml_of(src)
    AsciiChem.parse(src).to_cml
  end

  def parsed_formula(xml)
    AsciiChem::Cml.parse(xml)
  end

  describe 'emit' do
    it 'emits the single aci:crystal channel (no native wire duplicate)' do
      xml = cml_of(source)
      expect(xml).to include('<aci:crystal')
      expect(xml).not_to include('<crystal>')
      expect(xml).not_to include('<molecule')
    end

    it 'carries the canonical text render at the node position' do
      expect(cml_of(source)).to include(%(<aci:crystal position="0">#{source}</aci:crystal>))
    end
  end

  describe 'round-trip' do
    it 'preserves Crystal identity on full CML round-trip' do
      xml = cml_of(source)
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Crystal)
    end

    it 'preserves spacegroup' do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.spacegroup).to eq('Fm-3m')
    end

    it 'preserves cell parameters' do
      formula = parsed_formula(cml_of(source))
      crystal = formula.nodes.first
      expect(crystal.a).to eq('5.64')
      expect(crystal.b).to eq('5.64')
      expect(crystal.c).to eq('5.64')
    end

    it 'preserves atoms with fractional coords' do
      formula = parsed_formula(cml_of(source))
      crystal = formula.nodes.first
      expect(crystal.atoms.length).to eq(2)
      expect(crystal.atoms.map(&:element)).to contain_exactly('Na', 'Cl')
    end

    it 'preserves fractional coordinates exactly (no float widening)' do
      formula = parsed_formula(cml_of(source))
      expect(formula.to_text).to eq(source)
    end
  end

  describe 'backwards compat' do
    it 'still parses legacy aci: text-carrier Crystal XML' do
      # An older AsciiChem (< 0.9) would emit Crystal as
      # <aci:crystal position="0">crystal[...]{...}</aci:crystal>
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:crystal position="0">crystal[Legacy](a=1.0){Na@f(0,0,0)}</aci:crystal>
        </cml>
      CML
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Crystal)
      expect(formula.nodes.first.name).to eq('Legacy')
    end

    it 'still parses the native <crystal> wire written by pre-1.0 emits' do
      # The chemicalml 0.3.0-era emit wrapped Crystal in a <molecule>
      # with a native <crystal> child (scalars + symmetry) and an
      # <atomArray> of fractional-coordinate atoms. FromCanonical
      # keeps reading that shape.
      xml = '<cml xmlns="http://www.xml-cml.org/schema"><molecule id="m1" title="NaCl">' \
            '<atomArray><atom id="a1" elementType="Na" xFract="0.0" yFract="0.0" zFract="0.0"/></atomArray>' \
            '<crystal><scalar title="a">5.64</scalar><symmetry spaceGroup="Fm-3m"/></crystal>' \
            '</molecule></cml>'
      formula = parsed_formula(xml)
      crystal = formula.nodes.first
      expect(crystal).to be_an(AsciiChem::Model::Crystal)
      expect(crystal.name).to eq('NaCl')
      expect(crystal.a).to eq('5.64')
      expect(crystal.spacegroup).to eq('Fm-3m')
      expect(crystal.atoms.map(&:element)).to eq(['Na'])
    end
  end
end
