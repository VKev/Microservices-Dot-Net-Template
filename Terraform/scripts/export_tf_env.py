#!/usr/bin/env python3
"""
Load project/region values from Terraform tfvars files and emit shell exports.
Falls back to existing env values when keys are missing.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any, Dict, Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent


def load_file(path: Path) -> Dict[str, Any]:
    if path.suffix == ".json":
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)

    text = path.read_text(encoding="utf-8")

    # Try python-hcl2 if available for more accurate parsing.
    try:
        import hcl2  # type: ignore

        return hcl2.loads(text)
    except Exception:
        pass

    # Fallback: very small HCL-ish parser good enough for simple "key = value" pairs.
    data: Dict[str, Any] = {}
    pattern = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*(.+?)\s*$")
    for line in text.splitlines():
        if "#" in line:
            line = line.split("#", 1)[0]
        line = line.strip()
        if not line:
            continue
        match = pattern.match(line)
        if not match:
            continue
        key, raw_value = match.group(1), match.group(2).strip()
        if raw_value.startswith('"') and raw_value.endswith('"'):
            raw_value = raw_value[1:-1]
        data[key] = raw_value
    return data


def first_non_empty(mapping: Dict[str, Any], keys: Iterable[str], fallback: str) -> str:
    for key in keys:
        value = mapping.get(key)
        if value is None:
            continue
        if isinstance(value, str):
            value = value.strip()
        if value != "":
            return str(value)
    return fallback.strip()


def main() -> None:
    candidates = [
        REPO_ROOT / "Terraform" / "00-all.auto.tfvars.json",
        REPO_ROOT / "Terraform" / "00-all.auto.tfvars",
        REPO_ROOT / "Terraform" / "common.auto.tfvars",
        REPO_ROOT / "terraform-vars" / "common.auto.tfvars",
    ]

    merged: Dict[str, Any] = {}
    used_path: Path | None = None
    for path in candidates:
        if not path.exists():
            continue
        try:
            data = load_file(path)
            if isinstance(data, dict) and data:
                merged.update(data)
                used_path = path
                break
        except Exception:
            continue

    fallback_project = os.getenv("TF_ENV_FALLBACK_PROJECT", "")
    fallback_region = os.getenv("TF_ENV_FALLBACK_REGION", "")

    project = first_non_empty(
        merged,
        ("project_name", "project", "name"),
    fallback_project,
    )
    region = first_non_empty(
        merged,
        ("aws_region", "region"),
        fallback_region,
    )
    domain = first_non_empty(
        merged,
        ("domain_name", "cloudflare_domain"),
        os.getenv("TF_ENV_FALLBACK_DOMAIN", ""),
    )
    zone_id = first_non_empty(
        merged,
        ("cloudflare_zone_id",),
        os.getenv("TF_ENV_FALLBACK_CF_ZONE", ""),
    )
    sans_raw = merged.get("subject_alternative_names", None)
    sans_fallback = os.getenv("TF_ENV_FALLBACK_SANS", "")
    if sans_raw is None or sans_raw == "":
        sans = sans_fallback.strip()
    else:
        sans = json.dumps(sans_raw) if isinstance(sans_raw, (list, tuple)) else str(sans_raw).strip()

    if used_path:
        print(f"TF_ENV_SOURCE={used_path}")
    if project:
        print(f"PROJECT_NAME={project}")
        print(f"TF_VAR_project_name={project}")
    if region:
        print(f"AWS_REGION={region}")
        print(f"TF_VAR_region={region}")
        print(f"TF_VAR_aws_region={region}")
    if domain:
        print(f"ACM_DOMAIN_NAME={domain}")
        print(f"TF_VAR_domain_name={domain}")
    if zone_id:
        print(f"CLOUDFLARE_ZONE_ID={zone_id}")
        print(f"TF_VAR_cloudflare_zone_id={zone_id}")
    if sans:
        print(f"ACM_SANS={sans}")
        print(f"TF_VAR_subject_alternative_names={sans}")


if __name__ == "__main__":
    main()
