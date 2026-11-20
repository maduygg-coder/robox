"""Extract the station and menu scripts from a Roblox Studio XML backup."""

import argparse
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path)
    args = parser.parse_args()

    try:
        place = ElementTree.parse(args.place)
    except (ElementTree.ParseError, OSError) as error:
        parser.error(f"Không đọc được file .rbxlx: {error}")

    targets = {
        "Script": ("Station.server.lua", ("createStation", "GasStationAction")),
        "LocalScript": ("StationMenu.client.lua", ("GasStationMenu", "GasStationAction")),
    }

    sources = {}
    for class_name, (filename, markers) in targets.items():
        matches = []
        for item in place.iterfind(".//Item"):
            if item.get("class") != class_name:
                continue
            source = item.find("./Properties/*[@name='Source']")
            if source is not None and source.text and all(marker in source.text for marker in markers):
                matches.append(source.text)

        if len(matches) != 1:
            parser.error(f"Cần đúng một {filename} trong place, tìm được {len(matches)}.")

        sources[ROOT / "src" / filename] = matches[0]

    for path in sources:
        if path.exists():
            parser.error(f"File đã tồn tại: {path}. Dừng để tránh ghi đè code.")

    for path, source in sources.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("x", encoding="utf-8", newline="\n") as output:
            output.write(source)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
