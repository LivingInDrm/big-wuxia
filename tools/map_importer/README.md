# Map Importer

离线把 `wulinsh-assets/maps/scenes/Map_XXXXX/` 转成 Godot 4 原生资源。

依据 `docs/map-import-design.md`。

## 用法

```
python3 tools/map_importer/run.py --map Map_10020
python3 tools/map_importer/run.py --map Map_10020 --validate
python3 tools/map_importer/run.py --map Map_10020 --stages s1,s2
python3 tools/map_importer/run.py --map Map_10020 --force        # 忽略缓存
python3 tools/map_importer/run.py --map Map_10020 --dry-run      # 只跑 report
```

## 产物

- `resources/maps/imported/<MAP_ID>/<MAP_ID>_tileset.tres`
- `resources/maps/imported/<MAP_ID>/<MAP_ID>_battle_map.tscn`
- `resources/maps/imported/<MAP_ID>/atlas/*.png`
- `resources/maps/imported/<MAP_ID>/manifest.json`
- `resources/data/levels/<MAP_ID>.tres`
- `tools/map_importer/out/<MAP_ID>/report.md`

## 依赖

- Python 3（stdlib）
- Pillow（atlas repack）

## 设计

见 `docs/map-import-design.md` §A-I。
