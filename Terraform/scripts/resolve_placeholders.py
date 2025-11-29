import sys
import json

def main():
    try:
        # Read JSON from stdin
        input_data = json.load(sys.stdin)
        
        content = input_data.get("content", "")
        replacements_json = input_data.get("replacements_json", "{}")
        
        # Parse the replacements map
        try:
            replacements = json.loads(replacements_json)
        except json.JSONDecodeError:
            # If parsing fails, return content as is or handle error
            # For Terraform external data source, we should probably output the error or fail
            # But let's try to be safe
            replacements = {}

        # Perform replacements
        # We iterate over the map. Order matters if keys are substrings of each other,
        # but here keys are distinct TERRAFORM_RDS_...
        for k, v in replacements.items():
            if k and v:
                content = content.replace(k, str(v))

        # Write result to stdout
        json.dump({"result": content}, sys.stdout)
        
    except Exception as e:
        # Write error to stderr (Terraform will show it) and exit non-zero
        sys.stderr.write(str(e))
        sys.exit(1)

if __name__ == "__main__":
    main()
