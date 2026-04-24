"""Godot .tres / .tscn text writers — pure string construction.

Godot resource files are a stable text format; we emit them deterministically
so repeated runs produce byte-identical output (critical for diff-based
regression testing).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


def fmt_str(s: str) -> str:
    """Escape a string for a .tres quoted value."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt_vec2i(x: int, y: int) -> str:
    return f"Vector2i({int(x)}, {int(y)})"


def fmt_vec2(x: float, y: float) -> str:
    return f"Vector2({_fmt_float(x)}, {_fmt_float(y)})"


def fmt_bool(b: bool) -> str:
    return "true" if b else "false"


def _fmt_float(f: float) -> str:
    s = f"{f:.6f}".rstrip("0").rstrip(".")
    return s if s else "0"


def fmt_packed_vector2_array(pairs: Iterable[tuple[int, int]]) -> str:
    flat: list[str] = []
    for x, y in pairs:
        flat.append(str(int(x)))
        flat.append(str(int(y)))
    if not flat:
        return "PackedVector2Array()"
    return "PackedVector2Array(" + ", ".join(flat) + ")"


def fmt_vec2i_dict_of_strings(d: dict[tuple[int, int], str]) -> str:
    """Render a Dictionary with Vector2i keys and string values.
    Keys sorted deterministically for reproducibility.
    """
    if not d:
        return "{}"
    items = sorted(d.items(), key=lambda kv: (kv[0][0], kv[0][1]))
    parts = [f"{fmt_vec2i(k[0], k[1])}: {fmt_str(v)}" for k, v in items]
    return "{\n" + ",\n".join(parts) + "\n}"


# --------------------------------------------------------------------------- .tres builder

@dataclass
class ExtResource:
    rid: str                # e.g. "1_script"
    rtype: str              # "Script" | "Texture2D" | "PackedScene"
    path: str               # "res://..."


@dataclass
class SubResource:
    rid: str
    rtype: str
    props: list[tuple[str, str]]   # ordered key = formatted_value

    def render(self) -> str:
        hdr = f'[sub_resource type={fmt_str(self.rtype)} id={fmt_str(self.rid)}]'
        lines = [hdr]
        for k, v in self.props:
            lines.append(f"{k} = {v}")
        lines.append("")
        return "\n".join(lines)


class TresBuilder:
    """Build a Godot 4 .tres file deterministically."""

    def __init__(self, top_type: str, *, script_class: str | None = None, fmt: int = 3):
        self.top_type = top_type
        self.script_class = script_class
        self.fmt = fmt
        self.ext: list[ExtResource] = []
        self.sub: list[SubResource] = []
        self.resource_props: list[tuple[str, str]] = []

    def add_ext(self, rtype: str, path: str, rid: str) -> ExtResource:
        e = ExtResource(rid=rid, rtype=rtype, path=path)
        self.ext.append(e)
        return e

    def add_sub(self, sub: SubResource) -> SubResource:
        self.sub.append(sub)
        return sub

    def set_prop(self, key: str, value: str) -> None:
        self.resource_props.append((key, value))

    def render(self) -> str:
        load_steps = 1 + len(self.ext) + len(self.sub)
        parts: list[str] = []
        header = f'[gd_resource type={fmt_str(self.top_type)}'
        if self.script_class:
            header += f' script_class={fmt_str(self.script_class)}'
        header += f' load_steps={load_steps} format={self.fmt}]\n'
        parts.append(header)
        for e in self.ext:
            parts.append(
                f'[ext_resource type={fmt_str(e.rtype)} '
                f'path={fmt_str(e.path)} id={fmt_str(e.rid)}]'
            )
        if self.ext:
            parts.append("")
        for s in self.sub:
            parts.append(s.render())
        parts.append("[resource]")
        for k, v in self.resource_props:
            parts.append(f"{k} = {v}")
        # Ensure trailing newline
        return "\n".join(parts) + "\n"


# --------------------------------------------------------------------------- .tscn builder

@dataclass
class SceneExt:
    rid: str
    rtype: str
    path: str


@dataclass
class SceneNode:
    name: str
    node_type: str               # "Node2D" / "TileMapLayer"
    parent: str                  # "." or parent path relative to root
    props: list[tuple[str, str]]
    children: list["SceneNode"]

    def path(self) -> str:
        if self.parent == ".":
            return self.name
        return self.parent + "/" + self.name


class TscnBuilder:
    def __init__(self):
        self.ext: list[SceneExt] = []
        self.sub: list[SubResource] = []
        self.root: SceneNode | None = None

    def add_ext(self, rtype: str, path: str, rid: str) -> SceneExt:
        e = SceneExt(rid=rid, rtype=rtype, path=path)
        self.ext.append(e)
        return e

    def add_sub(self, sub: SubResource) -> SubResource:
        self.sub.append(sub)
        return sub

    def set_root(self, node: SceneNode) -> None:
        self.root = node

    def render(self) -> str:
        assert self.root is not None
        # count nodes
        def count(n: SceneNode) -> int:
            c = 1
            for ch in n.children:
                c += count(ch)
            return c
        nodes = count(self.root)
        load_steps = 1 + len(self.ext) + len(self.sub) + nodes
        parts: list[str] = []
        parts.append(f'[gd_scene load_steps={load_steps} format=3]\n')
        for e in self.ext:
            parts.append(
                f'[ext_resource type={fmt_str(e.rtype)} '
                f'path={fmt_str(e.path)} id={fmt_str(e.rid)}]'
            )
        if self.ext:
            parts.append("")
        for s in self.sub:
            parts.append(s.render())

        def emit(n: SceneNode):
            if n is self.root:
                hdr = f'[node name={fmt_str(n.name)} type={fmt_str(n.node_type)}]'
            else:
                hdr = (f'[node name={fmt_str(n.name)} type={fmt_str(n.node_type)} '
                       f'parent={fmt_str(n.parent)}]')
            parts.append(hdr)
            for k, v in n.props:
                parts.append(f"{k} = {v}")
            parts.append("")
            for ch in n.children:
                emit(ch)

        emit(self.root)
        # trim trailing empty
        text = "\n".join(parts)
        if not text.endswith("\n"):
            text += "\n"
        return text
