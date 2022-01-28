defmodule DealerScraperTest do
  use ExUnit.Case
  doctest DealerScraper

  test "greets the world" do
    assert DealerScraper.hello() == :world
  end
end
