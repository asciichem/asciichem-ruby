# frozen_string_literal: true

require 'spec_helper'

# MDL RXN emission (TODO.v2/13 item 4, RInChI): one $RXN container,
# reactants then products as V2000 mol blocks. RXN carries species,
# not stoichiometry; a formula-only species (no bonds) is not a
# structure and is refused by the molfile leg, by design.
RSpec.describe AsciiChem::Rxn do
  def reaction_for(source)
    AsciiChem.parse(source).nodes.first
  end

  it 'writes the RXN header, counts, and one mol block per species' do
    text = described_class.write(reaction_for('C-C-O + O=O -> C-C=O + O'))
    lines = text.lines
    expect(lines[0].strip).to eq('$RXN')
    expect(lines[4]).to eq("  2  2\n")
    expect(lines.count { |line| line.strip == '$MOL' }).to eq(4)
    expect(text).to end_with("M  END\n")
  end

  it 'emits single-atom species (ions are structures)' do
    text = described_class.write(reaction_for('Na + Cl-Cl -> Na-Cl + Cl'))
    expect(text.lines[4]).to eq("  2  2\n")
    expect(text.scan('$MOL').length).to eq(4)
  end

  it 'does not represent stoichiometric coefficients as extra blocks' do
    text = described_class.write(reaction_for('2C-C + C-C -> 2C-C-C'))
    expect(text.lines[4]).to eq("  2  1\n")
    expect(text.scan('$MOL').length).to eq(3)
  end

  it 'refuses formula-only species (not structures)' do
    expect { described_class.write(reaction_for('H_2O -> H_2O')) }
      .to raise_error(AsciiChem::ParseError, /not a structure/)
  end

  it 'names the reaction when asked' do
    text = described_class.write(reaction_for('A -> B'), name: 'test')
    expect(text.lines[1]).to eq("test\n")
  end
end
