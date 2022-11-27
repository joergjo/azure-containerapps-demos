PHONY: migrate-up migrate-down migrate-force 

PWD = $(shell pwd)
TOKEN = $(shell az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)

# Default number of migrations to execute up or down
N = 2

migrate-up:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" up $(N)

migrate-down:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" down $(N)
	
migrate-force:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" force $(VERSION)
