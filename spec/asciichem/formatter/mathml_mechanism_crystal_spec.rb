# frozen_string_literal: true

require 'spec_helper'

# Byte-exact MathML pins for the Mechanism and Crystal constructs.
# The shapes are RS-authoritative (asciichem-rs render_mechanism /
# render_crystal) and byte-matched against the rs/ts/py runtimes on
# these same inputs. The flows-step and full-NaCl-cell inputs are the
# ones the shared corpus pins as format/mathml/mechanism-flows and
# format/mathml/crystal-cell; the others are the rest of the
# mechanisms.json family.
RSpec.describe AsciiChem::Formatter::Mathml do
  def render(source)
    AsciiChem.parse(source).to_mathml
  end

  describe 'the mechanisms.json flows-step input (the mechanism-flows corpus golden input)' do
    it 'pins the flows-step MathML bytes' do
      input = "mechanism{\n  s1: A-B -> A + B | flow: A-B > A; B > B-C\n  s2: A + C -> A-C\n}"
      expect(render(input)).to eq(<<~MATHML)
        <?xml version="1.0" encoding="UTF-8"?>
        <math xmlns="http://www.w3.org/1998/Math/MathML">
          <mrow>
            <mrow>
              <mi mathvariant="normal">mechanism</mi>
              <mtable>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">s1</mi>
                  </mtd>
                  <mtd>
                    <mtext>A-B -&gt; A + B</mtext>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">s2</mi>
                  </mtd>
                  <mtd>
                    <mtext>A + C -&gt; A-C</mtext>
                  </mtd>
                </mtr>
              </mtable>
            </mrow>
          </mrow>
        </math>
      MATHML
    end
  end

  describe 'the mechanisms.json flows-with-spectator input' do
    it 'pins the flows-spectator MathML bytes' do
      input = "mechanism{\n  s1: A -> B | flow: A > B\n  spectator: Na^+\n}"
      expect(render(input)).to eq(<<~MATHML)
        <?xml version="1.0" encoding="UTF-8"?>
        <math xmlns="http://www.w3.org/1998/Math/MathML">
          <mrow>
            <mrow>
              <mi mathvariant="normal">mechanism</mi>
              <mtable>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">s1</mi>
                  </mtd>
                  <mtd>
                    <mtext>A -&gt; B</mtext>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">spectator</mi>
                  </mtd>
                  <mtd>
                    <mtext>Na^+</mtext>
                  </mtd>
                </mtr>
              </mtable>
            </mrow>
          </mrow>
        </math>
      MATHML
    end
  end

  describe 'the mechanisms.json no-flows input' do
    it 'pins the no-flows MathML bytes' do
      input = "mechanism{\n  step1: A -> B\n}"
      expect(render(input)).to eq(<<~MATHML)
        <?xml version="1.0" encoding="UTF-8"?>
        <math xmlns="http://www.w3.org/1998/Math/MathML">
          <mrow>
            <mrow>
              <mi mathvariant="normal">mechanism</mi>
              <mtable>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">step1</mi>
                  </mtd>
                  <mtd>
                    <mtext>A -&gt; B</mtext>
                  </mtd>
                </mtr>
              </mtable>
            </mrow>
          </mrow>
        </math>
      MATHML
    end
  end

  describe 'the full NaCl cell (the crystal-cell corpus golden input)' do
    input = 'crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m){Na@f(0,0,0) Cl@f(0.5,0.5,0.5)}'

    it 'pins the crystal-cell MathML bytes' do
      expect(render(input)).to eq(<<~MATHML)
        <?xml version="1.0" encoding="UTF-8"?>
        <math xmlns="http://www.w3.org/1998/Math/MathML">
          <mrow>
            <mrow>
              <mi mathvariant="normal">crystal</mi>
              <mrow>
                <mo>[</mo>
                <mtext>NaCl</mtext>
                <mo>]</mo>
              </mrow>
              <mtable>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">a</mi>
                  </mtd>
                  <mtd>
                    <mn>5.64</mn>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">b</mi>
                  </mtd>
                  <mtd>
                    <mn>5.64</mn>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">c</mi>
                  </mtd>
                  <mtd>
                    <mn>5.64</mn>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">α</mi>
                  </mtd>
                  <mtd>
                    <mn>90</mn>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">β</mi>
                  </mtd>
                  <mtd>
                    <mn>90</mn>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mi mathvariant="normal">γ</mi>
                  </mtd>
                  <mtd>
                    <mn>90</mn>
                  </mtd>
                </mtr>
              </mtable>
              <mtable>
                <mtr>
                  <mtd>
                    <mn>1</mn>
                  </mtd>
                  <mtd>
                    <mi mathvariant="normal">Na</mi>
                  </mtd>
                </mtr>
                <mtr>
                  <mtd>
                    <mn>2</mn>
                  </mtd>
                  <mtd>
                    <mi mathvariant="normal">Cl</mi>
                  </mtd>
                </mtr>
              </mtable>
            </mrow>
          </mrow>
        </math>
      MATHML
    end

    it 'round-trips via Text — the L1 form is lossless here' do
      # The corpus's crystal-cell golden omits the roundTrip flag not
      # because Text drifts (it does not, as pinned here) but because
      # the v1 WIRE form carries no fractional coordinates — they are
      # model-only render data, so the wire round-trip gates see
      # drift. Same posture as the corpus's cml/crystal-full fixture.
      expect(AsciiChem.parse(input).to_text).to eq(input)
    end
  end
end
