defmodule MercurioTest do
  use ExUnit.Case
  doctest Mercurio

  test "greets the world" do
    assert Mercurio.hello() == :world
  end
end
