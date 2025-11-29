import sys
import json

def main():
    try:
        # Read JSON from stdin
        input_data = json.load(sys.stdin)
        
        docs_map_json = input_data.get("docs_map_json", "{}")
        replacements_json = input_data.get("replacements_json", "{}")
        
        try:
            docs_map = json.loads(docs_map_json)
        except json.JSONDecodeError:
            docs_map = {}

        try:
            replacements = json.loads(replacements_json)
        except json.JSONDecodeError:
            replacements = {}

        results = {}
        
        # Perform replacements on each doc
        # Sort keys by length descending to prevent partial replacements of longer keys
        sorted_keys = sorted(replacements.keys(), key=len, reverse=True)
        
        for key, content in docs_map.items():
            resolved_content = content
            for k in sorted_keys:
                v = replacements[k]
                if k and v:
                    resolved_content = resolved_content.replace(k, str(v))
            results[key] = resolved_content

        # Write result map to stdout
        # Terraform external data source expects a flat map of strings
        json.dump(results, sys.stdout)
        
    except Exception as e:
        sys.stderr.write(str(e))
        sys.exit(1)

if __name__ == "__main__":
    main()
