# frozen_string_literal: true

require 'spec_helper'

# The mechanism step graph (TODO.v2/13 item 4): derived from the
# verbatim `mechanism{}` entries — steps, catalysts (species on both
# sides of a step), and links (a product species reused as a reactant
# by a later step). Computed; the text and wire forms are unchanged.
RSpec.describe AsciiChem::MechanismGraph do
  def graph_for(source)
    described_class.for(AsciiChem.parse(source).nodes.first)
  end

  def mechanism_body(*lines)
    "mechanism{\n  #{lines.join("\n  ")}\n}"
  end

  it 'parses each step value into a reaction' do
    graph = graph_for(mechanism_body('step1: A + B -> C'))
    expect(graph.steps.length).to eq(1)
    expect(graph.steps.first.label).to eq('step1')
    expect(graph.steps.first.reaction).to be_a(AsciiChem::Model::Reaction)
  end

  it 'links a later step that consumes an earlier product' do
    graph = graph_for(mechanism_body('s1: A + B -> C', 's2: C -> D'))
    expect(graph.links.map { |l| [l.from, l.to, l.species] })
      .to eq([['s1', 's2', ['C']]])
  end

  it 'links chains transitively step to step, not across gaps' do
    graph = graph_for(mechanism_body('s1: A -> B', 's2: B -> C', 's3: C -> D'))
    expect(graph.links.map { |l| [l.from, l.to, l.species] })
      .to eq([['s1', 's2', ['B']], ['s2', 's3', ['C']]])
  end

  it 'does not link steps with no shared species' do
    graph = graph_for(mechanism_body('s1: A -> B', 's2: X -> Y'))
    expect(graph.links).to be_empty
  end

  it 'recognises a species on both sides of one step as a catalyst' do
    graph = graph_for(mechanism_body('s1: A + Pd -> B + Pd'))
    expect(graph.steps.first.catalysts).to eq(['Pd'])
  end

  it 'links through a shared catalyst species as well' do
    graph = graph_for(mechanism_body('s1: A + Pd -> B + Pd', 's2: Pd + C -> D'))
    expect(graph.links.map(&:species)).to eq([['Pd']])
  end

  it 'keeps prose entries as nil reactions with no links' do
    graph = graph_for(mechanism_body('s1: proton transfer', 's2: A -> B'))
    expect(graph.steps.first.reaction).to be_nil
    expect(graph.steps.last.reaction).to be_a(AsciiChem::Model::Reaction)
    expect(graph.links).to be_empty
  end

  it 'uses a cascade entry side and exit side for linking' do
    graph = graph_for(mechanism_body('s1: A -> B -> C', 's2: C -> D'))
    expect(graph.links.map { |l| [l.from, l.to, l.species] })
      .to eq([['s1', 's2', ['C']]])
  end

  it 'ignores coefficients when matching species' do
    graph = graph_for(mechanism_body('s1: 2A -> 3B', 's2: 2B -> C'))
    expect(graph.links.map { |l| [l.from, l.to, l.species] })
      .to eq([['s1', 's2', ['B']]])
  end

  it 'leaves the canonical text and model unchanged' do
    source = mechanism_body('s1: A -> B', 's2: B -> C')
    expect(AsciiChem.parse(source).to_text).to eq(source)
  end
end
