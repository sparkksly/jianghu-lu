class_name Hand
extends RefCounted

# 进攻牌池 = ATTACK 类。
static func attack_pool(deck: Array[Move]) -> Array[Move]:
	var out: Array[Move] = []
	for m in deck:
		if m.kind == Move.Kind.ATTACK:
			out.append(m)
	return out

# 工具牌 = 非 ATTACK(步法/格挡/闪身/擒拿)。
static func utilities(deck: Array[Move]) -> Array[Move]:
	var out: Array[Move] = []
	for m in deck:
		if m.kind != Move.Kind.ATTACK:
			out.append(m)
	return out

# 有放回抽 n 张(可能重复)。pool 必须非空。
static func draw(pool: Array[Move], n: int, rng: RandomNumberGenerator, weights := {}) -> Array[Move]:
	# 加权有放回抽 n 张:每张权重 = 1 + weights[id](磨练招更易抽到);不传则等概率。
	var out: Array[Move] = []
	var cum: Array[int] = []
	var total := 0
	for m in pool:
		total += 1 + int(weights.get(m.id, 0))
		cum.append(total)
	for i in n:
		var r := rng.randi_range(0, total - 1)
		for j in cum.size():
			if r < cum[j]:
				out.append(pool[j])
				break
	return out
