defmodule Txt.Post do
  defstruct user: "", title: "", text: "", slug: "", tags: [], stamp: 0
end

defmodule Txt.User do
  defstruct user: "", hashed_password: ""
end

defmodule Txt.Store do
  use GenServer
  require Logger

  def create_tables do
    {:ok, user_table} =
      :dets.open_file(:user, type: :set, file: String.to_atom(Application.get_env(:txt, :user)))

    {:ok, post_table} =
      :dets.open_file(:post, type: :set, file: String.to_atom(Application.get_env(:txt, :post)))

    {user_table, post_table}
  end

  def start_link({user_table, post_table}) do
    GenServer.start_link(
      __MODULE__,
      {:ok, {user_table, post_table}},
      name: Txt.Store
    )
  end

  def upsert(obj) do
    GenServer.call(Txt.Store, {:insert, obj})
  end

  def lookup(obj) do
    GenServer.call(Txt.Store, {:lookup, obj})
  end

  def delete(obj) do
    GenServer.call(Txt.Store, {:delete, obj})
  end

  def select(obj) do
    GenServer.call(Txt.Store, {:select, obj})
  end

  # callbacks
  def init({:ok, {user_table, post_table}}) do
    Process.flag(:trap_exit, true)
    {:ok, {user_table, post_table}}
  end

  def handle_call({:delete, {user, slug}}, _from, {user_table, post_table}) do
    {:reply, :dets.delete(post_table, {user, slug}), {user_table, post_table}}
  end

  def handle_call({:delete, user}, _from, {user_table, post_table}) do
    {:reply, :dets.delete(user_table, user), {user_table, post_table}}
  end

  def handle_call({:lookup, {user, slug}}, _from, {user_table, post_table}) do
    case :dets.lookup(post_table, {user, slug}) do
      [{{_, _}, value}] ->
        {:reply, value, {user_table, post_table}}

      _ ->
        {:reply, :notfound, {user_table, post_table}}
    end
  end

  def handle_call({:lookup, user}, _from, {user_table, post_table}) do
    case :dets.lookup(user_table, user) do
      [{_, value}] ->
        {:reply, value, {user_table, post_table}}

      _ ->
        {:reply, :notfound, {user_table, post_table}}
    end
  end

  def handle_call({:select, user}, _from, {user_table, post_table}) do
    fun =
      case user do
        :any ->
          [{{{:"$1", :"$2"}, :"$3"}, [], [:"$3"]}]

        _ ->
          [{{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", user}], [:"$3"]}]
      end

    {:reply, Enum.sort(:dets.select(post_table, fun), fn a, b -> a.stamp >= b.stamp end),
     {user_table, post_table}}
  end

  def handle_call(
        {:insert,
         %Txt.Post{user: user, title: title, text: text, slug: slug, tags: tags, stamp: stamp}},
        _from,
        {user_table, post_table}
      ) do
    case :dets.insert(
           post_table,
           {{user, slug},
            %Txt.Post{user: user, title: title, text: text, slug: slug, tags: tags, stamp: stamp}}
         ) do
      :ok ->
        {:reply, :ok, {user_table, post_table}}

      ret ->
        {:reply, {:error, ret}, {user_table, post_table}}
    end
  end

  def handle_call(
        {:insert, %Txt.User{user: user, hashed_password: hashed_password}},
        _from,
        {user_table, post_table}
      ) do
    case :dets.insert(
           user_table,
           {user, %Txt.User{user: user, hashed_password: hashed_password}}
         ) do
      :ok ->
        {:reply, :ok, {user_table, post_table}}

      ret ->
        {:reply, {:error, ret}, {user_table, post_table}}
    end
  end

  def timestamp do
    :os.system_time(:seconds)
  end
end

defmodule Txt.Util do
  import Pbkdf2

  def hash_password(p) do
    hash_pwd_salt(p)
  end

  def check_password(pass, hash) do
    verify_pass(pass, hash)
  end

  def create_user(user, pass) do
    Txt.Store.upsert(%Txt.User{user: user, hashed_password: hash_password(pass)})
  end
end
