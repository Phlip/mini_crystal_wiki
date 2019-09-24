require "http/server"
require "./mini_crystal_wiki"

server = HTTP::Server.new do |context|
  context.response.content_type = "text/html"
  content = ""

  if context.request.method == "POST"
    HTTP::FormData.parse(context.request) do |part|
        case part.name
        when "content"
          content = part.body.gets_to_end
        end
    end
  end
 
  html = Wiki.serve("pages", context.request.method, context.request.path, content)
  context.response.print html
end

puts "Listening on http://127.0.0.1:8080"
server.listen(8080)
