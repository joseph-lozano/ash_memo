defmodule Example.Posts do
  use Ash.Domain

  resources do
    resource Example.Posts.Post do
      define :create_post, action: :create
      define :get_post, action: :read, get_by: [:id]
    end
  end
end