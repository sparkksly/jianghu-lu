extends GutTest

func test_all_well_formed():
	for e in Encounters.all():
		assert_true(e.has("title") and e.has("body"))
		assert_gt(e["options"].size(), 0)
		for o in e["options"]:
			assert_true(o.has("label") and o.has("effect"))

func test_for_chapter_returns_one():
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	assert_true(Encounters.for_chapter(0, rng).has("title"))
	assert_true(Encounters.for_chapter(2, rng).has("title"))
