# frozen_string_literal: true

require 'spec_helper'

# Mechanism electron-flow markers (TODO.v2/13 item 4, slice 4c): a
# step value is its reaction followed by `| flow: SRC > DST` clauses
# (semicolon-separated). Sources/targets stay verbatim; unknown
# clauses are rejected, never dropped.
RSpec.describe 'Mechanism electron-flow markers' do
  def mechanism_for(body)
    AsciiChem.parse("mechanism{\n  #{body}\n}")
  end

  def step(body)
    mechanism_for(body).nodes.first.steps.first
  end

  it 'parses a flow clause into typed markers' do
    parsed = step('s1: A-B -> A + B | flow: A-B > A; B > B-C')
    expect(parsed.reaction).to eq('A-B -> A + B')
    expect(parsed.flows.map { |f| [f.source, f.target] }).to eq(
      [['A-B', 'A'], ['B', 'B-C']]
    )
  end

  it 'keeps steps without flows empty' do
    expect(step('s1: A -> B').flows).to eq([])
  end

  it 'round-trips the canonical text exactly' do
    source = "mechanism{\n  s1: A-B -> A + B | flow: A-B > A; B > B-C\n  s2: A + C -> A-C\n}"
    expect(AsciiChem.parse(source).to_text).to eq(source)
  end

  it 'rejects an unknown clause kind instead of dropping it' do
    expect { mechanism_for('s1: A -> B | curve: A > B') }
      .to raise_error(AsciiChem::ParseError, /unknown clause/)
  end

  it 'rejects a malformed flow arrow' do
    expect { mechanism_for('s1: A -> B | flow: A >') }
      .to raise_error(AsciiChem::ParseError, /malformed flow/)
  end

  it 'carries flows into the step graph' do
    graph = AsciiChem::MechanismGraph.for(mechanism_for('s1: A -> B | flow: A > B').nodes.first)
    expect(graph.steps.first.flows.map(&:source)).to eq(['A'])
  end

  it 'emits flows on the wire' do
    json = mechanism_for('s1: A -> B | flow: A > B').to_model_json
    flows = JSON.parse(json)['nodes'][0]['steps'][0]['flows']
    expect(flows).to eq([{ 'source' => 'A', 'target' => 'B' }])
  end

  it 'omits flows from the wire when a step has none' do
    json = mechanism_for('s1: A -> B').to_model_json
    expect(JSON.parse(json)['nodes'][0]['steps'][0]).not_to have_key('flows')
  end

  it 'parses spectator text into molecules on the wire' do
    json = mechanism_for("s1: A -> B\n  spectator: Na^+").to_model_json
    spectator = JSON.parse(json)['nodes'][0]['spectators'][0]
    expect(spectator['nodes'][0]['element']).to eq('Na')
    expect(spectator['nodes'][0]['charge']).to eq('+')
  end

  it 'rejects a spectator that is not valid AsciiChem' do
    expect { mechanism_for("s1: A -> B\n  spectator: Na+").to_model_json }
      .to raise_error(AsciiChem::ParseError, /spectator is not valid AsciiChem/)
  end
end
