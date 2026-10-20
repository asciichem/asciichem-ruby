# frozen_string_literal: true

require 'spec_helper'

# Stoichiometry as model data (item 4 slice 2): the coefficients are
# already in the model; Reaction#stoichiometry exposes them
# normalized — species text (coefficient-stripped) → integer.
RSpec.describe 'Reaction#stoichiometry' do
  it 'normalizes the combustion of hydrogen' do
    reaction = AsciiChem.parse('2H_2 + O_2 -> 2H_2O').nodes.first
    expect(reaction.stoichiometry).to eq(
      reactants: { 'H_2' => 2, 'O_2' => 1 },
      products: { 'H_2O' => 2 }
    )
  end

  it 'treats an absent coefficient as one' do
    reaction = AsciiChem.parse('N_2 + 3H_2 -> 2NH_3').nodes.first
    expect(reaction.stoichiometry[:reactants]['N_2']).to eq(1)
    expect(reaction.stoichiometry[:reactants]['H_2']).to eq(3)
  end

  it 'keeps a species that appears on both sides separate per side' do
    reaction = AsciiChem.parse('A + B -> B + C').nodes.first
    expect(reaction.stoichiometry[:reactants]).to eq('A' => 1, 'B' => 1)
    expect(reaction.stoichiometry[:products]).to eq('B' => 1, 'C' => 1)
  end

  it 'sums duplicate species within a side' do
    reaction = AsciiChem.parse('C + C -> C_2').nodes.first
    expect(reaction.stoichiometry[:reactants]).to eq('C' => 2)
  end
end
