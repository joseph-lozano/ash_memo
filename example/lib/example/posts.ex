defmodule Example.Posts do
  use Ash.Domain

  resources do
    resource Example.Posts.Post
  end
end