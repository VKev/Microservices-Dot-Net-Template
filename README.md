

aws-nuke nuke -c ./aws_nuke/nuke-config.yaml --profile terraform-user --no-dry-run --no-alias-check --no-prompt

docker compose -f 'docker-compose-production.yml' up -d --build