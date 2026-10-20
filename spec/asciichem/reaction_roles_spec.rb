# frozen_string_literal: true

require 'spec_helper'

# Reaction-role derivation (item 4): explicit typed entries win; the
# writing convention (catalysts above the arrow, solvents below) is the
# fallback for free text.
RSpec.describe AsciiChem::ReactionRoles do
  def roles_for(source)
    reaction = AsciiChem.parse(source).nodes.first
    described_class.roles_for(reaction)
  end

  it 'keeps a typed catalyst entry verbatim' do
    roles = roles_for('A ->[cat: Pd, Pt] B')
    expect(roles[:catalysts]).to eq(['Pd, Pt'])
  end

  it 'routes typed roles regardless of side' do
    roles = roles_for('A ->[heat][cat: Pd] B')
    expect(roles[:catalysts]).to eq(['Pd'])
    expect(roles[:reagents]).to eq(['heat'])
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

  it 'classifies free text after typed entries in the same bracket' do
    roles = roles_for('A ->[cat: Pd; reflux] B')
    expect(roles[:catalysts]).to eq(['Pd'])
    expect(roles[:reagents]).to eq(['reflux'])
  end

  it 'answers empty for reactions without conditions' do
    roles = roles_for('A -> B')
    expect(roles.values).to all(be_empty)
  end
end
