defmodule Example.Posts.PostTest do
  use ExUnit.Case

  alias Example.Posts.Post

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Example.Repo)
  end

  describe "word_count calculation" do
    test "returns correct word count for content with multiple words" do
      post = %Post{content: "This is a test post"}
      assert Ash.calculate!(post, :word_count) == 5
    end

    test "returns correct word count for content with extra spaces" do
      post = %Post{content: "  This   is    a    test  "}
      assert Ash.calculate!(post, :word_count) == 4
    end

    test "returns 0 for nil content" do
      post = %Post{content: nil}
      assert Ash.calculate!(post, :word_count) == 0
    end

    test "returns 0 for empty content" do
      post = %Post{content: ""}
      assert Ash.calculate!(post, :word_count) == 0
    end

    test "returns 1 for single word" do
      post = %Post{content: "Hello"}
      assert Ash.calculate!(post, :word_count) == 1
    end

    test "handles content with newlines and tabs" do
      post = %Post{content: "Hello\nworld\tthis\ris\na test"}
      assert Ash.calculate!(post, :word_count) == 6
    end
  end
end
