# frozen_string_literal: true

require 'spec_helper'

# Depiction backends (TODO.v2/13 item 7): depictions are views — a
# backend maps a molecule to a Layout::Result and the renderer never
# learns which engine placed the atoms.
# A real backend implementation, not a double: it records calls and
# returns one positioned atom far from the built-in layout.
class LayoutBackendSpecBackend
  attr_reader :calls

  def initialize
    @calls = []
  end

  def layout(molecule, algorithm: 'layered')
    @calls << [molecule, algorithm]
    AsciiChem::Layout::Result.new(
      atoms: [AsciiChem::Layout::PositionedAtom.new(
        id: 1, element: 'C', x: 111.0, y: 222.0
      )],
      bonds: [], width: 111.0, height: 222.0
    )
  end
end

RSpec.describe 'Layout depiction backends' do
  let(:backend) { LayoutBackendSpecBackend.new }
  let(:formula) { AsciiChem.parse_smiles('C1CCCCC1') }
  let(:cyclohexane) { formula.nodes.first }

  after { AsciiChem::Layout.backend = nil }

  it 'defaults to the built-in elkrb backend' do
    expect(AsciiChem::Layout.backend).to be_a(AsciiChem::Layout::BuiltinBackend)
  end

  it 'returns the configured backend result' do
    AsciiChem::Layout.backend = backend
    result = AsciiChem::Layout.layout(cyclohexane)
    expect(result.atoms.map(&:x)).to eq([111.0])
    expect(backend.calls.length).to eq(1)
  end

  it 'passes the algorithm through to the backend' do
    AsciiChem::Layout.backend = backend
    AsciiChem::Layout.layout(cyclohexane, algorithm: 'force')
    expect(backend.calls.first.last).to eq('force')
  end

  it 'reaches the structural SVG renderer without edits to it' do
    builtin_svg = formula.to_structural_svg
    AsciiChem::Layout.backend = backend
    backend_svg = formula.to_structural_svg
    expect(backend_svg).not_to eq(builtin_svg)
    expect(backend_svg).to include('<svg')
  end

  it 'restores the built-in backend when cleared' do
    AsciiChem::Layout.backend = backend
    AsciiChem::Layout.backend = nil
    expect(AsciiChem::Layout.layout(cyclohexane).atoms.length).to eq(6)
  end
end
