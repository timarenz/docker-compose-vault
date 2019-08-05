CHECK_INTERVAL_S=1
INIT_PATH=/vault/init

vault server -config=/vault/config/local.json 2>&1 &

if [ -z $VAULT_ADDR ]; then
  export VAULT_ADDR=http://127.0.0.1:8200
fi

while $true; do
  VAULT_STATUS=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $VAULT_ADDR/v1/sys/health)
  case $VAULT_STATUS in
    501)
      echo "Vault is not initialized."
      echo "Trying to join Vault raft cluster..."
      vault operator raft join http://vault-1:8200
      ;;
    200)
      echo "Vault is initialized, unsealed and active."
      export CHECK_INTERVAL_S=60
      ;;
    429|473)
      echo "Vault is initialized, unsealed and in standby mode."
      export CHECK_INTERVAL_S=60
      ;;
    *)
      echo "Vault is an uninitialized or sealed state. Status code $VAULT_STATUS"
      ;;
  esac
  echo "Next check in $CHECK_INTERVAL_S seconds."
  sleep $CHECK_INTERVAL_S
done