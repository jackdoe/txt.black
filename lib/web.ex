defmodule Txt.Router do
  use Plug.Router

  plug(Plug.Parsers, parsers: [:urlencoded, :multipart])
  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)
  use Plug.ErrorHandler

  def extract_user(conn) do
    # could've used plug auth, buuut.. this is just for practice anyway
    # https://en.wikipedia.org/wiki/Basic_access_authentication
    # Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l -> to QWxhZGRpbjpPcGVuU2VzYW1l
    hdr =
      conn.req_headers
      |> Enum.filter(fn {k, _} -> "authorization" == k end)
      |> Enum.map(fn {_, v} -> String.split(v, ~r{ }) end)
      |> Enum.at(0)

    if hdr != nil do
      [user | pass] =
        Base.decode64!(Enum.at(hdr, 1))
        |> String.split(~r{:})

      case Txt.Store.lookup(user) do
        :notfound ->
          nil

        %Txt.User{user: username, hashed_password: hashed_password} ->
          if Txt.Util.check_password(pass, hashed_password) do
            username
          else
            nil
          end
      end
    else
      nil
    end
  end

  get "/post/" do
    conn = Plug.Conn.put_resp_header(conn, "WWW-Authenticate", "Basic realm=\"auth\"")
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")
    user = extract_user(conn)

    if user == nil do
      send_resp(conn, 401, "authenticate")
    else
      send_resp(conn, 200, Txt.HTML.form(user))
    end
  end

  post "/post/" do
    conn = Plug.Conn.put_resp_header(conn, "WWW-Authenticate", "Basic realm=\"auth\"")
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")
    user = extract_user(conn)

    if user == nil do
      send_resp(conn, 401, "authenticate")
    else
      p = conn.body_params

      post = %Txt.Post{
        user: user,
        title: p["title"],
        tags: p["tags"],
        slug: p["slug"],
        text: p["text"],
        stamp: Txt.Store.timestamp()
      }

      case Txt.Store.upsert(post) do
        :ok ->
          send_resp(conn, 200, "yey \\o/")

        _ ->
          send_resp(conn, 500, "failed to save")
      end
    end
  end

  get "/~:user" do
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")
    send_resp(conn, 200, Txt.HTML.show("posts by #{user}", Txt.Store.select(user)))
  end

  get "/~:user/:slug" do
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")

    case Txt.Store.lookup({user, slug}) do
      :notfound ->
        send_resp(conn, 404, "not found")

      post ->
        send_resp(conn, 200, Txt.HTML.show("#{user} - #{slug}", [post]))
    end
  end

  get "/" do
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")

    send_resp(
      conn,
      200,
      Txt.HTML.show("txt.black", [
        Txt.HTML.header()
        | Txt.Store.select(:any)
      ])
    )
  end

  match _ do
    conn = Plug.Conn.put_resp_header(conn, "content-type", "text/html")
    send_resp(conn, 404, "catch all, not found")
  end

  defp handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "#{conn.status} Something went wrong")
  end
end
