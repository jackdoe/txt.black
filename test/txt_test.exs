defmodule TxtTest do
  use ExUnit.Case
  alias Txt.Store
  alias Txt.Post
  alias Txt.User

  test "basic" do
    user = "abc"
    slug = "xyz"
    post = %Post{user: user, slug: slug, title: "hello", stamp: 1}

    Store.delete(user)
    Store.delete({user, slug})
    assert Store.lookup(user) == :notfound
    assert Store.lookup({user, slug}) == :notfound

    assert Store.upsert(post) == :ok
    assert Store.lookup({user, slug}) == post

    Store.delete({user, slug})
    assert Store.lookup({user, slug}) == :notfound

    u = %User{user: user, hashed_password: 123_123}
    assert Store.upsert(u) == :ok
    assert Store.lookup(user) == u

    Store.delete(user)
    assert Store.lookup(user) == :notfound

    assert Store.upsert(u) == :ok
    assert Store.upsert(post) == :ok

    assert Store.upsert(%Post{user: "other-user", slug: "other-slug", title: "hello", stamp: 1}) ==
             :ok

    assert length(Store.select(user)) == 1
    assert length(Store.select("other-user")) == 1
    assert length(Store.select(:any)) == 2

    Store.delete({"other-user", "other-slug"})

    IO.inspect(Application.stop(:txt))
  end
end
