#!/bin/bash
set -euo pipefail

echo "Validating AWS credentials..."

# -------------------------------------------------
# Required env validation
# -------------------------------------------------
: "${BASE_DIR:?Required environment variable BASE_DIR is not set}"
: "${DB_HOST:?Required environment variable DB_HOST is not set}"
: "${DB_PORT:?Required environment variable DB_PORT is not set}"
: "${DB_USER:?Required environment variable DB_USER is not set}"
: "${DB_PASSWORD:?Required environment variable DB_PASSWORD is not set}"
: "${AWS_S3_BUCKET:?Required environment variable AWS_S3_BUCKET is not set}"
: "${OBJECT_STORAGE_PATH_PREFIX:?Required environment variable OBJECT_STORAGE_PATH_PREFIX is not set}"
: "${BACKUP_RETENTION_DAYS:?Required environment variable BACKUP_RETENTION_DAYS is not set}"

# -------------------------------------------------
# Validate AWS credentials
# -------------------------------------------------
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "Error: AWS credentials are invalid or not configured properly."
  exit 1
fi

echo "AWS credentials validated successfully."
echo "Starting MongoDB full dump..."

# -------------------------------------------------
# Backup directory
# -------------------------------------------------
TODAY=$(date +%F)
BACKUP_DIR="${BASE_DIR}/${TODAY}"
mkdir -p "$BACKUP_DIR"

# -------------------------------------------------
# Dump ALL databases
# -------------------------------------------------
ERR_FILE="${BACKUP_DIR}/dump.err"

if mongodump \
    --host "$DB_HOST" \
    --port "$DB_PORT" \
    --username "$DB_USER" \
    --password "$DB_PASSWORD" \
    --authenticationDatabase admin \
    --out "$BACKUP_DIR" \
    > /dev/null 2> "$ERR_FILE"; then

  if [[ -z "$(ls -A "$BACKUP_DIR")" ]]; then
    echo "ERROR: MongoDB dump is empty!"
    cat "$ERR_FILE"
    exit 1
  fi

  rm -f "$ERR_FILE"
  echo "MongoDB dump completed successfully."

else
  echo "ERROR: MongoDB dump failed!"
  cat "$ERR_FILE"
  exit 1
fi

# -------------------------------------------------
# Upload to S3
# -------------------------------------------------
echo "Uploading backup to AWS S3..."

aws s3 sync \
  "$BACKUP_DIR" \
  "s3://${AWS_S3_BUCKET}/${OBJECT_STORAGE_PATH_PREFIX}/${TODAY}/MongoDB"

echo "Backup successfully uploaded to AWS S3."

# -------------------------------------------------
# Cleanup local
# -------------------------------------------------
rm -rf "$BACKUP_DIR"

# -------------------------------------------------
# Retention cleanup
# -------------------------------------------------
echo "Deleting old backups..."

aws s3 ls "s3://${AWS_S3_BUCKET}/${OBJECT_STORAGE_PATH_PREFIX}/" | \
while read -r line; do
  DATE=$(echo "$line" | awk '{print $2}')
  if [[ "$DATE" < "$(date -d "-${BACKUP_RETENTION_DAYS} days" +%F)" ]]; then
    aws s3 rm "s3://${AWS_S3_BUCKET}/${OBJECT_STORAGE_PATH_PREFIX}/${DATE}" --recursive
  fi
done

echo "Backup process completed successfully."
