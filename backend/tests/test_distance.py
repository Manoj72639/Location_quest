from main import distance_meters


def test_same_location_is_zero():
    assert distance_meters(11.0, 76.0, 11.0, 76.0) == 0


def test_distance_is_symmetric():
    a = distance_meters(11.0, 76.0, 11.001, 76.0)
    b = distance_meters(11.001, 76.0, 11.0, 76.0)
    assert abs(a - b) < 0.001


def test_one_degree_latitude_is_about_111_km():
    distance = distance_meters(0, 0, 1, 0)
    assert 110_000 < distance < 112_000
