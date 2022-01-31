defmodule Mix.Tasks.Scrape do
  @moduledoc """
  Mix task to all running the app via `mix scrape`
  """
  require Logger

  @log_levels [
    "emergency",
    "alert",
    "critical",
    "error",
    "warning",
    "notice",
    "info",
    "debug"
  ]

  def run(_) do
    Mix.Task.run("app.start")

    level_str = System.get_env("LOG_LEVEL", "warning")

    with :ok <-
           configure_logger(level_str),
         top_3 when is_list(top_3) <- DealerScraper.get_reviews_of_interest() do
      case Jason.encode(top_3) do
        {:ok, out} ->
          IO.puts(out)

        {:error, message} ->
          Logger.error("Json encode error: #{inspect(message)}")
          IO.puts(:stderr, Jason.encode!([]))
      end
    else
      {:error, message} ->
        IO.puts(:stderr, Jason.encode!(message))
    end
  end

  defp configure_logger(level_str)
       when level_str in @log_levels do
    level = String.to_atom(level_str)
    Logger.configure(level: level)
  end

  defp configure_logger(str) do
    msg = "Unknown log level: #{str}"
    Logger.error(msg)
    {:error, msg}
  end
end
