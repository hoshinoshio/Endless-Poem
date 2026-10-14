extends RefCounted
const SIZE := Vector2(24000,2700)
const NAMES := ["观测环外缘", "星台阶梯", "事故点", "灯廊岔路", "观测环", "钟楼下层", "钟楼回廊", "时间锚"]
static func ground_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0,1900),Vector2(900,1900),Vector2(1400,1740),Vector2(1800,1900),Vector2(3500,1900),Vector2(3700,1800),Vector2(3800,1800),Vector2(3920,1900),Vector2(6900,1900),Vector2(7100,2100),Vector2(7200,2100),Vector2(7400,1900),Vector2(9000,1900),Vector2(9500,2100),Vector2(10900,2100),Vector2(11500,1900),Vector2(15000,1900),Vector2(15600,2100),Vector2(17000,2100),Vector2(17700,1900),Vector2(18100,1900),Vector2(18300,1800),Vector2(18500,1800),Vector2(18700,1900),Vector2(24000,1900)])
static func platform_paths() -> Array:
	return [
		{"id":"tutorial_upper","points":PackedVector2Array([Vector2(2000,1900),Vector2(2120,1790),Vector2(2300,1700),Vector2(2500,1700),Vector2(2700,1900)])},
		{"id":"stairs_terrace","points":PackedVector2Array([Vector2(3300,1900),Vector2(3500,1720),Vector2(3700,1550),Vector2(3790,1550),Vector2(4140,1900)])},
		{"id":"bridge_before_deck","points":PackedVector2Array([Vector2(6800,1900),Vector2(6950,1900)])},
		{"id":"bridge_after_deck","points":PackedVector2Array([Vector2(7300,1900),Vector2(7520,1900)])},
		{"id":"lamp_upper","points":PackedVector2Array([Vector2(9400,1848.8),Vector2(10000,1400),Vector2(10800,1400),Vector2(11200,1830.8)])},
		{"id":"lamp_middle","points":PackedVector2Array([Vector2(9000,1900),Vector2(9280,1880),Vector2(9780,1750),Vector2(10850,1750),Vector2(11500,1900)])},
		{"id":"ring_inner","points":PackedVector2Array([Vector2(11850,1900),Vector2(12050,1720),Vector2(12650,1500),Vector2(13900,1500),Vector2(14500,1900)])},
		{"id":"tower_upper","points":PackedVector2Array([Vector2(14850,1900),Vector2(15050,1720),Vector2(15700,1450),Vector2(17000,1450),Vector2(17700,1900)])},
		{"id":"corridor_gallery","points":PackedVector2Array([Vector2(17850,1900),Vector2(18050,1720),Vector2(18550,1470),Vector2(19800,1470),Vector2(20500,1900)])},
		{"id":"anchor_terrace","points":PackedVector2Array([Vector2(23500,1900),Vector2(23700,1700),Vector2(23950,1700)])}
	]
static func encounters() -> Dictionary:
	var out := {}
	for row in [["tutorial",2780,1900,0],["stairs",4600,1900,1],["patrol",10100,1750,3],["lamp",10200,2100,3],["elite",16400,2100,5],["corridor",19400,1900,6],["boss",22500,1900,7]]:
		var center := Vector2(row[1],row[2])
		var width := 1500.0 if row[0] == "boss" else (1000.0 if row[0] == "tutorial" else 1350.0)
		out[row[0]] = {"rect":Rect2(center-Vector2(width/2,650),Vector2(width,660)),"floor_y":float(row[2]),"spawns":[center+Vector2(220,0),center+Vector2(420,0),center+Vector2(580,0)],"region":int(row[3]),"trigger":center-Vector2(270,0)}
	out["tutorial"]["trigger"] = Vector2(2710,1900)
	out["tutorial"]["spawns"] = [Vector2(3000,1900),Vector2(3130,1900),Vector2(3180,1900)]
	return out
static func interactions() -> Dictionary:
	return {"tutorial_lantern":Vector2(1900,1900),"bridge_before":Vector2(6800,1900),"bridge_after":Vector2(7400,1900),"supply_lamp":Vector2(10650,1400),"testimony":Vector2(13200,1900),"supply_tower":Vector2(15900,1450),"rest":Vector2(16600,1450),"anchor_key":Vector2(21500,1900),"final_dial":Vector2(23300,1900)}
static func gates() -> Array:
	return [{"x":3300.0,"completed":["tutorial"],"interactions":[],"label":"完成外缘试炼"},{"x":5900.0,"completed":["stairs"],"interactions":[],"label":"完成阶梯遭遇"},{"x":8800.0,"completed":[],"interactions":["bridge_before","bridge_after"],"label":"调查断桥的两个切片"},{"x":14800.0,"completed":[],"interactions":["testimony"],"label":"听取暮笙证词"},{"x":20900.0,"completed":["corridor"],"interactions":[],"label":"通过钟楼回廊"},{"x":22000.0,"completed":[],"interactions":["anchor_key"],"label":"取得锚的钥匙"},{"x":23200.0,"completed":["boss"],"interactions":[],"label":"完成克洛诺斯考核"}]
static func ground_y(x: float) -> float:
	var pts := ground_points()
	for i in range(pts.size()-1):
		if x >= pts[i].x and x <= pts[i+1].x:
			return lerpf(pts[i].y,pts[i+1].y,(x-pts[i].x)/(pts[i+1].x-pts[i].x))
	return 1900.0



static func fork_paths() -> Array:
	var out: Array = []
	for path in platform_paths():
		if path.id in ["tutorial_upper","stairs_terrace","lamp_middle","lamp_upper","ring_inner","tower_upper","corridor_gallery"]:
			out.append(path)
	return out
