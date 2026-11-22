"""Extract evenly spaced reference frames from an aerial video using Blender's sequencer.

Usage:
  blender --background --factory-startup --python tools/extract_video_frames.py -- <video> <outdir>
"""

import os
import sys

import bpy

FRACTIONS = [0.03, 0.16, 0.30, 0.44, 0.58, 0.72, 0.86, 0.97]


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:]
    video = os.path.abspath(argv[0])
    outdir = os.path.abspath(argv[1])
    os.makedirs(outdir, exist_ok=True)

    clip = bpy.data.movieclips.load(video)
    scene = bpy.context.scene
    scene.sequence_editor_create()
    strips = getattr(scene.sequence_editor, "strips", None)
    if strips is None:
        strips = scene.sequence_editor.sequences
    strips.new_movie("aerial", video, channel=1, frame_start=1)

    scene.render.resolution_x = clip.size[0]
    scene.render.resolution_y = clip.size[1]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.render.use_sequencer = True
    scene.render.use_compositing = False

    duration = max(1, clip.frame_duration)
    for index, fraction in enumerate(FRACTIONS, start=1):
        frame = max(1, min(duration, int(duration * fraction)))
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(outdir, "frame_%02d.png" % index)
        bpy.ops.render.render(write_still=True)
        print("WROTE", scene.render.filepath)


main()