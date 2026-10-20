# frozen_string_literal: true

require 'spec_helper'

# Structured role entries (TODO.v2/13 item 4, slice 1): the bracket
# text stays verbatim (round-trip source); typed `role: value` entries
# are derived from it. Unknown prefixes are free text — never an error.
RSpec.describe 'Reaction conditions entries' do
  def entries_for(text)
    AsciiChem.parse(text).nodes.first.conditions.entries
  end

  it 'parses a typed catalyst entry above the arrow' do
    entries = entries_for('A ->[cat: Pd] B')
    expect(entries.length).to eq(1)
    expect(entries.first.role).to eq(:catalyst)
    expect(entries.first.value).to eq('Pd')
    expect(entries.first.side).to eq(:above)
  end

  it 'parses typed entries on both sides' do
    entries = entries_for('A ->[cat: Pd][solv: THF] B')
    expect(entries.map { |e| [e.role, e.value, e.side] }).to eq(
      [[:catalyst, 'Pd', :above], [:solvent, 'THF', :below]]
    )
  end

  it 'separates multiple entries in one bracket with semicolons' do
    entries = entries_for('A ->[cat: Pd; solv: THF] B')
    expect(entries.map { |e| [e.role, e.value] }).to eq(
      [[:catalyst, 'Pd'], [:solvent, 'THF']]
    )
  end

  it 'keeps free text entries verbatim alongside typed ones' do
    entries = entries_for('A ->[cat: Pd; reflux] B')
    expect(entries.map { |e| [e.role, e.value] }).to eq(
      [[:catalyst, 'Pd'], [nil, 'reflux']]
    )
  end

  it 'keeps an unknown prefix as free text (lossless)' do
    entries = entries_for('A ->[temp: 80] B')
    expect(entries.map { |e| [e.role, e.value] }).to eq([[nil, 'temp: 80']])
  end

  it 'maps role spellings to the same role' do
    entries = entries_for('A ->[catalyst: Ni][solvent: EtOH] B')
    expect(entries.map(&:role)).to eq(%i[catalyst solvent])
  end

  it 'returns no entries without conditions' do
    expect(entries_for('A -> B')).to be_empty
  end

  it 'round-trips every entry form through canonical text' do
    ['A ->[cat: Pd] B',
     'A ->[cat: Pd][solv: THF] B',
     'A ->[cat: Pd; reflux] B',
     'A ->[temp: 80] B'].each do |text|
      expect(AsciiChem.parse(text).to_text).to eq(text)
    end
  end
end
