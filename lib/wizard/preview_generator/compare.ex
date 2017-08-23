defmodule Wizard.PreviewGenerator.Compare do
  require Logger

  @spec is_same_png?(Path.t, Path.t) :: boolean | {:error, any}
  def is_same_png?(first_image_path, second_image_path) do
    case load([first_image_path, second_image_path]) do
      {:ok, [png1, png2]} ->
        is_same_size?(png1, png2) &&
          is_same_bit_depth?(png1, png2) &&
          has_same_pixels?(png1, png2)
      error ->
        Logger.error "Error reading png files #{inspect error}"
        false
    end
  end

  defp is_same_size?(png1, png2),
    do: png1.width == png2.width && png1.height == png2.height

  defp is_same_bit_depth?(png1, png2),
    do: png1.bit_depth == png2.bit_depth

  defp has_same_pixels?(png1, png2),
    do: png1.pixels == png2.pixels

  @spec load(list(Path.t)) :: {:ok, list(map)} | {:error, any}
  defp load(paths), do: load([], paths)
  defp load(result, []), do: {:ok, result}
  defp load(result, [path | paths]) do
    case Imagineer.load(path) do
      {:ok, png} -> load([png | result], paths)
      error -> error
    end
  end
end
