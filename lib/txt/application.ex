defmodule Txt.Application do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # List all child processes to be supervised
    {user_table, post_table} = Txt.Store.create_tables()
    port = Application.get_env(:txt, :port)
    Logger.info("listening to #{port}")

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Txt.Router,
        options: [port: port]
      ),
      {Txt.Store, {user_table, post_table}}
    ]

    opts = [strategy: :one_for_one, name: Txt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
