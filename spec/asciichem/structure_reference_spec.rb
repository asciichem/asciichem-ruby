# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'the standalone structure reference' do
  # `@smiles("...")` standing alone is an ingest edge (the same
  # posture as the CLI's input modes): the annotation carries the
  # structure in, the model is the molecule the SMILES reader
  # produces (grammar v0.6.0, asciichem-rs#45).

  it 'parses into the ingested molecule' do
    formula = AsciiChem.parse('@smiles("c1cc[nH]c1")')
    molecule = formula.nodes.first
    expect(molecule).to be_a(AsciiChem::Model::Molecule)
    expect(molecule.nodes.grep(AsciiChem::Model::Atom).map(&:element))
      .to eq(%w[C C C N C])
  end

  it 'renders through the existing formatters' do
    mathml = AsciiChem.parse('@smiles("CCO")').to_mathml
    expect(mathml).to include('<mrow')
  end

  it 'canonical text is the expanded ascii form (the ingest-edge loss)' do
    # The reference syntax itself is not preserved — exactly how
    # molfile ingest behaves: the model is the structure, and the
    # Text formatter canonicalises it to ascii.
    expect(AsciiChem.parse('@smiles("CCO")').to_text).to eq('C-C-O')
  end

  it 'keeps the attached form the identifier annotation it has always been' do
    formula = AsciiChem.parse('H_2O @smiles("CCO")')
    molecule = formula.nodes.first
    expect(molecule.identifiers.map(&:convention)).to include('smiles')
    expect(molecule.nodes.grep(AsciiChem::Model::Atom).map(&:element)).to eq(%w[H O])
  end

  it 'rejects other sources at parse time (the grammar hard-codes smiles)' do
    expect { AsciiChem.parse('@molfile("CCO")') }
      .to raise_error(AsciiChem::ParseError, /char 2/)
  end

  it 'rejects dot-disconnected components with guidance' do
    expect { AsciiChem.parse('@smiles("CC.O")') }
      .to raise_error(AsciiChem::ParseError, /one connected structure/)
  end

  it 'carries bracket hydrogens through the pipe' do
    formula = AsciiChem.parse('@smiles("c1cc[nH]c1")')
    molecule = formula.nodes.first
    n = molecule.nodes.grep(AsciiChem::Model::Atom).find { |a| a.element == 'N' }
    expect(n.hydrogens).to eq(1)
  end

  it 'derives the recorded identity from the reference', :engine do
    engine = begin
      AsciiChem::Inchi::NativeEngine.new
    rescue AsciiChem::Error
      skip 'no identity engine (set CHEMOMER_LIB to the built cdylib)'
    end
    formula = AsciiChem.parse('@smiles("c1cc[nH]c1")')
    identity = AsciiChem::Inchi.identity_for(formula.nodes.first, engine: engine)
    expect(identity.inchi).to eq('InChI=1S/C4H5N/c1-2-4-5-3-1/h1-5H')
  end
end
