
require "spec"
require "./mini_crystal_wiki"
require "crystagiri"
require "file_utils"
require "string_scanner"

describe "Wiki" do

  it "StringScanner scans strings" do
    s = StringScanner.new("a aabbcc c")
    s.eos?.should be_false
    s.scan(/a/).should eq("a")
    s.scan(/\s*/).should eq(" ")
    s.scan(/aabbcc/).should eq("aabbcc")
    s.scan(/\s*/).should eq(" ")
    s.scan(/c/).should eq("c")
    s.eos?.should be_true
       
    converters = [
      { /aabbcc/, ->(s : String){ "<" + s + ">"} },
      { /\s+/, ->(s : String){ s } },
      { /a/, ->(s : String){ "z" } },
      { /b/, ->(s : String){ "y" } },
      { /c/, ->(s : String){ "x" } },
    ]
 
    s = StringScanner.new("a aabbcc c")
    result = ""
    
    while ! s.eos?  # This is the pattern our lexer uses
      converters.each do |(pattern, response)|    
        got = s.scan(pattern)
                
        unless got.nil?
          result += response.call(got)
          break
        end
      end
    end
    
    result.should eq("z <aabbcc> x")
  end
  
  it "marks up simple markup" do
    sample = activate_wiki_format("this is ''em''phatic\nthis is '''bold'''")
    reference = "this is <em>em</em>phatic<br/>\nthis is <strong>bold</strong><br/>\n"
    sample.should eq(reference)
  end

  it "escapes HTML" do
  
    sample = activate_wiki_format(">scr&eam<")
  
    reference = "&gt;scr&amp;eam&lt;<br/>\n"
    sample.should eq(reference)
  end
  
  it "expands two, three, or five ticks" do
  
    html = activate_wiki_format("me '''''galo'''''mania")
    
    html.includes?("me <strong><em>galo</em></strong>mania").should be_true
    
    html = activate_wiki_format("'''''megalomania'''''")
    
    html.includes?("<strong><em>megalomania</em></strong>").should be_true
  end

  it "expands ---- into a horizontal rule" do
  
    html = activate_wiki_format("one more\n----\nsilver dollar")
    
    html.should eq("one more<br/>\n<hr/>silver dollar<br/>\n")
  end

  it "provides concise internal links" do
    
    got = activate_wiki_format("FrontPage")
    
    got.should match(/href="\/FrontPage/)
    doc = assert_html(got)
    doc.xpath("//a[ '/FrontPage' = @href ]/text()").to_s.should eq("FrontPage")
    assert_xpath(doc, "//a[ '/FrontPage' = @href ]/text()", /FrontPage/)
    
    got = activate_wiki_format("baBaLoo")
    
    got.should_not match(/href/)
    
    got = activate_wiki_format("WinThirty2")
    
    got.should_not match(/href/)
  end
  
  it "makes external links hot" do
    
    html = activate_wiki_format("oxford commas: https://twitter.com/davejorgenson/status/1176243940728684547 yo")
    
    html.should match(/oxford commas:/)
    doc = assert_html(html)
    doc.xpath("//a[ 'https://twitter.com/davejorgenson/status/1176243940728684547' = @href and '_blank' = @target ]/text()").to_s.should eq("https://twitter.com/davejorgenson/status/1176243940728684547")
  end

  it "does not confuse internal and external links" do
    s = "yo: https://www.google.com/?q=HowToPissOffYourPair InternalLink"
    
    html = activate_wiki_format(s)
    html.should contain("yo: <a href=\"https://www.google.com/?q=HowToPissOffYourPair\" target=\"_blank\">https://www.google.com/?q=HowToPissOffYourPair</a> ")
    html.should contain(" <a href=\"/InternalLink\">InternalLink</a>")
  end
  
  it "Crystagiri calls xpath on nodes correctly" do
    xml = "<html><body><hr/></body></html>"
    doc = Crystagiri::HTML.new(xml)
    node = doc.nodes.xpath_node("/html/body")
    node.should_not be_nil    
    fail("bad") if node.nil?  #  See https://forum.crystal-lang.org/t/var-should-not-be-nil-does-not-eliminate-var-of-nil-from-subsequent-type-inference/1165
    
    hr = node.xpath_node("hr")

    hr.should_not be_nil
    hr.not_nil!.name.should eq("hr")
  end

  it "converts a page to HTML" do
    wiki = assemble_test_wiki()
    File.write("test_pages/KozmiqueBullfrog.page", "Hello ''World''\nFrontPage")
    
    html = wiki.format_page("KozmiqueBullfrog")
    
    html.should match(/\A<!DOCTYPE html>/)
    html.should match(/Hello/)
    doc = assert_html(html)
    assert_xpath(doc, "/html/body//h1", /\AKozmiqueBullfrog\Z/)
    node = assert_xpath(doc, "/html/body/article[ contains(text(), 'Hello') ]", /Hello/)
    assert_xpath doc, "//article/em", /World/
    assert_xpath doc, "//article/a[ '/FrontPage' = @href ]", /FrontPage/
    assert_xpath node, "em", /World/
    button = assert_xpath(doc, "/html/body/table/tbody/tr/td[2]/button", /Edit/)
   # p button.attributes["onclick"].methods
    button.attributes["onclick"].to_s.should eq(" onclick=\"window.location.href = '/KozmiqueBullfrog/edit';\"")
  end

  it "delivers an empty edit page" do
    wiki = assemble_test_wiki()
    File.delete("test_pages/SamplePage.page") if File.exists?("test_pages/SamplePage.page")

    html = wiki.edit_page("SamplePage")
    
    doc = assert_html(html)
    assert_xpath(doc, "/html/body//h1", /\ASamplePage\Z/)  # TODO  make this a search button
    form = assert_xpath(doc, "/html/body/form[ 'post' = @method and '/SamplePage' = @action ]")
    textarea = assert_xpath(form, "textarea[ '20' = @rows and '80' = @cols ]")
    textarea.text.should eq("")
    assert_xpath form, "input[ 'submit' = @type and 'Save' = @value ]"
  end
  
  it "delivers an empty edit page when you hit a page that doesn't exist" do
    wiki = assemble_test_wiki()
    File.delete("test_pages/SamplePage.page") if File.exists?("test_pages/SamplePage.page")

    html = Wiki.serve("test_pages", "GET", "/SamplePage", "new content")
    
    doc = assert_html(html)
    assert_xpath(doc, "/html/body//h1", /\ASamplePage\Z/)
    form = assert_xpath(doc, "/html/body/form[ 'post' = @method and '/SamplePage' = @action ]")
    textarea = assert_xpath(form, "textarea[ '20' = @rows and '80' = @cols ]")
    textarea.text.should eq("")
    assert_xpath form, "input[ 'submit' = @type and 'Save' = @value ]"
  end
  
  it "delivers a full edit page" do
    wiki = assemble_test_wiki()
    File.write("test_pages/SamplePage.page", ">sam&ple<")

    html = wiki.edit_page("SamplePage")
    
    doc = assert_html(html)
    assert_xpath(doc, "/html/body//h1", /\ASamplePage\Z/)
    form = assert_xpath(doc, "/html/body/form[ 'post' = @method ]")
    textarea = assert_xpath(form, "textarea[ 'content' = @name and '20' = @rows and '80' = @cols ]")
    textarea.text.should eq(">sam&ple<")
  end
  
  it "serves a wiki page" do
    assemble_test_wiki()
    File.write("test_pages/KozmiqueBullfrog.page", "Hello ''World''\nFrontPage")
    
    html = Wiki.serve("test_pages", "GET", "/KozmiqueBullfrog", "")
    
    doc = assert_html(html)
    assert_xpath doc, "//article[ contains(text(), 'Hello') ]"
  end
  
  it "serves an edit page" do
    assemble_test_wiki()
    File.write("test_pages/KozmiqueBullfrog.page", "Hello ''World''\nFrontPage")
    
    html = Wiki.serve("test_pages", "GET", "/KozmiqueBullfrog/edit", "")
    
    doc = assert_html(html)
    assert_xpath doc, "//textarea[ contains(text(), 'Hello') ]"
  end
  
  it "posts an edit page" do
    assemble_test_wiki()
    File.write("test_pages/KozmiqueBullfrog.page", "overwrite me")
    
    html = Wiki.serve("test_pages", "POST", "/KozmiqueBullfrog", "new content")
    
    doc = assert_html(html)
    assert_xpath doc, "//article[ contains(text(), 'new content') ]"
    File.read("test_pages/KozmiqueBullfrog.page").should eq("new content")
  end
  
end  # TODO  add a DOCTYPE

def assemble_test_wiki
  FileUtils.mkdir("test_pages") unless Dir.exists?("test_pages")
  wiki = Wiki.new("test_pages")
  return wiki
end

class Object
  macro methods
    {{ @type.methods.map &.name.stringify }}
  end
end

def assert_html(html)
  return Crystagiri::HTML.new(html).nodes
end

def assert_xpath(doc : XML::Node, path : String, matcher = //)
  node = doc.xpath_node(path)
  fail(path + " not found in " + doc.to_s) if node.nil?
  node.text.to_s.should match(matcher)
  return node
end

def activate_wiki_format(str)
  wiki = Wiki.new("test_pages")
  return wiki.format_article(str)
end
