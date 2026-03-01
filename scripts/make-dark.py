#!/usr/bin/env python3
"""Transform draw.io light-mode diagrams into dark-mode equivalents."""

import re
from pathlib import Path

# Semantic color mappings: light → dark
# Fills use medium-dark saturated colors so semantic meaning (red/green/amber/blue)
# remains clearly readable on a dark canvas — not so dark they render near-black.
FILL_MAP = {
    '#dae8fc': '#1e4d8c',   # blue fill (entry nodes)
    '#fff2cc': '#7a6200',   # amber fill (diamonds, caveats)
    '#d5e8d4': '#2d6b2d',   # green fill (checkpoints, suitable)
    '#f8cecc': '#8b2020',   # red fill (error/stop/not-suitable nodes)
    '#f5f5f5': '#3a3a3a',   # gray fill (swimlane, reference nodes)
}

STROKE_MAP = {
    '#6c8ebf': '#6a9fd8',   # blue stroke
    '#d6b656': '#d4a820',   # amber stroke
    '#82b366': '#5aad5a',   # green stroke
    '#b85450': '#d45a5a',   # red stroke
    '#666666': '#999999',   # gray stroke (swimlane)
}

FONT_MAP = {
    '#333333': '#cccccc',   # swimlane header text
    '#666666': '#999999',   # scope note gray text
    '#444444': '#bbbbbb',   # reference node text
}


def transform_style(style: str, is_edge: bool) -> str:
    # Apply fill replacements
    for light, dark in FILL_MAP.items():
        style = re.sub(
            rf'fillColor={re.escape(light)}',
            f'fillColor={dark}',
            style, flags=re.IGNORECASE
        )

    # Apply stroke replacements
    for light, dark in STROKE_MAP.items():
        style = re.sub(
            rf'strokeColor={re.escape(light)}',
            f'strokeColor={dark}',
            style, flags=re.IGNORECASE
        )

    # Apply explicit font color replacements
    for light, dark in FONT_MAP.items():
        style = re.sub(
            rf'fontColor={re.escape(light)}',
            f'fontColor={dark}',
            style, flags=re.IGNORECASE
        )

    has_fill = 'fillColor=' in style
    is_transparent = 'fillColor=none' in style and 'strokeColor=none' in style
    has_font_color = 'fontColor=' in style

    if is_edge:
        # Edge labels need light text on dark canvas
        if not has_font_color:
            style = style.rstrip(';') + ';fontColor=#cccccc;'
    elif is_transparent:
        # Title / scope note text nodes
        if not has_font_color:
            style = style.rstrip(';') + ';fontColor=#cccccc;'
    elif has_fill:
        # Filled nodes that don't have explicit fontColor yet — default black → white
        if not has_font_color:
            style = style.rstrip(';') + ';fontColor=#ffffff;'
    else:
        # Default nodes (no fillColor) — add dark fill + white text
        style = style.rstrip(';') + ';fillColor=#2d2d2d;strokeColor=#888888;fontColor=#ffffff;'

    return style


def transform_file(input_path: Path, output_path: Path) -> None:
    content = input_path.read_text()

    # Set dark canvas background
    content = re.sub(
        r'<mxGraphModel>',
        '<mxGraphModel background="#1e1e1e">',
        content
    )

    # Transform style attributes, passing edge context
    def replace_style(match):
        # Look backwards for edge="1" in the same mxCell tag
        prefix = content[:match.start()]
        last_tag_start = prefix.rfind('<mxCell')
        tag_context = content[last_tag_start:match.end()]
        is_edge = 'edge="1"' in tag_context
        style = match.group(1)
        return f'style="{transform_style(style, is_edge)}"'

    content = re.sub(r'style="([^"]*)"', replace_style, content)

    output_path.write_text(content)
    print(f"  {input_path.name} → {output_path.name}")


if __name__ == '__main__':
    diagrams = ['saw-scout-wave', 'saw-bootstrap', 'saw-check', 'saw-status']
    base = Path(__file__).parent.parent / 'docs' / 'diagrams'

    for name in diagrams:
        transform_file(base / f'{name}.drawio', base / f'{name}-dark.drawio')

    print("Done.")
