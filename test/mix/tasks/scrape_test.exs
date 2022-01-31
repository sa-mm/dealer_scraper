defmodule Mix.Tasks.ScrapeTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mox

  alias Mix.Tasks.Scrape

  setup :verify_on_exit!

  setup do
    level = Logger.level()
    on_exit(fn -> Logger.configure(level: level) end)
  end

  describe "run/1 should" do
    test "put output" do
      do_expect()
      assert capture_io(fn -> Scrape.run("") end) =~ "reviewer"
    end

    test "respect log level" do
      do_expect()
      System.put_env("LOG_LEVEL", "debug")
      assert capture_io(fn -> Scrape.run("") end) =~ "reviewer"
      assert :debug = Logger.level()
    end
  end

  defp do_expect(pages \\ 5) do
    for _n <- 1..pages do
      expect(HttpClientMock, :get, fn _url ->
        {:ok, %HTTPoison.Response{body: File.read!("test/support/page1.html")}}
      end)
    end
  end
end
