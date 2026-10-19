# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Engine::PargEngine do
  # Both sides go through the real Parser path (ParseFailed →
  # ParseError wrapping included), so the comparison is end-to-end.
  def reference_model(input)
    AsciiChem::Parser.new(input).parse
  end

  around do |example|
    AsciiChem::Engine.use(:parg)
    example.run
  ensure
    AsciiChem::Engine.use(:parslet)
  end

  it 'is registered under :parg' do
    expect(AsciiChem::Engine.use(:parg)).to eq(described_class)
  end

  it 'vendors an artifact matching the pinned grammar version' do
    expect(described_class.artifact.version).to eq(described_class::PARG_GRAMMAR_VERSION)
  end

  describe 'round-trips the shared-corpus construct matrix' do
    [
      'H_2O', 'H2O', '2H_2O', 'Ca^2+', 'SO_4^2-', '^14C', '_14C',
      'C1-C-C-C-C-C1', 'C12-C-C1-C2', 'CH_3-CH_2-OH',
      '2H_2 + O_2 -> 2H_2O', 'N_2 + 3H_2 <=>[Fe][400C] 2NH_3',
      'A ->[heat] B ->[cool] C', 'Ca(OH)_2', 'Fe(IV)', 'Fe^(II)',
      'CC(=O)OC1=CC=CC=C1C(=O)O', 'Ca^2+ + CO_3^2- -> CaCO_3',
      '(R)-CH_3CH(OH)COOH', ':O', '1s^2 2s^2 2p^6', '`x^2`',
      '"nitrogen gas"', 'H_2O @name("water") @cas("7732-18-5")',
      'H_2O @meta("source","handbook")', '  H_2O  ',
      'C@(10,20)@R@m(2)@t("C1")',
      'crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}',
      'spectrum[nmr](type=1H){1.2: 3H s "CH3"}',
      'calc(b3lyp){energy: -234.5}', 'zmatrix{ C1 H2 C1 1.09 }',
      'mechanism{ step1: A -> B }'
    ].each do |input|
      it input.inspect do
        model = AsciiChem.parse(input)
        expected = reference_model(input)
        expect(model).to eq(expected)
        expect(model.to_text).to eq(expected.to_text)
      end
    end
  end

  it 'renders MathML identical to the reference engine' do
    ['H_2O', 'SO_4^2-', 'Ca(OH)_2', 'N_2 + 3H_2 <=>[Fe][400C] 2NH_3'].each do |input|
      expect(AsciiChem.parse(input).to_mathml).to eq(reference_model(input).to_mathml)
    end
  end

  it 'rejects what the reference engine rejects' do
    ['', '???', 'H_', 'C(=O', '+ H_2O', 'crystal[NaCl', 'zmatrix{ C1 ',
     '@name("x") H_2O', 'Uue'].each do |input|
      expect { AsciiChem.parse(input) }.to raise_error(AsciiChem::ParseError)
      expect { reference_model(input) }.to raise_error(AsciiChem::ParseError)
    end
  end

  # Rejections must match the reference engine, including tail
  # garbage the grammar cannot capture.
  it 'rejects trailing input the reference engine rejects' do
    ['A(oh)GARBAGE', 'H_2O extra', 'Ca(OH)_2 junk'].each do |input|
      expect { reference_model(input) }.to raise_error(AsciiChem::ParseError)
      expect { AsciiChem.parse(input) }.to raise_error(AsciiChem::ParseError)
    end
  end
end
