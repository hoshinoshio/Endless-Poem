"""Convert acceptance PNG frames into a GIF. No artwork is synthesized or edited."""
from pathlib import Path
import argparse
import json
from PIL import Image


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=Path, default=root / "docs/verification/motion_frames")
    parser.add_argument("--evidence", type=Path, default=root / "docs/verification/motion_render_evidence.json")
    parser.add_argument("--output", type=Path, default=root / "docs/verification/motion_preview.gif")
    args = parser.parse_args()
    evidence = json.loads(args.evidence.read_text(encoding="utf-8"))
    count = int(evidence["frame_count"])
    fps = int(evidence["fps"])
    if count <= 0:
        raise ValueError("Acceptance evidence contains no frames")
    frames = []
    for index in range(count):
        with Image.open(args.frames / f"frame_{index:04d}.png") as image:
            if image.size != (1440, 900):
                raise ValueError(f"Frame {index} has incorrect full-canvas dimensions")
            frames.append(image.convert("RGB").resize((960, 600), Image.Resampling.LANCZOS))
    # A single palette keeps stationary scenery at stable indices, so GIF can
    # encode small changed rectangles rather than recompressing the entire canvas.
    # Samples cover both encounters and the travelling spell, including pause UI.
    sample_indices = sorted(set(range(0, count, max(1, count // 30))) | {count - 1})
    sample_sheet = Image.new("RGB", (160 * len(sample_indices), 100))
    for slot, index in enumerate(sample_indices):
        sample_sheet.paste(frames[index].resize((160, 100), Image.Resampling.BOX), (160 * slot, 0))
    palette = sample_sheet.quantize(colors=255, method=Image.Quantize.MEDIANCUT,
                                    dither=Image.Dither.NONE)
    # Reserve index 255 for unchanged pixels. A fully occupied 256-color palette
    # cannot create transparent delta frames, even when only a few pixels change
    # inside a large bounding rectangle. Quantization may use the padding slot;
    # map it to its nearest real color before marking it transparent.
    colors = palette.getpalette()
    colors.extend([0] * (768 - len(colors)))
    palette.putpalette(colors)
    padding = colors[765:768]
    replacement = min(range(255), key=lambda i: sum((colors[i * 3 + c] - padding[c]) ** 2 for c in range(3)))
    remap = list(range(256))
    remap[255] = replacement
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE).point(remap) for frame in frames]
    # GIF stores duration in centiseconds. Distribute rounding across the sequence.
    durations = [10 * (round((i + 1) * 100 / fps) - round(i * 100 / fps)) for i in range(count)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(args.output, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, optimize=True, disposal=1, transparency=255, palette=palette.getpalette())
    with Image.open(args.output) as result:
        encoded_count = result.n_frames
        total_duration = 0
        for index in range(encoded_count):
            result.seek(index)
            total_duration += result.info.get("duration", 0)
        # Pillow can merge visually identical paused frames while preserving their
        # durations. Validate time and canvas, retaining every source PNG as evidence.
        if result.size != (960, 600) or total_duration != sum(durations):
            raise ValueError("Encoded GIF did not preserve the acceptance duration and canvas")
    print(f"MOTION_PREVIEW source_frames={count} gif_frames={encoded_count} fps={fps} "
          f"duration_ms={total_duration} size=960x600 bytes={args.output.stat().st_size} "
          f"palette=255+transparent dither=none output={args.output}")


if __name__ == "__main__":
    main()
