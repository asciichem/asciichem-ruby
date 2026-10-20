# frozen_string_literal: true

require 'spec_helper'

# Reaction-roles perception (item 4 slice A): the writing convention
# (catalysts above the arrow, solvents below) derives structured role
# hints from the free-form conditions text.
RSpec.describe AsciiChem::ReactionRoles do
  def roles_for(source)
    reaction = AsciiChem.parse(source).nodes.first
    described_class.roles_for(reaction)
  end

  it 'classifies catalyst hints above the arrow' do
    roles = roles_for('A ->[cat: Pd, Pt] B')
    expect(roles[:catalysts]).to eq(['cat:', 'Pd', 'Pt'])
  end

  it 'classifies solvent hints below the arrow' do
    roles = roles_for('A ->[heat][THF, H2O] B')
    expect(roles[:solvents]).to eq(%w[THF H2O])
  end

  it 'keeps unclassified above entries as reagent hints' do
    roles = roles_for('A ->[heat][THF] B')
    expect(roles[:reagents]).to eq(['heat'])
    expect(roles[:solvents]).to eq(['THF'])
  end

  it 'answers empty for reactions without conditions' do
    roles = roles_for('A -> B')
    expect(roles.values).to all(be_empty)
  end
end
