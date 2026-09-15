# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AsciiChem::Engine do
  after { described_class.use(:parslet) }

  it 'defaults to the parslet engine' do
    expect(described_class.current).to eq(AsciiChem::Engine::ParsletEngine)
  end

  it 'parses through the default engine' do
    expect(AsciiChem.parse('H_2O').to_text).to eq('H_2O')
  end

  it 'rejects unknown engine names' do
    expect { described_class.use(:rpmpeg) }
      .to raise_error(AsciiChem::Engine::Error, /unknown engine :rpmpeg/)
  end

  it 'restores the previous engine after a switch' do
    described_class.use(:parslet)
    expect(AsciiChem.parse('Ca^2+').to_text).to eq('Ca^2+')
  end

  describe 'parsanol availability' do
    it 'raises install guidance when the gem is absent' do
      next if parsanol_loadable?

      expect { described_class.use(:parsanol) }
        .to raise_error(AsciiChem::Engine::NotAvailableError, /gem "parsanol"/)
    end
  end

  describe 'under the parsanol engine' do
    around do |example|
      skip 'parsanol gem not installed' unless parsanol_loadable?

      described_class.use(:parsanol)
      example.run
    ensure
      described_class.use(:parslet)
    end

    it 'round-trips the shared-corpus construct matrix' do
      [
        'H_2O',
        '2H_2O',
        '^14C',
        'SO_4^2-',
        '(R)-2H_2O',
        '2H_2 + O_2 <=>[Fe][400C] 2NH_3',
        'A -> B -> C -> D',
        '`K_c = 1` H_2O',
        'H_2O "heat" 2H_2O',
        '1s^2 2s^2 2p^6'
      ].each do |source|
        expect(AsciiChem.parse(source).to_text).to eq(source), source
      end
    end

    it "raises AsciiChem::ParseError (not the engine's) on rejects" do
      expect { AsciiChem.parse('((') }.to raise_error(AsciiChem::ParseError)
    end
  end

  private

  def parsanol_loadable?
    @parsanol_loadable ||= begin
      require 'parsanol/parslet'
      true
    rescue LoadError
      false
    end
  end
end
