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
static func draw(pool: Array[Move], n: int, rng: RandomNumberGenerator) -> Array[Move]:
	var out: Array[Move] = []
	for i in n:
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out
