#!/bin/bash

# Parametri
MINIO_ALIAS="myminio"
MINIO_URL="https://localhost:9000"
ACCESS_KEY="admin"
SECRET_KEY="password"

# Funzione per creare utente, bucket e policy
create_user() {
    local username=$1
    local password=$(openssl rand -base64 12)

    # Configura alias MinIO
    mc alias set $MINIO_ALIAS $MINIO_URL $ACCESS_KEY $SECRET_KEY --insecure

    # Crea bucket per l'utente
    local bucket_name="${username}-bucket"
    mc mb ${MINIO_ALIAS}/${bucket_name} --insecure

    # Crea politica di accesso per l'utente
    local policy_name="${username}-policy"
    local policy_file="${policy_name}.json"

    echo '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ],
          "Resource": [
            "arn:aws:s3:::'${bucket_name}'",
            "arn:aws:s3:::'${bucket_name}'/*"
          ]
        }
      ]
    }' > $policy_file

    # Aggiungi politica al server MinIO
    mc admin policy create $MINIO_ALIAS $policy_name $policy_file --insecure

    # Crea utente e assegna politica
    mc admin user add $MINIO_ALIAS $username $password --insecure
    mc admin policy attach $MINIO_ALIAS $policy_name --user $username --insecure

    # Pulisci il file di politica temporaneo
    rm $policy_file

    # Stampa il nome utente e la password generata
    echo "Utente $username creato con successo."
    echo "Nome utente: $username"
    echo "Password: $password"
}

# Verifica che sia stato fornito un nome utente come parametro
if [ -z "$1" ]; then
    echo "Errore: nessun nome utente fornito."
    echo "Uso: $0 <nome_utente>"
    exit 1
fi

# Crea utente, bucket e politica
create_user $1

