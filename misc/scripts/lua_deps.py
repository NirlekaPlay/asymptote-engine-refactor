#!/usr/bin/env python3
"""
lua_deps.py - Traverse require() calls in Lua/Luau files and output a dependency graph.
Supports Rojo project files (default.project.json) to resolve Roblox service paths.

Usage:
	Made by Claude

	python lua_deps.py <entry_file> [--root <repo_root>] [--rojo <project.json>] [--json] [--dot]

Examples:
	python lua_deps.py src/server/world/level/NewLevel.lua
	python lua_deps.py src/server/world/level/NewLevel.lua --rojo default.project.json --json
	python lua_deps.py src/server/world/level/NewLevel.lua --dot > graph.dot

Notes:
	I highly recommend using the dot format and paste it into https://dreampuf.github.io/GraphvizOnline/
"""

import re
import sys
import json
import argparse
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────────────
# Require patterns
# ──────────────────────────────────────────────────────────────────────────────
REQUIRE_PATTERNS = [
	re.compile(r'''require\s*\(\s*["']([^"']+)["']\s*\)'''),   # require("path") / require('path')
	re.compile(r'''require\s*\(\s*([\w][.\w]*)\s*\)'''),        # require(script.Parent.Foo)
]

EXTENSIONS = [".lua", ".luau", ""]


# ──────────────────────────────────────────────────────────────────────────────
# Rojo project.json parser
# Walks the tree and builds a map:
#   Roblox instance path  →  filesystem path
#   e.g. "ServerScriptService.server" → Path("src/server")
# ──────────────────────────────────────────────────────────────────────────────

def load_rojo_mappings(project_file: Path, repo_root: Path) -> dict[str, Path]:
	"""
	Parse a Rojo default.project.json and return a dict mapping
	Roblox dotted paths → filesystem Path objects.

	e.g. {
		"ServerScriptService":        Path("src/server"),   # if service itself has $path
		"ServerScriptService.server": Path("src/server"),   # named child with $path
		"ReplicatedStorage.shared":   Path("src/shared"),
		...
	}
	"""
	mappings: dict[str, Path] = {}

	try:
		data = json.loads(project_file.read_text(encoding="utf-8"))
	except Exception as e:
		print(f"[warn] Could not parse Rojo project file {project_file}: {e}", file=sys.stderr)
		return mappings

	def walk(node: dict, roblox_path: str):
		if not isinstance(node, dict):
			return

		# If this node has a $path, record the mapping
		fs_path_str = node.get("$path")
		if fs_path_str and roblox_path:
			fs_path = (repo_root / fs_path_str).resolve()
			mappings[roblox_path] = fs_path

		# Recurse into children (skip $ keys)
		for key, child in node.items():
			if key.startswith("$") or not isinstance(child, dict):
				continue
			child_path = f"{roblox_path}.{key}" if roblox_path else key
			walk(child, child_path)

	tree = data.get("tree", {})
	walk(tree, "")

	return mappings


def resolve_roblox_path(module_path: str, mappings: dict[str, Path], current_file: Path) -> Path | None:
	"""
	Try to resolve a dotted Roblox path like:
		ServerScriptService.server.world.entity.Entity
		script.Parent.cell.Cell

	Strategy:
	1. Handle script.* relative paths by anchoring to current_file's location.
	2. For absolute service paths, find the longest matching prefix in mappings,
	   then treat the remainder as a filesystem sub-path.
	"""

	parts = module_path.split(".")

	# ── script.* relative paths ──────────────────────────────────────────────
	if parts[0] == "script":
		base = current_file.parent
		remainder = parts[1:]
		for token in remainder:
			if token == "Parent":
				base = base.parent
			else:
				# Try to find the file from here
				candidate = base / token
				result = _try_extensions(candidate)
				if result:
					return result
				# keep descending into directory
				if candidate.is_dir():
					base = candidate
				else:
					break
		return None

	# ── Absolute Roblox service paths ────────────────────────────────────────
	# Find the longest prefix in mappings
	best_prefix_len = 0
	best_fs_root: Path | None = None

	for roblox_prefix, fs_root in mappings.items():
		prefix_parts = roblox_prefix.split(".")
		n = len(prefix_parts)
		if parts[:n] == prefix_parts and n > best_prefix_len:
			best_prefix_len = n
			best_fs_root = fs_root

	if best_fs_root is None:
		return None

	# Remaining path after the matched prefix
	remainder = parts[best_prefix_len:]

	if not remainder:
		# The path points at a directory — try init files
		return _try_extensions(best_fs_root / "init") or (
			best_fs_root if best_fs_root.is_file() else None
		)

	candidate = best_fs_root.joinpath(*remainder)
	return _try_extensions(candidate)


def _try_extensions(base: Path) -> Path | None:
	"""Try appending .lua / .luau / nothing, also try init files."""
	for ext in EXTENSIONS:
		p = Path(str(base) + ext) if ext else base
		if p.is_file():
			return p.resolve()
	# directory init
	for ext in [".lua", ".luau"]:
		p = base / ("init" + ext)
		if p.is_file():
			return p.resolve()
	return None


# ──────────────────────────────────────────────────────────────────────────────
# Standard filesystem require resolution
# ──────────────────────────────────────────────────────────────────────────────

def find_file(module_path: str, base_dir: Path, root_dir: Path) -> Path | None:
	"""Resolve a plain string require path relative to base_dir and root_dir."""
	slash_path = module_path.replace(".", "/")
	candidates = [
		base_dir / module_path,
		base_dir / slash_path,
		root_dir / module_path,
		root_dir / slash_path,
	]
	for c in candidates:
		result = _try_extensions(c)
		if result:
			return result
	return None


# ──────────────────────────────────────────────────────────────────────────────
# Source parsing
# ──────────────────────────────────────────────────────────────────────────────

def extract_requires(file_path: Path) -> list[str]:
	try:
		source = file_path.read_text(encoding="utf-8", errors="replace")
	except OSError as e:
		print(f"[warn] Cannot read {file_path}: {e}", file=sys.stderr)
		return []

	# Strip single-line comments
	source = re.sub(r'--(?!\[).*', '', source)

	found, seen = [], set()
	for pattern in REQUIRE_PATTERNS:
		for match in pattern.finditer(source):
			token = match.group(1)
			if token not in seen:
				seen.add(token)
				found.append(token)
	return found


# ──────────────────────────────────────────────────────────────────────────────
# Graph builder
# ──────────────────────────────────────────────────────────────────────────────

def build_graph(
	entry: Path,
	root_dir: Path,
	rojo_mappings: dict[str, Path],
	max_depth: int = -1,
	recurse: bool = True,
) -> dict:
	nodes: dict[str, dict] = {}
	edges: list[dict] = []
	visited: set[str] = set()

	def node_id(path: Path) -> str:
		try:
			return str(path.relative_to(root_dir))
		except ValueError:
			return str(path)

	def visit(file: Path, depth: int):
		nid = node_id(file)
		if nid in visited:
			return
		visited.add(nid)
		nodes[nid] = {"id": nid, "label": file.stem, "path": str(file), "external": False}

		if (max_depth >= 0 and depth >= max_depth) or (not recurse and depth > 0):
			return

		base_dir = file.parent
		for req in extract_requires(file):
			# 1. Try standard filesystem resolution first
			resolved = find_file(req, base_dir, root_dir)

			# 2. Fall back to Rojo-aware resolution
			if resolved is None and rojo_mappings:
				resolved = resolve_roblox_path(req, rojo_mappings, file)

			if resolved:
				rid = node_id(resolved)
				edges.append({"from": nid, "to": rid, "label": req})
				visit(resolved, depth + 1)
			else:
				# Truly unresolved — surface as external node
				rid = f"<{req}>"
				if rid not in nodes:
					# Use the last segment as a short label
					short = req.split(".")[-1]
					nodes[rid] = {"id": rid, "label": short, "path": None, "external": True}
				edges.append({"from": nid, "to": rid, "label": req})

	visit(entry.resolve(), 0)
	return {"entry": node_id(entry.resolve()), "nodes": list(nodes.values()), "edges": edges}


# ──────────────────────────────────────────────────────────────────────────────
# DOT output
# ──────────────────────────────────────────────────────────────────────────────

def to_dot(graph: dict) -> str:
	lines = ["digraph lua_deps {", "  rankdir=LR;",
			 '  node [shape=box, style=filled, fontname="Helvetica"];']
	for node in graph["nodes"]:
		nid   = node["id"].replace('"', '\\"')
		label = node["label"].replace('"', '\\"')
		color = ('#90ee90' if node["id"] == graph["entry"]
				 else '#ffd700' if node.get("external") else '#d0e8ff')
		lines.append(f'  "{nid}" [label="{label}", fillcolor="{color}"];')
	for edge in graph["edges"]:
		lines.append(f'  "{edge["from"]}" -> "{edge["to"]}";')
	lines.append("}")
	return "\n".join(lines)

# ──────────────────────────────────────────────────────────────────────────────
# Full-project graph
# ──────────────────────────────────────────────────────────────────────────────

def build_full_project_graph(
	root_dir: Path,
	rojo_mappings: dict[str, Path],
	exclude_globs: list[str] | None = None,
) -> dict:
	"""
	Discover every .lua / .luau file under root_dir, build a merged
	dependency graph, and annotate nodes with role classification.
	"""
	exclude_globs = exclude_globs or []
	all_files: list[Path] = []
	for ext in ("*.lua", "*.luau"):
		all_files.extend(root_dir.rglob(ext))

	# Filter out any excluded patterns (e.g. Packages/, node_modules/)
	def is_excluded(p: Path) -> bool:
		rel = str(p.relative_to(root_dir))
		return any(p.match(g) or rel.startswith(g.rstrip("/")) for g in exclude_globs)

	all_files = [f for f in all_files if not is_excluded(f)]
	print(f"[info] Found {len(all_files)} Lua/Luau files", file=sys.stderr)

	merged_nodes: dict[str, dict] = {}
	merged_edges: list[dict] = []
	seen_edges: set[tuple[str, str]] = set()

	for file in all_files:
		g = build_graph(file, root_dir, rojo_mappings, max_depth=-1, recurse=True)
		for node in g["nodes"]:
			merged_nodes.setdefault(node["id"], node)
		for edge in g["edges"]:
			key = (edge["from"], edge["to"])
			if key not in seen_edges:
				seen_edges.add(key)
				merged_edges.append(edge)

	# ── Compute degree ────────────────────────────────────────────────────────
	in_degree:  dict[str, int] = {nid: 0 for nid in merged_nodes}
	out_degree: dict[str, int] = {nid: 0 for nid in merged_nodes}
	for edge in merged_edges:
		out_degree[edge["from"]] = out_degree.get(edge["from"], 0) + 1
		in_degree[edge["to"]]   = in_degree.get(edge["to"], 0) + 1

	hub_threshold = max(3, len(merged_nodes) // 20)  # top ~5% by in-degree

	for nid, node in merged_nodes.items():
		ind  = in_degree.get(nid, 0)
		outd = out_degree.get(nid, 0)
		if ind == 0 and outd == 0:
			role = "orphan"
		elif ind == 0 and outd > 0:
			role = "root"
		elif ind >= hub_threshold:
			role = "hub"
		elif outd == 0:
			role = "leaf"
		else:
			role = "normal"
		node["role"] = role
		node["in_degree"]  = ind
		node["out_degree"] = outd

	return {
		"nodes": list(merged_nodes.values()),
		"edges": merged_edges,
		"stats": {
			"total_files": len(all_files),
			"total_nodes": len(merged_nodes),
			"total_edges": len(merged_edges),
			"orphans": sum(1 for n in merged_nodes.values() if n["role"] == "orphan"),
			"roots":   sum(1 for n in merged_nodes.values() if n["role"] == "root"),
			"hubs":    sum(1 for n in merged_nodes.values() if n["role"] == "hub"),
			"hub_threshold": hub_threshold,
		},
	}


def to_dot_full(graph: dict) -> str:
	COLOR = {
		"orphan": "#ff6b6b",  # red   — unused / dead code
		"root":   "#ffd700",  # gold  — entry points
		"hub":    "#ff9966",  # orange — heavily imported
		"leaf":   "#d0e8ff",  # light blue — pure utilities
		"normal": "#f0f0f0",  # grey
	}
	lines = [
		"digraph project_deps {",
		"  rankdir=LR;",
		'  node [shape=box, style=filled, fontname="Helvetica", fontsize=10];',
		'  edge [fontsize=8];',
		# Invisible rank-grouping for orphans
		"  subgraph cluster_orphans {",
		'    label="Orphaned (unreachable)"; style=dashed; color="#ff6b6b";',
	]
	for node in graph["nodes"]:
		if node["role"] == "orphan":
			nid = node["id"].replace('"', '\\"')
			lines.append(f'    "{nid}";')
	lines.append("  }")

	for node in graph["nodes"]:
		if node["role"] == "orphan":
			continue  # already in subgraph
		nid   = node["id"].replace('"', '\\"')
		label = node["label"].replace('"', '\\"')
		role  = node.get("role", "normal")
		color = COLOR.get(role, COLOR["normal"])
		ind, outd = node.get("in_degree", 0), node.get("out_degree", 0)
		tip = f"{role} | in={ind} out={outd}"
		lines.append(
			f'  "{nid}" [label="{label}", fillcolor="{color}", tooltip="{tip}"];'
		)

	for edge in graph["edges"]:
		lines.append(f'  "{edge["from"]}" -> "{edge["to"]}";')
	lines.append("}")
	return "\n".join(lines)


def print_summary(graph: dict):
	s = graph["stats"]
	print(f"\n{'─'*50}")
	print(f"  Files scanned : {s['total_files']}")
	print(f"  Nodes         : {s['total_nodes']}")
	print(f"  Edges         : {s['total_edges']}")
	print(f"  Orphans       : {s['orphans']}  (no imports, not imported)")
	print(f"  Roots         : {s['roots']}   (entry points, not imported by anyone)")
	print(f"  Hubs          : {s['hubs']}    (imported by ≥{s['hub_threshold']} others)")
	print(f"{'─'*50}\n")

	if s["orphans"]:
		print("Orphaned modules (potential dead code):")
		for n in graph["nodes"]:
			if n["role"] == "orphan":
				print(f"  ✗  {n['id']}")
		print()

	print("Hubs (most-imported):")
	hubs = sorted(
		[n for n in graph["nodes"] if n["role"] == "hub"],
		key=lambda n: n["in_degree"], reverse=True
	)
	for n in hubs[:15]:
		print(f"  ★  {n['id']}  (imported by {n['in_degree']})")

# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def main():
	parser = argparse.ArgumentParser(
		description="Lua/Luau dependency graph extractor with Rojo support"
	)
	parser.add_argument("entry", nargs="?", default=None,   # ← now optional
						help="Entry Lua/Luau file (omit when using --project)")
	parser.add_argument("--root", default=None,
						help="Repo root for resolving paths (default: cwd)")
	parser.add_argument("--rojo", default=None,
						help="Path to Rojo project JSON (default: auto-detect default.project.json)")
	fmt = parser.add_mutually_exclusive_group()
	fmt.add_argument("--json", dest="fmt", action="store_const", const="json", default="json")
	fmt.add_argument("--dot",  dest="fmt", action="store_const", const="dot")
	parser.add_argument("--depth", type=int, default=-1,
						help="Max traversal depth (-1 = unlimited)")
	parser.add_argument("--no-recurse", action="store_true",
						help="Only parse the entry file")
	parser.add_argument("--project", action="store_true",
						help="Scan the entire repo and emit a full project graph")
	parser.add_argument("--exclude", nargs="*", default=["Packages/", "node_modules/", ".git/"],
						help="Path prefixes to exclude (default: Packages/ node_modules/)")
	args = parser.parse_args()

	# Validate: need entry XOR --project
	if not args.project and not args.entry:
		parser.error("entry file is required unless --project is specified")

	repo_root = Path(args.root).resolve() if args.root else Path.cwd()

	# Auto-detect Rojo project file
	rojo_file: Path | None = None
	search_start = Path(args.entry).resolve().parent if args.entry else repo_root
	if args.rojo:
		rojo_file = Path(args.rojo)
	else:
		candidate = search_start
		while True:
			p = candidate / "default.project.json"
			if p.is_file():
				rojo_file = p
				break
			if candidate == candidate.parent:
				break
			candidate = candidate.parent

	rojo_mappings: dict[str, Path] = {}
	if rojo_file and rojo_file.is_file():
		rojo_mappings = load_rojo_mappings(rojo_file, repo_root)
		print(f"[info] Loaded Rojo mappings from {rojo_file} ({len(rojo_mappings)} paths)",
			  file=sys.stderr)
	else:
		print("[info] No Rojo project file found; using filesystem resolution only.",
			  file=sys.stderr)

	if args.project:
		graph = build_full_project_graph(repo_root, rojo_mappings, args.exclude)
		if args.fmt == "dot":
			print(to_dot_full(graph))
		elif args.fmt == "json":
			print(json.dumps(graph, indent=2))
		print_summary(graph)
		sys.exit(0)

	# Single-file mode
	entry = Path(args.entry)
	if not entry.is_file():
		print(f"Error: '{entry}' is not a file.", file=sys.stderr)
		sys.exit(1)

	graph = build_graph(entry, repo_root, rojo_mappings, args.depth, not args.no_recurse)
	print(to_dot(graph) if args.fmt == "dot" else json.dumps(graph, indent=2))


if __name__ == "__main__":
	main()