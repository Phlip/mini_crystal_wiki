
require "spec"
require "./mini_crystal_wiki"
require "crystagiri"
require "file_utils"

describe "Wiki" do 

  it "marks up simple markup" do
    sample = activate_wiki_format("this is ''em''phatic\nthis is '''bold'''")
    reference = "this is <em>em</em>phatic<br/>\nthis is <strong>bold</strong><br/>\n"
    assert_equal reference, sample
  end

  it "escapes HTML" do
  
    sample = activate_wiki_format(">scr&eam<")
  
    reference = "&gt;scr&amp;eam&lt;<br/>\n"
    assert_equal reference, sample
  end
  
  it "expands two, three, or five ticks" do
  
    html = activate_wiki_format("me '''''galo'''''mania")
    
    assert html.includes?("me <strong><em>galo</em></strong>mania")
    
    html = activate_wiki_format("'''''megalomania'''''")
    
    assert html.includes?("<strong><em>megalomania</em></strong>")
  end

  it "expands ---- into a horizontal rule" do
  
    html = activate_wiki_format("one more\n----\nsilver dollar")
    
    html.should eq("one more<br/>\n<hr/>silver dollar<br/>\n")
  end

  it "provides concise internal links" do
    
    got = activate_wiki_format("FrontPage")
    
    assert_match(/href="\/FrontPage/, got)    
    doc = assert_html(got)
    doc.xpath("//a[ '/FrontPage' = @href ]/text()").to_s.should eq("FrontPage")
    assert_xpath(doc, "//a[ '/FrontPage' = @href ]/text()", /FrontPage/)
    
    got = activate_wiki_format("baBaLoo")
    
    deny_match(/href/, got)
    
    got = activate_wiki_format("WinThirty2")
    
    deny_match(/href/, got)
  end
  
  it "makes external links hot" do
    
    html = activate_wiki_format("oxford commas: https://twitter.com/davejorgenson/status/1176243940728684547 yo")
    
    html.should match(/oxford commas:/)
    doc = assert_html(html)
    doc.xpath("//a[ 'https://twitter.com/davejorgenson/status/1176243940728684547' = @href and '_blank' = @target ]/text()").to_s.should eq("https://twitter.com/davejorgenson/status/1176243940728684547")
  end
 
  it "Crystagiri calls xpath on nodes correctly" do
    xml = "<html><body><hr/></body></html>"
    doc = Crystagiri::HTML.new(xml)
    node = doc.nodes.xpath_node("/html/body")
    fail("bad") if node.nil?  #  Yay Crystal!  Nil-safety is just another type inference!
    
    hr = node.xpath_node("hr")
    
    fail("bad") if hr.nil?
    hr.name.should eq("hr")
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

def assert_match(regex, sample)
  sample.should match(regex)
end

def deny_match(regex, sample)
  assert regex.match(sample) == nil
end

def activate_wiki_format(str)
  wiki = Wiki.new("test_pages")
  return wiki.format_article(str)
end

def assert_equal(reference, sample)
  sample.should eq(reference)
end

def assert(x)
  x.should eq(true)
end 
