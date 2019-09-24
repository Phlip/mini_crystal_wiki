
LocalLink = /\b((?:[A-Z][a-z]+){2,})\b/  #  the heart of Wikidom... ;-)

class Wiki

  @page_folder = "pages"
  property :page_folder
  
  def initialize(page_folder)
    @page_folder = page_folder
  end
  
  def self.serve(page_folder, method, uri, content)
    wiki = Wiki.new(page_folder)
    page_name = uri.sub(/\A\//, "")
    page_name = "FrontPage" if page_name == ""  # TODO  test this
    page_at = wiki.page_path(page_name)

    if method == "POST"
      File.write(page_at, content)
    end
    
    exists = File.exists?(page_at)
 
    if exists && page_name =~ /\A#{LocalLink}\Z/
      return wiki.format_page(page_name)
    end
    
    if !exists || page_name =~ /#{LocalLink}\/edit/
      return wiki.edit_page(page_name.sub(/\/edit\Z/, ""))
    end
    
    return ""
  end
  
  def edit_page(page_name : String)
    page_at = page_path(page_name)
    contents = File.exists?(page_at) ? File.read(page_at) : ""

    [
        [ "&", "&amp;" ],
        [ "<", "&lt;" ],
        [ ">", "&gt;" ],
    ].each do |(frum, too)|
      contents = contents.gsub(frum, too)
    end
    
    return tag :html do
             tag :body do
               tag(:h1){ page_name } +
               
               tag :form, { method: :post, action: "/#{page_name}", enctype: "multipart/form-data" } do
                 tag :textarea, { name: :content, rows: 20, cols: 80 } do
                   contents
                 end +
                 "<br/>" + 
                 "<br/>" + 
                 tag(:input, { type: :submit, value: :Save }){""}
               end
             end
           end
  end
  
  def page_path(page_name)
    return page_folder + "/" + page_name + ".page"
  end
  
  def format_page(page_name : String)
    page_at = page_path(page_name)
    contents = File.read(page_at)

    return "<!DOCTYPE html>\n" +
           tag :html do
             tag :body do
               tag("h1"){ page_name } + "<hr/>" +
               tag("article"){ format_article(contents) } + "<hr/>" +
               
               tag :table, { width: "100%" } do
                 tag :tbody do
                   tag :tr do
                     tag(:td){""} +
                     tag :td, { align: "right" } do
                       onclick = "window.location.href = '/#{page_name}/edit';"
                       
                       tag :button, { onclick: onclick } do 
                         "Edit"
                       end  
                     end  
                   end
                 end
               end
             end
           end
  end
  
  def tag(name, attributes = {} of Symbol => String)
    attr = ""
    
    attributes.each do |key, value|
      attr += " #{key}=\"#{value}\""
    end
    
    return "<#{name}#{attr}>#{yield}</#{name}>"
  end 
  
  def format_article(str)
    contents = ""

    str.split("\n").each do |line|
      line = format_wiki_line(line)
      line += "<br/>\n" unless line == "<hr/>"
      contents += line
    end
    
    return contents
  end

  def format_wiki_line(line)
    [
        [ "&",             "&amp;" ],
        [ "<",             "&lt;" ],
        [ ">",             "&gt;" ],
        [ LocalLink, "<a href=\"/\\1\">\\1</a>" ],
        [ /([^']?)'''''([^'].*?)'''''/, "\\1<strong><em>\\2</em></strong>" ],
        [ /'''(.*?)'''/,   "<strong>\\1</strong>" ],
        [ /''(.*?)''/,     "<em>\\1</em>" ],
        [ /\A----\s*\Z/,     "<hr/>" ],
    ].each do |(frum, too)|  # TODO  inform https://github.com/crystal-lang/crystal/wiki/Crystal-for-Rubyists of the (,) trick
      line = line.gsub(frum, too)
    end  
    
    return line
  end

end
