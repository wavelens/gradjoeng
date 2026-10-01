# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_strongest_glitches_are_ranked_and_padded() -> void:
	var glitches: Array[Vector4] = [Vector4(0, 0, 1, 0.2), Vector4(1, 0, 1, 0.9), Vector4(2, 0, 1, 0.5)]
	var picked := DetectionScreen.strongest(glitches, 4)
	equal(picked.size(), 4)
	for i in 4:
		near(picked[i].w, [0.9, 0.5, 0.2, 0.0][i], 1e-5)
	equal(DetectionScreen.strongest(glitches, 2).size(), 2)
