from gradjoeng.fx import cpu_color


def test_cpu_color_runs_green_blue_red():
    green, blue, red = cpu_color(0), cpu_color(50), cpu_color(100)
    assert green[1] == max(green)
    assert blue[2] == max(blue)
    assert red[0] == max(red)
    assert cpu_color(150) == red
