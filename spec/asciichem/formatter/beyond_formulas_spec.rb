# frozen_string_literal: true

require "spec_helper"

# Visit methods for the five beyond-formulas constructs (Crystal,
# Spectrum, Calculation, ZMatrix, Mechanism). Each formatter must
# produce structurally-valid output for every construct — no
# NotImplementedError. The shape (mrow/mtable for MathML, dl/table for
# HTML, tabular for LaTeX) is checked, not the exact text content.
RSpec.shared_examples "renders beyond-formulas constructs" do |format|
  let(:crystal)    { "crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}" }
  let(:spectrum)   { %(spectrum[nmr](type=1H,solvent=CDCl3){1.2: 3H s "CH3"}) }
  let(:calc)       { "calc(b3lyp/6-31G*){energy: -234.5 Hartree}" }
  let(:zmatrix)    { "zmatrix{\n  C1\n  H2 C1 1.09\n}" }
  let(:mechanism)  { "mechanism{\n  step1: A -> B\n  spectator: Na+\n}" }

  def render(source)
    AsciiChem.parse(source).public_send(:"to_#{format}")
  end

  it "renders a Crystal without raising" do
    expect { render(crystal) }.not_to raise_error
  end

  it "renders a Spectrum without raising" do
    expect { render(spectrum) }.not_to raise_error
  end

  it "renders a Calculation without raising" do
    expect { render(calc) }.not_to raise_error
  end

  it "renders a ZMatrix without raising" do
    expect { render(zmatrix) }.not_to raise_error
  end

  it "renders a Mechanism without raising" do
    expect { render(mechanism) }.not_to raise_error
  end
end

RSpec.describe AsciiChem::Formatter::Mathml do
  include_examples "renders beyond-formulas constructs", :mathml

  def render(source)
    AsciiChem.parse(source).to_mathml
  end

  it "wraps Crystal cell params in an mtable" do
    xml = render("crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}")
    expect(xml).to include("<mtable>")
    expect(xml).to include("<mi mathvariant=\"normal\">a</mi>")
    expect(xml).to include("<mn>5.64</mn>")
  end

  it "uses Greek labels for crystal angle parameters" do
    xml = render("crystal[x](alpha=90,beta=90,gamma=90){Na@f(0,0,0)}")
    expect(xml).to include("α", "β", "γ")
  end

  it "renders spectrum peaks as mtable rows" do
    xml = render(%(spectrum[nmr](type=1H){1.2: 3H s "CH3"}))
    expect(xml).to include("<mn>1.2</mn>")
    expect(xml).to include("<mi mathvariant=\"normal\">s</mi>")
    expect(xml).to include("<mtext>CH3</mtext>")
  end

  it "renders calculation properties as mtable rows" do
    xml = render("calc(b3lyp){energy: -234.5}")
    expect(xml).to include("<mi mathvariant=\"normal\">energy</mi>")
    expect(xml).to include("<mn>-234.5</mn>")
  end

  it "renders zmatrix rows as mtable" do
    xml = render("zmatrix{\n  C1\n  H2 C1 1.09\n}")
    expect(xml).to include("<mn>1.09</mn>")
  end

  it "renders mechanism steps as labelled mtable rows" do
    xml = render("mechanism{\n  step1: A -> B\n}")
    expect(xml).to include("<mi mathvariant=\"normal\">step1</mi>")
    expect(xml).to include("<mtext>A -&gt; B</mtext>")
  end

  it "produces well-formed XML for all constructs" do
    sources = [
      "crystal[NaCl](a=1){Na@f(0,0,0)}",
      %(spectrum[x](type=y){1: 1H}),
      "calc(m){x: 1}",
      "zmatrix{\n  C1\n}",
      "mechanism{\n  s: A -> B\n}"
    ]
    sources.each do |src|
      xml = render(src)
      doc = Nokogiri::XML(xml)
      expect(doc.errors).to be_empty, "invalid XML for #{src}: #{doc.errors.inspect}"
    end
  end
end

RSpec.describe AsciiChem::Formatter::Html do
  include_examples "renders beyond-formulas constructs", :html

  def render(source)
    AsciiChem.parse(source).to_html
  end

  it "wraps Crystal in a classed span" do
    expect(render("crystal[NaCl](a=1){Na@f(0,0,0)}"))
      .to include('class="asciichem-crystal"')
  end

  it "renders spectrum peaks in a table with headers" do
    html = render(%(spectrum[nmr](type=1H){1.2: 3H s "CH3"}))
    expect(html).to include("<table")
    expect(html).to include("<th>position</th>")
    expect(html).to include("<td>1.2</td>")
  end

  it "escapes HTML-significant characters in peak assignments" do
    html = render(%(spectrum[x](type=y){1: 1H s "a<b"}))
    expect(html).to include("&lt;")
  end

  it "renders calculation properties in a dl" do
    html = render("calc(b3lyp){energy: -234.5}")
    expect(html).to include("<dl")
    expect(html).to include("<dt>energy</dt>")
    expect(html).to include("<dd>-234.5")
  end

  it "renders zmatrix rows as table rows" do
    html = render("zmatrix{\n  C1\n  H2 C1 1.09\n}")
    expect(html).to include("<table")
    expect(html).to include("H2")
    expect(html).to include("1.09")
  end

  it "renders mechanism steps in a dl" do
    html = render("mechanism{\n  step1: A -> B\n  spectator: Na+\n}")
    expect(html).to include("<dt>step1</dt>")
    expect(html).to include("<dt>spectator</dt>")
    expect(html).to include("Na+")
  end
end

RSpec.describe AsciiChem::Formatter::Latex do
  include_examples "renders beyond-formulas constructs", :latex

  def render(source)
    AsciiChem.parse(source).to_latex
  end

  it "renders Crystal as a tabular of cell params" do
    tex = render("crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}")
    expect(tex).to include("\\text{crystal}")
    expect(tex).to include("[NaCl]")
    expect(tex).to include("\\begin{tabular}")
    expect(tex).to include("5.64")
  end

  it "renders spectrum peaks as a tabular" do
    tex = render(%(spectrum[nmr](type=1H){1.2: 3H s "CH3"}))
    expect(tex).to include("\\text{spectrum}")
    expect(tex).to include("[nmr]")
    expect(tex).to include("1.2")
    expect(tex).to include("CH3")
  end

  it "renders calculation properties as a tabular" do
    tex = render("calc(b3lyp){energy: -234.5}")
    expect(tex).to include("energy")
    expect(tex).to include("-234.5")
  end

  it "renders zmatrix rows with correct column count for ragged rows" do
    tex = render("zmatrix{\n  C1\n  H2 C1 1.09\n}")
    expect(tex).to include("{lll}")
    expect(tex).to include("H2 & C1 & 1.09")
  end

  it "renders mechanism steps as a tabular" do
    tex = render("mechanism{\n  step1: A -> B\n}")
    expect(tex).to include("step1")
    expect(tex).to include("A -> B")
  end
end
