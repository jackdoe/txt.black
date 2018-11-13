defmodule Txt.HTML do
  alias Plug.HTML

  def escape(s) do
    HTML.html_escape(s)
  end

  def form(user) do
    gen("post something #{user}", """
    <form action="/post/" METHOD=post class="blog">
      posting as <b>#{escape(user)}</b><br>
      <label for="title">Title</label>
      <input type="text" name="title" id="title" value=""><br>
      <label for="slug">Slug</label>
      <input type="text" name="slug" id="slug" value="example"><br>
      <div id="tags">
        <label for="tag">Tag <a href="javascript: void(0)" onClick="newTag()">+</a></label>
        <input type="text" name="tags[]" id="tag" value="">
      </div>
      <br>
      <script>
        var newTag = function() {
            var anchor = document.getElementById("tags")
            var input = document.createElement("input");
            input.type = "text";
            input.name = "tags[]"
            anchor.appendChild(input);            
        }
      </script>
      Text:<br>
      <textarea name="text" style="width:80%; height: 50%"></textarea><br>
      <input type="submit" value="Submit">
    </form>
    """)
  end

  def header() do
    %Txt.Post{
      user: "jack",
      title: "txt.black",
      slug: "/",
      text: """
      hey,
      welcome to txt.black, if you want to post here send me an email to info@txt.black

      check out the code at https://github.com/jackdoe/txt.black 


      PS: we do not use cookies :)

      """,
      stamp: Txt.Store.timestamp()
    }
  end

  def show(%Txt.Post{user: user, title: title, text: text, slug: slug, tags: tags, stamp: stamp}) do
    tags = tags |> Enum.map(fn x -> "<small>##{escape(x)}</small>" end) |> Enum.join(" ")

    """
    <h3>
    <small>[<a href="/~#{escape(user)}/#{escape(slug)}">#{escape(slug)}</a> @ <a href="/~#{
      escape(user)
    }/">#{escape(user)}</a>, #{stamp}]</small>
    #{escape(title)}
    </h3>
    <pre>
    #{escape(text)}
    #{tags}
    </pre>
    """
  end

  def show(title, posts) do
    joined = posts |> Enum.map(fn x -> show(x) end) |> Enum.join("<hr>\n")
    gen(title, joined)
  end

  def gen(title, inner) do
    """
    <!DOCTYPE html5>
    <html>
    <head>
    <meta name="viewport" content="initial-scale=1.0">
    <meta charset="utf-8">
    <style>
    html, body {
    padding: 0;
    margin: 0;
    font-family: Menlo, monospace;
    background-color: black;
    color: white;
    }
    a {
    color: silver;
    }
    a:active {
    color: silver;
    }
    a:visited {
    color: gray;
    }
    .blog {
    padding: 10px;
    margin: 10px;
    }
    pre {
    white-space: pre-wrap;        
    white-space: -moz-pre-wrap;   
    white-space: -pre-wrap;       
    white-space: -o-pre-wrap;     
    word-wrap: break-word;        
    font-family: Menlo, monospace
    }
    input,textarea {
    margin: 5px;
    padding: 5px;
    font-family: Menlo, monospace;
    background-color: black;
    color: white;
    }
    </style>
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon.png">
    <meta name="theme-color" content="#ffffff">
    <title>#{escape(title)}</title>
    </head>
    <body>
    <div class="blog">
    #{inner}
    </div>
    </body>
    </html>
    """
  end
end
