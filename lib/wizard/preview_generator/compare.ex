defmodule Wizard.PreviewGenerator.Compare do
  @spec is_same_png?(Path.t, Path.t) :: boolean | {:error, any}
  def is_same_png?(first_image_path, second_image_path) do
    case load([first_image_path, second_image_path]) do
      {:ok, [png1, png2]} ->
        is_same_size?(png1, png2) &&
          is_same_bit_depth?(png1, png2) &&
          has_same_pixels?(png1, png2)
      error ->
        error
    end
  end

  defp is_same_size?(png1, png2) do
    png1.width == png2.width && png1.height == png2.height
  end

  defp is_same_bit_depth?(png1, png2) do
    png1.bit_depth == png2.bit_depth
  end

  defp has_same_pixels?(png1, png2),
    do: has_same_pixels_for_rows?(png1.pixels, png2.pixels)

  defp has_same_pixels_for_rows?([], []), do: true
  defp has_same_pixels_for_rows?([_ | _], []), do: false
  defp has_same_pixels_for_rows?([], [_ | _]), do: false
  defp has_same_pixels_for_rows?([row1 | rows1], [row2 | rows2]) do
    if has_same_pixels_for_row?(row1, row2) do
      has_same_pixels_for_rows?(rows1, rows2)
    else
      false
    end
  end

  defp has_same_pixels_for_row?([], []), do: true
  defp has_same_pixels_for_row?([_ | _], []), do: false
  defp has_same_pixels_for_row?([], [_ | _]), do: false
  defp has_same_pixels_for_row?([pixel1 | row1], [pixel2 | row2]) do
    if pixel1 == pixel2 do
      has_same_pixels_for_row?(row1, row2)
    else
      false
    end
  end

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
