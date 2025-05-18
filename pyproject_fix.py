from pathlib import Path
import tomlkit


def fix_pyproject(file: Path):
    # Read the existing TOML file
    with open(file, "r") as f:
        doc: tomlkit.TOMLDocument = tomlkit.parse(f.read())

# Rename [tool.poetry] to [project]
    if "poetry" in doc.get("tool", {}):
        doc["project"] = doc["tool"].pop("poetry")
        if not doc["tool"]:
            del doc["tool"]

    # Rename [tool.poetry.dev-dependencies] to [tool.poetry.group.dev.dependencies]
    if "tool" in doc and "poetry" in doc["tool"] and "dev-dependencies" in doc["tool"]["poetry"]:
        if "group" not in doc["tool"]["poetry"]:
            doc["tool"]["poetry"]["group"] = {}
        doc["tool"]["poetry"]["group"]["dev"] = {"dependencies": doc["tool"]["poetry"].pop("dev-dependencies")}

    # Move python under [project] as requires-python and the rest under [package] as requires
    #if "tool" in doc and "poetry" in doc["tool"] and "dependencies" in doc["tool"]["poetry"]:
    print(doc["tool"].keys())
    dependencies = {k:v for k,v in doc["tool"]["poetry"].pop("dependencies")}
    print(dependencies)
    dependencies["requires-python"] 
    if "python" in dependencies:
        doc["project"]["requires-python"] = dependencies.pop("python")
    doc["project"]["dependencies"] = [f"{k}{v}" for k,v in dependencies]

    # Set authors under [project]
    if "project" in doc:
        doc["project"]["authors"] = [{"name": "Partho", "email": "partho.bhowmick@icloud.com"}]

    with open(file, "wt") as f:
        tomlkit.dump(doc, f)


if __name__ == "__main__":
    fix_pyproject(
        "/Users/partho/kubernetes-python-client-project-root/python-async-client/pyproject.toml"
    )
